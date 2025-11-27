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
  Timer? _rssiTimer;

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
  bool _isCancelled = false; // Track if user has cancelled the connection
  bool _isReconnecting = false; // Track if reconnect is in progress (timer scheduled or running)
  bool _isInitialConnection = false; // Track if this is the first connection attempt (show Connecting not Reconnecting)

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
  Future<void> connect(ScannedWatch scannedDevice, {bool autoConnect = false}) async {
    debugPrint('[WatchService] connect() called: autoConnect=$autoConnect, _isCancelled=$_isCancelled');
    // Only reset _isCancelled for truly user-initiated connections
    // Don't reset if this might be from an auto-reconnect attempt
    if (!autoConnect) {
      _isCancelled = false;
      debugPrint('[WatchService] connect() - reset _isCancelled to false (user-initiated)');
    }
    await _connectToDevice(scannedDevice.device, scannedDevice.id, scannedDevice.name, autoConnect: autoConnect);
  }

  /// Connect by device ID (for saved watches)
  /// 
  /// [autoConnect] - If true, uses flutter_blue_plus's autoConnect feature which:
  ///   - Returns immediately (non-blocking)
  ///   - System handles reconnection when device appears
  ///   - Doesn't time out - keeps trying until device available
  ///   - Convenient for auto-reconnect on app launch
  Future<void> connectById(String deviceId, {bool autoConnect = false}) async {
    debugPrint('[WatchService] connectById() called: deviceId=$deviceId, autoConnect=$autoConnect, _isCancelled=$_isCancelled');
    // Only reset _isCancelled for truly user-initiated connections
    // Don't reset if this might be from an auto-reconnect attempt
    if (!autoConnect) {
      _isCancelled = false;
      debugPrint('[WatchService] connectById() - reset _isCancelled to false (user-initiated)');
    }
    final device = BluetoothDevice.fromId(deviceId);
    await _connectToDevice(device, deviceId, 'ZSWatch', autoConnect: autoConnect);
  }

  Future<void> _connectToDevice(BluetoothDevice device, String watchId, String name, {bool autoConnect = false, bool isReconnectAttempt = false}) async {
    debugPrint('[WatchService:$hashCode] _connectToDevice called: watchId=$watchId, autoConnect=$autoConnect, isReconnectAttempt=$isReconnectAttempt, _isCancelled=$_isCancelled, _autoReconnect=$_autoReconnect, currentState=${currentConnection.state}');
    
    // Don't connect if user has cancelled
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] _connectToDevice skipped - cancelled by user');
      return;
    }

    // Don't reconnect if already connected to this device
    if (isConnected && _device?.remoteId.str == watchId) {
      debugPrint('[WatchService:$hashCode] _connectToDevice skipped - already connected');
      return;
    }
    
    // Don't start a new connection if already connecting
    final currentState = currentConnection.state;
    if (currentState == WatchConnectionState.connecting ||
        currentState == WatchConnectionState.bonding ||
        currentState == WatchConnectionState.discoveringServices ||
        currentState == WatchConnectionState.negotiating) {
      debugPrint('[WatchService:$hashCode] _connectToDevice skipped - already in state: $currentState');
      return;
    }

    // Only reset these for fresh connections, not reconnect attempts
    if (!isReconnectAttempt) {
      _autoReconnect = true;
      _reconnectAttempts = 0;
      _isInitialConnection = true; // Mark as initial connection
    }
    // Note: Only reset _isCancelled for user-initiated connections, not internal reconnects
    // The public connect methods should reset this flag

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

      _device = device;

      // Connect with optional autoConnect
      // When autoConnect is true:
      // - We don't await - let it run in background
      // - System will connect when device is available
      // - Connection events come through connectionState listener
      // Note: autoConnect is incompatible with mtu argument, so we request MTU after connection
      if (autoConnect) {
        // Final check before BLE call - user might have cancelled during setup
        if (_isCancelled) {
          debugPrint('[WatchService:$hashCode] autoConnect skipped - cancelled just before BLE call');
          return;
        }
        // Don't await - autoConnect runs in background
        // The connectionState listener will handle the connection event
        unawaited(device.connect(
          license: License.free,
          timeout: const Duration(seconds: 0),
          mtu: null, // autoConnect is incompatible with mtu
          autoConnect: true,
        ).catchError((e) {
          // Ignore errors for autoConnect - connection state listener handles everything
          debugPrint('[WatchService] AutoConnect error (ignored): $e');
        }));
      } else {
        // Final check before BLE call - user might have cancelled during setup
        if (_isCancelled) {
          debugPrint('[WatchService:$hashCode] connect skipped - cancelled just before BLE call');
          return;
        }
        debugPrint('[WatchService:$hashCode] About to call device.connect(autoConnect: false)');
        await device.connect(
          license: License.free,
          timeout: BleConfig.connectionTimeout,
          autoConnect: false,
        );
        // Perform post-connection setup only for direct connections
        await _setupAfterConnect(watchId, name);
      }

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
    
    // Check if user has cancelled
    if (_isCancelled) {
      debugPrint('Setup cancelled - user cancelled connection');
      return;
    }
    
    // Check if device is still valid (user may have cancelled)
    if (_device == null) {
      debugPrint('Setup cancelled - device is null');
      return;
    }
    
    _isSettingUp = true;

    try {
      // Bonding
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.bonding,
      ));

      // Re-check device in case user cancelled during state updates
      if (_device == null) {
        debugPrint('Setup cancelled during bonding - device is null');
        return;
      }

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

      // Setup NUS for Gadgetbridge protocol (needed for sync)
      await _setupNus();

      // Subscribe to battery service
      await _setupBatteryNotifications();
      
      // Read initial RSSI and start periodic updates
      await _readAndUpdateRssi();
      _startRssiUpdates();

      // Transition to syncing state (FR-088)
      // Connection is established but initial sync not yet complete
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.syncing,
        mtu: mtu,
        connectedAt: DateTime.now(),
      ));

      // Perform initial sync operations (FR-084 to FR-087)
      // Time sync (FR-085)
      await syncTime();
      
      // Request device info via Gadgetbridge
      await requestDeviceInfo();

      // Note: Music state sync (FR-086) is handled by MediaControlNotifier
      // which listens to connectionStream and syncs when state becomes connected

      // Mark as fully connected and ready (FR-088)
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.connected,
      ));

      // Reset reconnect attempts and initial connection flag on successful setup
      _reconnectAttempts = 0;
      _isInitialConnection = false;

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

  /// Read RSSI and update connection state
  Future<void> _readAndUpdateRssi() async {
    if (_device == null || !isConnected) return;
    
    try {
      final rssi = await _device!.readRssi();
      _updateConnection(currentConnection.copyWith(rssi: rssi));
    } catch (e) {
      debugPrint('[WatchService] Failed to read RSSI: $e');
    }
  }

  /// Start periodic RSSI updates (every 5 seconds)
  void _startRssiUpdates() {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _readAndUpdateRssi();
    });
  }

  /// Stop RSSI updates
  void _stopRssiUpdates() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
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
        try {
          final json = jsonDecode(message) as Map<String, dynamic>;
          _handleGadgetbridgeMessage(json);
        } catch (e) {
          // Watch sometimes sends malformed JSON with unquoted values like:
          // {"t":"music", "n": play} instead of {"t":"music", "n": "play"}
          // Try to fix and reparse
          final fixedMessage = _fixMalformedJson(message);
          if (fixedMessage != null) {
            try {
              final json = jsonDecode(fixedMessage) as Map<String, dynamic>;
              _handleGadgetbridgeMessage(json);
            } catch (e2) {
              debugPrint('[BLE RX] JSON parse failed even after fix: $e2');
            }
          } else {
            debugPrint('[BLE RX] JSON parse failed: $e');
          }
        }
      }
    } catch (e) {
      // Binary data that can't be decoded as UTF-8 - log raw bytes
      debugPrint('[BLE RX] Raw bytes: $data');
    }
  }

  /// Attempt to fix malformed JSON with unquoted string values
  /// e.g., {"t":"music", "n": play} -> {"t":"music", "n": "play"}
  String? _fixMalformedJson(String message) {
    // Pattern: after a colon and optional whitespace, find an unquoted word
    // that isn't a number, true, false, or null
    final regex = RegExp(r':\s*([a-zA-Z_][a-zA-Z0-9_]*)(\s*[,}])');
    final fixed = message.replaceAllMapped(regex, (match) {
      final value = match.group(1)!;
      final suffix = match.group(2)!;
      // Don't quote true, false, null
      if (value == 'true' || value == 'false' || value == 'null') {
        return ': $value$suffix';
      }
      return ': "$value"$suffix';
    });
    return fixed != message ? fixed : null;
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
  /// 
  /// Automatically chunks large messages to fit within BLE MTU.
  /// Watch can receive up to 2000 bytes total, but each BLE packet
  /// is limited by MTU (typically 244 bytes usable).
  Future<void> _sendNus(String data) async {
    final nusService = _findService(_guid(NusUuids.service));
    if (nusService == null) return;

    final txChar = _findCharacteristic(nusService, _guid(NusUuids.txCharacteristic));
    if (txChar == null) return;

    debugPrint('[BLE TX] $data');

    final bytes = utf8.encode(data);
    
    // Get current MTU from connection, default to minimum if not set
    final currentMtu = _connectionController.value.mtu ?? BleConfig.minimumMtu;
    // Usable payload is MTU - 3 (ATT header)
    final maxChunkSize = currentMtu - 3;
    
    // If data fits in one packet, send directly
    if (bytes.length <= maxChunkSize) {
      await txChar.write(bytes, withoutResponse: txChar.properties.writeWithoutResponse);
      return;
    }
    
    // Check if total data exceeds watch's max buffer (2000 bytes)
    if (bytes.length > 2000) {
      debugPrint('[BLE TX] WARNING: Data exceeds watch max buffer (${bytes.length} > 2000), truncating');
      // Truncate to fit - this shouldn't happen for notifications if we handle it properly
    }
    
    // Split into chunks and send sequentially
    int offset = 0;
    int chunkNum = 0;
    while (offset < bytes.length) {
      final end = (offset + maxChunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(offset, end);
      
      chunkNum++;
      debugPrint('[BLE TX] Chunk $chunkNum: ${chunk.length} bytes (offset $offset)');
      
      await txChar.write(chunk, withoutResponse: txChar.properties.writeWithoutResponse);
      
      // Small delay between chunks to allow BLE stack to process
      if (end < bytes.length) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      offset = end;
    }
    
    debugPrint('[BLE TX] Sent ${bytes.length} bytes in $chunkNum chunks');
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
    debugPrint('[WatchService:$hashCode] _handleConnectionStateChange: state=$state, _isCancelled=$_isCancelled');
    
    // If user has cancelled, ignore all connection events and disconnect
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] Ignoring connection event - cancelled by user');
      if (state == BluetoothConnectionState.connected) {
        // Force disconnect if BLE layer reports connected after cancel
        BluetoothDevice.fromId(watchId).disconnect();
      }
      return;
    }

    switch (state) {
      case BluetoothConnectionState.connected:
        // For autoConnect, we need to run setup when connection happens
        // Check if we're in connecting state (waiting for autoConnect)
        // Also check _autoReconnect - if false, user cancelled and we should disconnect
        if (currentConnection.state == WatchConnectionState.connecting && !_isSettingUp) {
          if (!_autoReconnect) {
            debugPrint('[WatchService] Connection arrived but cancelled - disconnecting');
            _device?.disconnect();
            _cleanup();
            _updateConnection(Connection(
              watchId: watchId,
              watchName: name,
              state: WatchConnectionState.disconnected,
            ));
            return;
          }
          debugPrint('[WatchService] AutoConnect triggered - running setup');
          _setupAfterConnect(watchId, name);
        }
        break;
      case BluetoothConnectionState.disconnected:
        _handleDisconnect(watchId, name);
        break;
      // ignore: deprecated_member_use
      case BluetoothConnectionState.connecting:
      // ignore: deprecated_member_use
      case BluetoothConnectionState.disconnecting:
        // Transient states - no action needed
        break;
    }
  }

  void _handleDisconnect(String watchId, String name) {
    debugPrint('[WatchService:$hashCode] _handleDisconnect: _isCancelled=$_isCancelled, _autoReconnect=$_autoReconnect, _reconnectAttempts=$_reconnectAttempts, _isReconnecting=$_isReconnecting');
    
    // If user has cancelled, don't attempt reconnection
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] Disconnect ignored - cancelled by user');
      _isReconnecting = false;
      _updateConnection(Connection(
        watchId: watchId,
        watchName: name,
        state: WatchConnectionState.disconnected,
      ));
      _cleanup();
      return;
    }
    
    // Don't start another reconnect if one is already in progress
    if (_isReconnecting) {
      debugPrint('[WatchService:$hashCode] Disconnect ignored - reconnect already in progress');
      return;
    }

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
    debugPrint('[WatchService:$hashCode] _attemptReconnect: _isCancelled=$_isCancelled, _autoReconnect=$_autoReconnect, _reconnectAttempts=$_reconnectAttempts');
    
    // If user has cancelled, don't attempt reconnection
    if (_isCancelled) {
      debugPrint('[WatchService:$hashCode] Reconnect skipped - cancelled by user');
      _isReconnecting = false;
      return;
    }

    // Cancel any existing reconnect timer to prevent stacking
    _reconnectTimer?.cancel();
    
    _reconnectAttempts++;
    _isReconnecting = true;  // Mark that we're in reconnect flow
    debugPrint('[WatchService:$hashCode] Scheduling reconnect timer (attempt $_reconnectAttempts)');

    // Only show "Reconnecting" if we've actually been connected before
    // For initial connection failures (e.g., autoConnect assertion error), keep showing "Connecting"
    if (_isInitialConnection) {
      debugPrint('[WatchService:$hashCode] Initial connection - keeping Connecting state');
      // Don't change state, keep showing "Connecting"
    } else {
      _updateConnection(currentConnection.copyWith(
        state: WatchConnectionState.reconnecting,
        reconnectionCount: _reconnectAttempts,
      ));
    }

    _reconnectTimer = Timer(BleConfig.reconnectionDelay, () async {
      debugPrint('[WatchService:$hashCode] Reconnect timer fired: _isCancelled=$_isCancelled, _autoReconnect=$_autoReconnect');
      // Double-check cancellation inside timer callback
      if (_isCancelled) {
        debugPrint('[WatchService:$hashCode] Reconnect timer skipped - cancelled by user');
        _isReconnecting = false;
        return;
      }
      if (_device != null && _autoReconnect && !_isSettingUp) {
        try {
          await _connectToDevice(_device!, watchId, name, isReconnectAttempt: true);
          _isReconnecting = false;  // Clear flag on successful connect start
        } catch (e) {
          debugPrint('[WatchService:$hashCode] Reconnect attempt $_reconnectAttempts failed: $e');
          _isReconnecting = false;  // Clear flag to allow next attempt from disconnect handler
          
          // Check if cancelled during the await - if so, don't continue reconnect logic
          if (_isCancelled) {
            debugPrint('[WatchService:$hashCode] Reconnect cancelled during attempt - cleaning up');
            _cleanup();
            return;
          }
          
          if (_reconnectAttempts >= _maxReconnectAttempts) {
            _updateConnection(Connection.error(
              watchId,
              ConnectionErrorType.maxReconnectionsReached,
            ));
            _cleanup();
          }
        }
      } else {
        _isReconnecting = false;
      }
    });
  }

  /// Cancel any pending connection (for autoConnect scenarios)
  /// This prevents the connection from being established even if the device appears
  void cancelPendingConnection() {
    debugPrint('[WatchService:$hashCode] cancelPendingConnection() called - setting _isCancelled=true, _autoReconnect=false');
    _autoReconnect = false;
    _isCancelled = true; // Mark as cancelled to ignore future connection events
    _isReconnecting = false; // Clear reconnecting flag
    _reconnectTimer?.cancel();
    
    // If we're in any connecting state, transition to disconnected
    final state = currentConnection.state;
    if (state.isConnectingOrReconnecting) {
      final watchId = currentConnection.watchId;
      final watchName = currentConnection.watchName;
      
      // IMPORTANT: Call disconnect BEFORE cleanup to cancel any pending BLE operation
      // Use both the stored device reference AND create one from ID for maximum coverage
      final device = _device;
      if (device != null) {
        debugPrint('[WatchService:$hashCode] Disconnecting device to cancel pending connection');
        device.disconnect();
      } else if (watchId.isNotEmpty) {
        // If _device is null but we have a watchId, create device from ID and disconnect
        debugPrint('[WatchService:$hashCode] Creating device from ID to cancel: $watchId');
        BluetoothDevice.fromId(watchId).disconnect();
      }
      
      _cleanup();
      _updateConnection(Connection(
        watchId: watchId,
        watchName: watchName,
        state: WatchConnectionState.disconnected,
      ));
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _autoReconnect = false;
    _isCancelled = true; // Mark as cancelled to ignore reconnection attempts
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
    _stopRssiUpdates();
    _device = null;
    _services = null;
    _isSettingUp = false;
    _isReconnecting = false;
    _isInitialConnection = false;
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


