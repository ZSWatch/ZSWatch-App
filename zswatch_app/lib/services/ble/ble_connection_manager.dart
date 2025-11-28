import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/ble_constants.dart';
import '../../data/models/connection.dart';
import '../../data/models/connection_state.dart';
import 'ble_scanner.dart';

/// Manages BLE connections to ZSWatch devices
///
/// Handles:
/// - Connection establishment and teardown
/// - MTU negotiation and PHY optimization
/// - Bonding/pairing
/// - Auto-reconnection on disconnect
/// - Connection state management
class BleConnectionManager {
  final FlutterSecureStorage _secureStorage;

  BluetoothDevice? _connectedDevice;
  List<BluetoothService>? _services;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  Timer? _reconnectTimer;

  final _connectionController = StreamController<Connection>.broadcast();

  Connection _currentConnection = const Connection(
    watchId: '',
    state: WatchConnectionState.disconnected,
  );

  // Disabled by default - WatchService handles auto-reconnect now
  bool _autoReconnect = false;
  bool _isCancelled = false; // Track if user has cancelled
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  BleConnectionManager({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Stream of connection state changes
  Stream<Connection> get connectionStream => _connectionController.stream;

  /// Current connection state
  Connection get currentConnection => _currentConnection;

  /// Whether currently connected
  bool get isConnected => _currentConnection.isConnected;

  /// Currently connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Discovered services on connected device
  List<BluetoothService>? get services => _services;

  /// Connect to a device
  ///
  /// [device] - Device to connect to (from scanner)
  /// [autoReconnect] - Whether to automatically reconnect on disconnect (disabled by default)
  Future<void> connect(
    ScannedWatch device, {
    bool autoReconnect = false,
  }) async {
    _autoReconnect = autoReconnect;
    _reconnectAttempts = 0;
    _isCancelled = false; // Reset for new connection

    await _connectToDevice(device.device, device.id);
  }

  /// Connect to a device by ID (for reconnecting to saved devices)
  Future<void> connectById(String deviceId, {bool autoReconnect = false}) async {
    _autoReconnect = autoReconnect;
    _reconnectAttempts = 0;
    _isCancelled = false; // Reset for new connection

    // Create a BluetoothDevice from ID
    final device = BluetoothDevice.fromId(deviceId);
    await _connectToDevice(device, deviceId);
  }

  Future<void> _connectToDevice(BluetoothDevice device, String watchId) async {
    // Don't connect if user has cancelled
    if (_isCancelled) {
      debugPrint('[BleConnectionManager] _connectToDevice skipped - cancelled by user');
      return;
    }

    try {
      // Update state to connecting
      _updateConnection(Connection(
        watchId: watchId,
        state: WatchConnectionState.connecting,
      ));

      // Cancel any existing subscriptions
      await _connectionStateSubscription?.cancel();

      // Subscribe to connection state changes
      _connectionStateSubscription = device.connectionState.listen(
        (state) => _handleConnectionStateChange(state, watchId),
      );

      // Attempt connection
      await device.connect(
        license: License.free,
        timeout: BleConfig.connectionTimeout,
        autoConnect: false,
      );

      _connectedDevice = device;

      // Perform post-connection setup
      await _performPostConnectionSetup(watchId);

    } catch (e) {
      debugPrint('Connection error: $e');
      _updateConnection(Connection.error(
        watchId,
        ConnectionErrorType.timeout,
        details: e.toString(),
      ));
      rethrow;
    }
  }

  Future<void> _performPostConnectionSetup(String watchId) async {
    try {
      // Update state to bonding
      _updateConnection(_currentConnection.copyWith(
        state: WatchConnectionState.bonding,
      ));

      // Ensure bonding (may prompt user)
      if (_connectedDevice != null) {
        await _ensureBonding(watchId);
      }

      // Update state to discovering services
      _updateConnection(_currentConnection.copyWith(
        state: WatchConnectionState.discoveringServices,
      ));

      // Discover services
      _services = await _connectedDevice?.discoverServices();

      // Verify required services exist
      if (!_hasRequiredServices()) {
        throw Exception('Required BLE services not found');
      }

      // Update state to negotiating
      _updateConnection(_currentConnection.copyWith(
        state: WatchConnectionState.negotiating,
      ));

      // Optimize connection parameters
      await _optimizeConnection(watchId);

      // All done - update to connected state
      _updateConnection(_currentConnection.copyWith(
        state: WatchConnectionState.connected,
        connectedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      ));

    } catch (e) {
      debugPrint('Post-connection setup error: $e');
      _updateConnection(Connection.error(
        watchId,
        ConnectionErrorType.serviceDiscoveryFailed,
        details: e.toString(),
      ));
      await disconnect();
      rethrow;
    }
  }

  /// Negotiate MTU for optimal throughput
  Future<int> negotiateMtu() async {
    if (_connectedDevice == null) {
      throw StateError('Not connected');
    }

    final mtu = await _connectedDevice!.requestMtu(BleConfig.preferredMtu);
    _updateConnection(_currentConnection.copyWith(mtu: mtu));
    return mtu;
  }

  /// Enable Data Length Extension
  void enableDle() {
    // DLE is typically enabled automatically with MTU negotiation
    // on modern BLE stacks. This just updates our tracking.
    _updateConnection(_currentConnection.copyWith(
      dleEnabled: true,
    ));
  }

  Future<void> _optimizeConnection(String watchId) async {
    try {
      // Negotiate MTU
      final mtu = await negotiateMtu();
      debugPrint('Negotiated MTU: $mtu');

      // Note: We don't request connection priority here.
      // The watch manages connection intervals based on its current needs
      // (e.g., short intervals during DFU, longer intervals when idle).
      // Forcing high priority from the phone would override the watch's
      // power-saving preferences.

      // Mark DLE as enabled (automatic with MTU negotiation)
      enableDle();

    } catch (e) {
      debugPrint('Connection optimization warning: $e');
      // Non-fatal - continue with default parameters
    }
  }

  Future<void> _ensureBonding(String watchId) async {
    if (_connectedDevice == null) return;

    try {
      // Check if already bonded
      final bondState = await _connectedDevice!.bondState.first;
      if (bondState == BluetoothBondState.bonded) {
        debugPrint('Device already bonded');
        return;
      }

      // Initiate bonding
      debugPrint('Initiating bonding...');
      await _connectedDevice!.createBond();

      // Store bonding reference securely
      await _secureStorage.write(
        key: 'bond_$watchId',
        value: DateTime.now().toIso8601String(),
      );

    } catch (e) {
      debugPrint('Bonding error: $e');
      // Continue anyway - some devices work without explicit bonding
    }
  }

  bool _hasRequiredServices() {
    if (_services == null || _services!.isEmpty) return false;

    // Check for NUS service (required for Gadgetbridge protocol)
    final nusServiceGuid = Guid(NusUuids.service);
    final hasNus = _services!.any((s) => s.uuid == nusServiceGuid);

    return hasNus;
  }

  void _handleConnectionStateChange(
    BluetoothConnectionState state,
    String watchId,
  ) {
    switch (state) {
      case BluetoothConnectionState.connected:
        // Already handled in connect flow
        break;

      case BluetoothConnectionState.disconnected:
        _handleDisconnect(watchId);
        break;

      // ignore: deprecated_member_use
      case BluetoothConnectionState.connecting:
        // Already handled
        break;

      // ignore: deprecated_member_use
      case BluetoothConnectionState.disconnecting:
        // Transitional state
        break;
    }
  }

  void _handleDisconnect(String watchId) {
    // If user has cancelled, don't attempt reconnection
    if (_isCancelled) {
      debugPrint('[BleConnectionManager] Disconnect ignored - cancelled by user');
      _updateConnection(Connection(
        watchId: watchId,
        state: WatchConnectionState.disconnected,
      ));
      _cleanup();
      return;
    }

    final wasConnected = _currentConnection.isConnected;

    if (wasConnected && _autoReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      // Attempt reconnection
      _attemptReconnect(watchId);
    } else {
      // Final disconnect
      _updateConnection(Connection(
        watchId: watchId,
        state: WatchConnectionState.disconnected,
        reconnectionCount: _reconnectAttempts,
      ));
      _cleanup();
    }
  }

  void _attemptReconnect(String watchId) {
    // If user has cancelled, don't attempt reconnection
    if (_isCancelled) {
      debugPrint('[BleConnectionManager] Reconnect skipped - cancelled by user');
      return;
    }

    _reconnectAttempts++;

    _updateConnection(_currentConnection.copyWith(
      state: WatchConnectionState.reconnecting,
      reconnectionCount: _reconnectAttempts,
    ));

    // Delay before reconnect attempt
    _reconnectTimer = Timer(BleConfig.reconnectionDelay, () async {
      // Double-check cancellation inside timer callback
      if (_isCancelled) {
        debugPrint('[BleConnectionManager] Reconnect timer skipped - cancelled by user');
        return;
      }
      if (_connectedDevice != null && _autoReconnect) {
        try {
          await _connectToDevice(_connectedDevice!, watchId);
        } catch (e) {
          debugPrint('[BleConnectionManager] Reconnect attempt $_reconnectAttempts failed: $e');
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

  /// Read RSSI from connected device
  Future<int> readRssi() async {
    if (_connectedDevice == null) {
      throw StateError('Not connected');
    }

    final rssi = await _connectedDevice!.readRssi();
    _updateConnection(_currentConnection.copyWith(
      rssi: rssi,
      lastActivityAt: DateTime.now(),
    ));
    return rssi;
  }

  /// Cancel any pending connection
  void cancelPendingConnection() {
    debugPrint('[BleConnectionManager] Cancelling pending connection');
    _autoReconnect = false;
    _isCancelled = true;
    _reconnectTimer?.cancel();
    
    final device = _connectedDevice;
    _cleanup();
    device?.disconnect();
    
    _updateConnection(Connection(
      watchId: _currentConnection.watchId,
      state: WatchConnectionState.disconnected,
    ));
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _autoReconnect = false;
    _isCancelled = true; // Mark as cancelled to prevent reconnection
    _reconnectTimer?.cancel();

    final device = _connectedDevice;
    final watchId = _currentConnection.watchId;

    _cleanup();

    if (device != null) {
      try {
        await device.disconnect();
      } catch (e) {
        debugPrint('Disconnect error: $e');
      }
    }

    _updateConnection(Connection(
      watchId: watchId,
      state: WatchConnectionState.disconnected,
    ));
  }

  void _cleanup() {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectedDevice = null;
    _services = null;
  }

  void _updateConnection(Connection connection) {
    _currentConnection = connection;
    _connectionController.add(connection);
  }

  /// Update last activity timestamp
  void updateActivity() {
    if (_currentConnection.isConnected) {
      _updateConnection(_currentConnection.copyWith(
        lastActivityAt: DateTime.now(),
      ));
    }
  }

  /// Find a service by UUID
  BluetoothService? findService(Guid uuid) {
    return _services?.cast<BluetoothService?>().firstWhere(
          (s) => s?.uuid == uuid,
          orElse: () => null,
        );
  }

  /// Find a characteristic by UUID within a service
  BluetoothCharacteristic? findCharacteristic(
    BluetoothService service,
    Guid uuid,
  ) {
    return service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
          (c) => c?.uuid == uuid,
          orElse: () => null,
        );
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
  }
}

