import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';

import '../core/constants/ble_constants.dart';
import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../data/models/watch.dart';
import 'ble/ble_scanner.dart';

// Convert String UUIDs to Guid for flutter_blue_plus
Guid _guid(String uuid) => Guid(uuid);

/// Unified watch service that handles:
/// - BLE connection management
/// - Device info retrieval
/// - Protocol communication (Gadgetbridge)
/// - Battery monitoring
class WatchService {
  BluetoothDevice? _device;
  List<BluetoothService>? _services;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _nusSubscription;
  StreamSubscription<List<int>>? _batterySubscription;
  Timer? _reconnectTimer;

  // Use BehaviorSubject to cache last value for new subscribers
  final _connectionController = BehaviorSubject<Connection>.seeded(
    const Connection(watchId: '', state: WatchConnectionState.disconnected),
  );
  final _watchInfoController = BehaviorSubject<Watch?>.seeded(null);
  final _batteryController = BehaviorSubject<int>.seeded(0);
  final _incomingMessageController = StreamController<Map<String, dynamic>>.broadcast();

  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3; // Reduced for faster disconnect detection
  bool _isSettingUp = false; // Prevent concurrent setup calls

  /// Stream of connection state changes
  Stream<Connection> get connectionStream => _connectionController.stream;

  /// Stream of watch info updates
  Stream<Watch?> get watchInfoStream => _watchInfoController.stream;

  /// Stream of battery level updates
  Stream<int> get batteryStream => _batteryController.stream;

  /// Stream of incoming messages from watch
  Stream<Map<String, dynamic>> get incomingMessages => _incomingMessageController.stream;

  /// Current connection state
  Connection get currentConnection => _connectionController.value;

  /// Current watch info
  Watch? get currentWatch => _watchInfoController.value;

  /// Whether connected
  bool get isConnected => _connectionController.value.isConnected;

  /// Connect to a scanned device
  Future<void> connect(ScannedWatch scannedDevice) async {
    await _connectToDevice(scannedDevice.device, scannedDevice.id, scannedDevice.name);
  }

  /// Connect by device ID (for saved watches)
  Future<void> connectById(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await _connectToDevice(device, deviceId, 'ZSWatch');
  }

  Future<void> _connectToDevice(BluetoothDevice device, String watchId, String name) async {
    // Don't reconnect if already connected to this device
    if (isConnected && _device?.remoteId.str == watchId) {
      return;
    }
    
    // Don't start a new connection if already connecting
    final currentState = currentConnection.state;
    if (currentState == WatchConnectionState.connecting ||
        currentState == WatchConnectionState.bonding ||
        currentState == WatchConnectionState.discoveringServices ||
        currentState == WatchConnectionState.negotiating) {
      return;
    }

    _autoReconnect = true;
    _reconnectAttempts = 0;

    try {
      _updateConnection(Connection(
        watchId: watchId,
        watchName: name,
        state: WatchConnectionState.connecting,
      ));

      // Cancel existing subscriptions
      await _connectionSubscription?.cancel();

      // Subscribe to connection state BEFORE connecting
      _connectionSubscription = device.connectionState.listen(
        (state) => _handleConnectionStateChange(state, watchId, name),
      );

      // Connect
      await device.connect(
        timeout: BleConfig.connectionTimeout,
        autoConnect: false,
      );

      _device = device;

      // Perform post-connection setup
      await _setupAfterConnect(watchId, name);

    } catch (e) {
      _updateConnection(Connection.error(
        watchId,
        ConnectionErrorType.timeout,
        details: e.toString(),
      ));
      rethrow;
    }
  }

  Future<void> _setupAfterConnect(String watchId, String name) async {
    // Prevent concurrent setup calls (can happen on rapid reconnects)
    if (_isSettingUp) {
      debugPrint('Setup already in progress, skipping duplicate call');
      return;
    }
    _isSettingUp = true;

    try {
      // Bonding
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.bonding,
      ));

      final bondState = await _device!.bondState.first;
      if (bondState != BluetoothBondState.bonded) {
        await _device!.createBond();
      }

      // Discover services
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.discoveringServices,
      ));

      _services = await _device!.discoverServices();

      // Negotiate MTU
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.negotiating,
      ));

      final mtu = await _device!.requestMtu(BleConfig.preferredMtu);

      // Request high priority connection (enables 2M PHY)
      await _device!.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high,
      );

      // Mark as connected
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.connected,
        mtu: mtu,
        connectedAt: DateTime.now(),
      ));

      // Create or update watch object - preserve existing firmware/battery info
      final existingWatch = currentWatch;
      final watch = existingWatch != null && existingWatch.id == watchId
          ? existingWatch.copyWith(lastConnectedAt: DateTime.now())
          : Watch(
              id: watchId,
              name: name,
              createdAt: DateTime.now(),
              lastConnectedAt: DateTime.now(),
            );
      _watchInfoController.add(watch);

      // Setup NUS for Gadgetbridge protocol
      await _setupNus();

      // Subscribe to battery service
      await _setupBatteryNotifications();

      // Request device info via Gadgetbridge
      await requestDeviceInfo();

      // Sync time
      await syncTime();

      // Reset reconnect attempts on successful setup
      _reconnectAttempts = 0;

    } catch (e) {
      _updateConnection(Connection.error(
        watchId,
        ConnectionErrorType.serviceDiscoveryFailed,
        details: e.toString(),
      ));
      await disconnect();
      rethrow;
    } finally {
      _isSettingUp = false;
    }
  }

  Future<void> _setupNus() async {
    await _nusSubscription?.cancel();
    _nusSubscription = null;
    
    final nusService = _findService(_guid(NusUuids.service));
    if (nusService == null) return;

    final rxChar = _findCharacteristic(nusService, _guid(NusUuids.rxCharacteristic));
    if (rxChar == null) return;

    await rxChar.setNotifyValue(true);
    _nusSubscription = rxChar.onValueReceived.listen(_handleNusData);
  }

  void _handleNusData(List<int> data) {
    try {
      final message = utf8.decode(data).trim();
      if (message.isEmpty) return;

      debugPrint('[BLE RX] $message');

      // Try to parse as JSON
      if (message.startsWith('{') && message.endsWith('}')) {
        final json = jsonDecode(message) as Map<String, dynamic>;
        _handleGadgetbridgeMessage(json);
      }
    } catch (e) {
      // Binary data that can't be decoded as UTF-8 - log raw bytes
      debugPrint('[BLE RX] Raw bytes: $data');
    }
  }

  void _handleGadgetbridgeMessage(Map<String, dynamic> message) {
    _incomingMessageController.add(message);

    final type = message['t'] as String?;
    if (type == null) return;

    switch (type) {
      case 'ver':
        // Device info response
        final fw = message['fw'] as String?;
        final hw = message['hw'] as String?;
        final watch = currentWatch;
        if (watch != null) {
          _watchInfoController.add(watch.copyWith(
            firmwareVersion: fw,
            hardwareVersion: hw,
          ));
        }
        break;

      case 'status':
        // Status update (includes battery)
        final battery = message['bat'] as int?;
        final isCharging = message['chg'] == 1;
        if (battery != null) {
          _batteryController.add(battery);
          final watch = currentWatch;
          if (watch != null) {
            _watchInfoController.add(watch.copyWith(batteryLevel: battery));
          }
          _updateConnection(currentConnection.copyWith(isCharging: isCharging));
        }
        break;
    }
  }

  Future<void> _setupBatteryNotifications() async {
    await _batterySubscription?.cancel();
    _batterySubscription = null;
    
    final batteryService = _findService(_guid(BatteryUuids.service));
    if (batteryService == null) return;

    final levelChar = _findCharacteristic(batteryService, _guid(BatteryUuids.level));
    if (levelChar == null) return;

    // Read initial value
    try {
      final data = await levelChar.read();
      if (data.isNotEmpty) {
        final level = data[0];
        _batteryController.add(level);
        final watch = currentWatch;
        if (watch != null) {
          _watchInfoController.add(watch.copyWith(batteryLevel: level));
        }
      }
    } catch (_) {}

    // Subscribe to notifications
    try {
      await levelChar.setNotifyValue(true);
      _batterySubscription = levelChar.onValueReceived.listen((data) {
        if (data.isNotEmpty) {
          final level = data[0];
          _batteryController.add(level);
          final watch = currentWatch;
          if (watch != null) {
            _watchInfoController.add(watch.copyWith(batteryLevel: level));
          }
        }
      });
    } catch (_) {}
  }

  /// Send Gadgetbridge command
  Future<void> _sendGb(Map<String, dynamic> data) async {
    final json = jsonEncode(data);
    await _sendNus('GB($json)');
  }

  /// Send raw NUS data
  Future<void> _sendNus(String data) async {
    final nusService = _findService(_guid(NusUuids.service));
    if (nusService == null) return;

    final txChar = _findCharacteristic(nusService, _guid(NusUuids.txCharacteristic));
    if (txChar == null) return;

    debugPrint('[BLE TX] $data');

    final bytes = utf8.encode(data);
    await txChar.write(bytes, withoutResponse: txChar.properties.writeWithoutResponse);
  }

  /// Request device info from watch
  Future<void> requestDeviceInfo() async {
    await _sendGb({'t': 'ver'});
  }

  /// Sync time to watch
  Future<void> syncTime() async {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch ~/ 1000;
    final tz = now.timeZoneOffset.inMinutes / 60.0;
    await _sendNus('setTime($timestamp);E.setTimeZone($tz);');
  }

  /// Send notification to watch
  Future<void> sendNotification({
    required int id,
    required String source,
    String? title,
    String? body,
    String? sender,
    String? subject,
    String? phoneNumber,
    bool canReply = false,
  }) async {
    final data = <String, dynamic>{
      't': 'notify',
      'id': id,
      'src': source,
    };
    if (title != null) data['title'] = title;
    if (body != null) data['body'] = body;
    if (sender != null) data['sender'] = sender;
    if (subject != null) data['subject'] = subject;
    if (phoneNumber != null) data['tel'] = phoneNumber;
    if (canReply) data['reply'] = true;

    await _sendGb(data);
  }

  /// Update an existing notification on watch
  Future<void> updateNotification(int id, String body) async {
    await _sendGb({
      't': 'notify~',
      'id': id,
      'body': body,
    });
  }

  /// Remove a notification from watch
  Future<void> removeNotification(int id) async {
    await _sendGb({'t': 'notify-', 'id': id});
  }

  /// Send music playback state to watch
  Future<void> sendMusicState({
    required String state,
    int? positionSeconds,
    bool shuffle = false,
    bool repeat = false,
  }) async {
    final data = <String, dynamic>{
      't': 'musicstate',
      'state': state,
    };
    if (positionSeconds != null) data['position'] = positionSeconds;
    if (shuffle) data['shuffle'] = 1;
    if (repeat) data['repeat'] = 1;

    await _sendGb(data);
  }

  /// Send music track info to watch
  Future<void> sendMusicInfo({
    String? artist,
    String? album,
    String? track,
    int? durationSeconds,
    int? trackNumber,
    int? trackCount,
  }) async {
    final data = <String, dynamic>{'t': 'musicinfo'};
    if (artist != null) data['artist'] = artist;
    if (album != null) data['album'] = album;
    if (track != null) data['track'] = track;
    if (durationSeconds != null) data['dur'] = durationSeconds;
    if (trackCount != null) data['c'] = trackCount;
    if (trackNumber != null) data['n'] = trackNumber;

    await _sendGb(data);
  }

  /// Start/stop find device (vibrate watch)
  Future<void> findDevice(bool enabled) async {
    await _sendGb({'t': 'find', 'n': enabled});
  }

  /// Vibrate watch with pattern
  Future<void> vibrate(int pattern) async {
    await _sendGb({'t': 'vibrate', 'n': pattern});
  }

  void _handleConnectionStateChange(
    BluetoothConnectionState state,
    String watchId,
    String name,
  ) {
    switch (state) {
      case BluetoothConnectionState.disconnected:
        _handleDisconnect(watchId, name);
        break;
      default:
        break;
    }
  }

  void _handleDisconnect(String watchId, String name) {
    final wasConnected = currentConnection.isConnected || 
                         currentConnection.state == WatchConnectionState.connecting ||
                         currentConnection.state == WatchConnectionState.bonding ||
                         currentConnection.state == WatchConnectionState.discoveringServices ||
                         currentConnection.state == WatchConnectionState.negotiating;

    if (wasConnected && _autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _attemptReconnect(watchId, name);
    } else {
      _updateConnection(Connection(
        watchId: watchId,
        watchName: name,
        state: WatchConnectionState.disconnected,
      ));
      _cleanup();
    }
  }

  void _attemptReconnect(String watchId, String name) {
    // Cancel any existing reconnect timer to prevent stacking
    _reconnectTimer?.cancel();
    
    _reconnectAttempts++;

    _updateConnection(currentConnection.copyWith(
      state: WatchConnectionState.reconnecting,
      reconnectionCount: _reconnectAttempts,
    ));

    _reconnectTimer = Timer(BleConfig.reconnectionDelay, () async {
      if (_device != null && _autoReconnect && !_isSettingUp) {
        try {
          await _connectToDevice(_device!, watchId, name);
        } catch (e) {
          debugPrint('Reconnect attempt $_reconnectAttempts failed: $e');
          if (_reconnectAttempts >= _maxReconnectAttempts) {
            _updateConnection(Connection.error(
              watchId,
              ConnectionErrorType.maxReconnectionsReached,
            ));
            _cleanup();
          }
        }
      }
    });
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();

    final device = _device;
    final watchId = currentConnection.watchId;
    final watchName = currentConnection.watchName;

    _cleanup();

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _updateConnection(Connection(
      watchId: watchId,
      watchName: watchName,
      state: WatchConnectionState.disconnected,
    ));
  }

  void _cleanup() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _nusSubscription?.cancel();
    _nusSubscription = null;
    _batterySubscription?.cancel();
    _batterySubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _device = null;
    _services = null;
    _isSettingUp = false;
  }

  void _updateConnection(Connection connection) {
    _connectionController.add(connection);
  }

  BluetoothService? _findService(Guid uuid) {
    return _services?.cast<BluetoothService?>().firstWhere(
          (s) => s?.uuid == uuid,
          orElse: () => null,
        );
  }

  BluetoothCharacteristic? _findCharacteristic(BluetoothService service, Guid uuid) {
    return service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
          (c) => c?.uuid == uuid,
          orElse: () => null,
        );
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
    await _watchInfoController.close();
    await _batteryController.close();
    await _incomingMessageController.close();
  }
}


