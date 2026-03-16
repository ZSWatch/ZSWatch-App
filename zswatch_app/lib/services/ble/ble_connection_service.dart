import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/ble_constants.dart';
import '../../data/models/connection.dart';
import '../../data/models/connection_phase.dart';
import '../../data/models/connection_state.dart';
import 'ble_scanner.dart';

/// Single source of truth for BLE connection lifecycle.
///
/// Replaces the connection/reconnect logic that was previously scattered
/// across WatchService, BleConnectionManager, and WatchStateProvider.
///
/// All connection-related providers derive their state from this service's
/// [phaseStream] and [connectionStream].
class BleConnectionService {
  BluetoothDevice? _device;
  List<BluetoothService>? _services;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _reconnectTimer;
  Timer? _rssiTimer;

  // Phase is the primary state — no boolean flags needed.
  final _phaseController = BehaviorSubject<ConnectionPhase>.seeded(
    const ConnectionPhase.disconnected(),
  );

  // Connection model for backwards compatibility with UI code.
  final _connectionController = BehaviorSubject<Connection>.seeded(
    const Connection(watchId: '', state: WatchConnectionState.disconnected),
  );

  // Callback for post-connection setup (NUS, battery, sync) — owned by WatchService.
  Future<void> Function(BluetoothDevice device, List<BluetoothService> services,
      String watchId, String name)? onSetupRequired;

  int _reconnectAttempts = 0;
  static const int _maxQuickReconnectAttempts = 3;

  // Minimal flags that can't be expressed in ConnectionPhase:
  bool _isCancelled = false; // User requested cancellation
  bool _autoReconnect = true;
  String _watchId = '';
  String _watchName = '';

  // --- Public API ---

  /// Stream of connection phase changes (primary state).
  Stream<ConnectionPhase> get phaseStream => _phaseController.stream;

  /// Current connection phase.
  ConnectionPhase get currentPhase => _phaseController.value;

  /// Stream of Connection model changes (for backwards compat).
  Stream<Connection> get connectionStream => _connectionController.stream;

  /// Current Connection model.
  Connection get currentConnection => _connectionController.value;

  /// Currently connected BLE device (for GATT operations by WatchService).
  BluetoothDevice? get device => _device;

  /// Discovered BLE services (for GATT operations by WatchService).
  List<BluetoothService>? get services => _services;

  /// Whether fully connected and operational.
  bool get isConnected => currentPhase is Connected;

  /// The watch ID we're connected/connecting to.
  String get watchId => _watchId;

  /// Connect to a scanned device.
  Future<void> connect(ScannedWatch scannedDevice,
      {bool autoConnect = false}) async {
    if (!autoConnect) {
      _isCancelled = false;
    }
    await _connectToDevice(
        scannedDevice.device, scannedDevice.id, scannedDevice.name,
        autoConnect: autoConnect);
  }

  /// Connect by device ID (for saved watches / auto-reconnect).
  Future<void> connectById(String deviceId,
      {bool autoConnect = false}) async {
    if (!autoConnect) {
      _isCancelled = false;
    }
    final device = BluetoothDevice.fromId(deviceId);
    await _connectToDevice(device, deviceId, 'ZSWatch',
        autoConnect: autoConnect);
  }

  /// Cancel any pending connection attempt.
  void cancelPendingConnection() {
    debugPrint('[BleConnectionService] cancelPendingConnection()');
    _isCancelled = true;
    _autoReconnect = false;
    _reconnectTimer?.cancel();

    final phase = currentPhase;
    if (phase.isTryingToConnect) {
      final device = _device;
      if (device != null) {
        device.disconnect();
      } else if (_watchId.isNotEmpty) {
        BluetoothDevice.fromId(_watchId).disconnect();
      }
      _cleanup();
      _setPhase(const ConnectionPhase.disconnected());
    }
  }

  /// Disconnect from current device.
  Future<void> disconnect() async {
    _autoReconnect = false;
    _isCancelled = true;
    _reconnectTimer?.cancel();

    final device = _device;
    _cleanup();

    if (device != null) {
      try {
        await device.disconnect();
      } catch (e) {
        debugPrint(
            '[BleConnectionService] disconnect() error (ignored): $e');
      }
    }

    _setPhase(const ConnectionPhase.disconnected());
  }

  /// Re-discover BLE services on the connected device.
  Future<bool> rediscoverServices() async {
    if (_device == null || !isConnected) return false;
    debugPrint('[BleConnectionService] Re-discovering services...');
    try {
      _services = await _device!.discoverServices();
      final hasSmp = _findService(_guid(McumgrUuids.service)) != null;
      debugPrint(
          '[BleConnectionService] Re-discovery complete. SMP available: $hasSmp');
      return hasSmp;
    } catch (e) {
      debugPrint('[BleConnectionService] Re-discovery failed: $e');
      return false;
    }
  }

  /// Whether SMP/MCUmgr service is available.
  bool get hasSmpService => _findService(_guid(McumgrUuids.service)) != null;

  /// Read RSSI and update connection model.
  Future<void> readAndUpdateRssi() async {
    if (_device == null || !isConnected) return;
    try {
      final rssi = await _device!.readRssi();
      _updateConnectionModel(currentConnection.copyWith(rssi: rssi));
    } catch (e) {
      debugPrint('[BleConnectionService] Failed to read RSSI: $e');
    }
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await disconnect();
    await _phaseController.close();
    await _connectionController.close();
  }

  // --- Internal connection logic ---

  Future<void> _connectToDevice(
    BluetoothDevice device,
    String watchId,
    String name, {
    bool autoConnect = false,
    bool isReconnectAttempt = false,
  }) async {
    debugPrint(
        '[BleConnectionService] _connectToDevice: watchId=$watchId, '
        'autoConnect=$autoConnect, isReconnect=$isReconnectAttempt, '
        'phase=$currentPhase');

    if (_isCancelled) return;

    // Already connected to this device
    if (isConnected && _device?.remoteId.str == watchId) return;

    // Already in a connecting sub-state
    final phase = currentPhase;
    if (phase is Connecting || phase is SettingUp) return;

    if (!isReconnectAttempt) {
      _autoReconnect = true;
      _reconnectAttempts = 0;
    }

    _watchId = watchId;
    _watchName = name;

    try {
      _setPhase(const ConnectionPhase.connecting());

      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen(
        (state) => _handleBleStateChange(state, watchId, name),
      );
      _device = device;

      if (autoConnect) {
        if (_isCancelled) return;
        unawaited(device
            .connect(
          license: License.free,
          timeout: const Duration(seconds: 0),
          mtu: null,
          autoConnect: true,
        )
            .catchError((Object e) {
          debugPrint(
              '[BleConnectionService] AutoConnect error (ignored): $e');
        }));
      } else {
        if (_isCancelled) return;
        final timeout = isReconnectAttempt
            ? const Duration(seconds: 10)
            : BleConfig.connectionTimeout;
        await device.connect(
          license: License.free,
          timeout: timeout,
          autoConnect: false,
        );
        await _runSetup(watchId, name);
      }
    } catch (e) {
      _setPhase(ConnectionPhase.error(
        type: ConnectionErrorType.timeout,
        details: e.toString(),
      ));
      rethrow;
    }
  }

  /// Run post-connection setup (bonding, service discovery, MTU, then
  /// hand off to WatchService for NUS/battery/sync via callback).
  Future<void> _runSetup(String watchId, String name) async {
    if (_isCancelled || _device == null || !_device!.isConnected) return;

    _setPhase(const ConnectionPhase.settingUp(step: SetupStep.bonding));

    try {
      // Bonding (Android only)
      if (Platform.isAndroid) {
        if (!_shouldContinue()) return;
        final bondState = await _device!.bondState.first;
        if (!_shouldContinue()) return;
        if (bondState != BluetoothBondState.bonded) {
          await _device!.createBond();
          if (!_shouldContinue()) return;
        }
      }

      // Service discovery
      _setPhase(const ConnectionPhase.settingUp(
          step: SetupStep.discoveringServices));
      if (!_shouldContinue()) return;
      _services = await _device!.discoverServices();

      // MTU negotiation
      int mtu;
      if (Platform.isAndroid) {
        _setPhase(
            const ConnectionPhase.settingUp(step: SetupStep.negotiating));
        if (!_shouldContinue()) return;
        mtu = await _device!.requestMtu(BleConfig.preferredMtu);
      } else {
        mtu = AppConstants.minimumAcceptableMtu;
      }

      // Syncing phase — hand off to WatchService for NUS, battery, time sync
      _setPhase(const ConnectionPhase.settingUp(step: SetupStep.syncing));
      if (!_shouldContinue()) return;

      // Update connection model with MTU before callback
      _updateConnectionModel(currentConnection.copyWith(
        mtu: mtu,
        connectedAt: DateTime.now(),
      ));

      // Let WatchService do NUS setup, battery, time sync, device info
      if (onSetupRequired != null) {
        await onSetupRequired!(_device!, _services!, watchId, name);
      }

      if (!_shouldContinue()) return;

      // Fully connected
      _setPhase(const ConnectionPhase.connected());
      _reconnectAttempts = 0;

      // Start RSSI updates
      await readAndUpdateRssi();
      _startRssiUpdates();
    } catch (e) {
      debugPrint('[BleConnectionService] Setup error: $e');
      if (_device != null && _device!.isConnected) {
        // Device still connected but setup failed — disconnect and let
        // reconnect handle it
        try {
          await _device!.disconnect();
        } catch (_) {}
      } else if (_autoReconnect && !_isCancelled) {
        // Device already disconnected during setup — schedule reconnect
        _scheduleReconnect(watchId, name);
      }
    }
  }

  bool _shouldContinue() {
    if (_isCancelled) return false;
    if (_device == null) return false;
    if (!_device!.isConnected) return false;
    return true;
  }

  void _handleBleStateChange(
    BluetoothConnectionState state,
    String watchId,
    String name,
  ) {
    debugPrint(
        '[BleConnectionService] BLE state: $state, phase: $currentPhase');

    if (_isCancelled) {
      if (state == BluetoothConnectionState.connected) {
        BluetoothDevice.fromId(watchId).disconnect();
      }
      return;
    }

    switch (state) {
      case BluetoothConnectionState.connected:
        final phase = currentPhase;
        // For autoConnect or background reconnect — BLE layer reports connected,
        // we need to run setup.
        if ((phase is Connecting || phase is Reconnecting) &&
            phase is! SettingUp) {
          if (!_autoReconnect) {
            _device?.disconnect();
            _cleanup();
            _setPhase(const ConnectionPhase.disconnected());
            return;
          }
          _runSetup(watchId, name);
        }
        break;

      case BluetoothConnectionState.disconnected:
        _handleDisconnect(watchId, name);
        break;

      // ignore: deprecated_member_use
      case BluetoothConnectionState.connecting:
      // ignore: deprecated_member_use
      case BluetoothConnectionState.disconnecting:
        break;
    }
  }

  void _handleDisconnect(String watchId, String name) {
    debugPrint(
        '[BleConnectionService] _handleDisconnect: phase=$currentPhase, '
        'cancelled=$_isCancelled, autoReconnect=$_autoReconnect, '
        'attempts=$_reconnectAttempts');

    if (_isCancelled) {
      _setPhase(const ConnectionPhase.disconnected());
      _cleanup();
      return;
    }

    final phase = currentPhase;

    // If we're in background reconnect, stay in reconnecting state
    if (phase is Reconnecting && phase.isBackground) {
      return;
    }

    // If we're in connecting/autoConnect phase, this may be the initial
    // spurious disconnect notification — ignore it
    if (phase is Connecting) {
      return;
    }

    // If setup is in progress, let setup detect via _shouldContinue()
    if (phase is SettingUp) {
      // Setup will fail and trigger reconnect from its catch block
      return;
    }

    // Was previously connected or in a connecting state
    final shouldReconnect = _autoReconnect &&
        (phase is Connected ||
            phase is SettingUp ||
            phase.isTryingToConnect);

    if (shouldReconnect &&
        _reconnectAttempts < _maxQuickReconnectAttempts) {
      _scheduleReconnect(watchId, name);
    } else if (shouldReconnect) {
      _startBackgroundReconnect(watchId, name);
    } else {
      _setPhase(const ConnectionPhase.disconnected());
      _cleanup();
    }
  }

  void _scheduleReconnect(String watchId, String name) {
    if (_isCancelled) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    _setPhase(ConnectionPhase.reconnecting(attempt: _reconnectAttempts));

    _reconnectTimer = Timer(BleConfig.reconnectionDelay, () async {
      if (_isCancelled) return;
      if (!_autoReconnect) return;

      try {
        _device = BluetoothDevice.fromId(watchId);
        await _connectionSubscription?.cancel();
        _connectionSubscription = _device!.connectionState.listen(
          (state) => _handleBleStateChange(state, watchId, name),
        );
        await _connectToDevice(_device!, watchId, name,
            isReconnectAttempt: true);
      } catch (e) {
        debugPrint(
            '[BleConnectionService] Reconnect attempt $_reconnectAttempts failed: $e');
        if (_isCancelled) {
          _cleanup();
          return;
        }
        if (_reconnectAttempts >= _maxQuickReconnectAttempts) {
          _startBackgroundReconnect(watchId, name);
        } else {
          _scheduleReconnect(watchId, name);
        }
      }
    });
  }

  void _startBackgroundReconnect(String watchId, String name) {
    if (_isCancelled) return;
    _reconnectTimer?.cancel();

    _setPhase(ConnectionPhase.reconnecting(
      attempt: _reconnectAttempts,
      isBackground: true,
    ));

    _scheduleBackgroundAttempt(watchId, name);
  }

  void _scheduleBackgroundAttempt(String watchId, String name) {
    if (_isCancelled) return;
    final phase = currentPhase;
    if (phase is! Reconnecting || !phase.isBackground) return;

    final attemptNumber = _reconnectAttempts - _maxQuickReconnectAttempts;
    final delaySeconds = (5 + (attemptNumber * 5)).clamp(5, 15);

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_isCancelled) return;
      final p = currentPhase;
      if (p is! Reconnecting || !p.isBackground) return;

      _reconnectAttempts++;
      debugPrint(
          '[BleConnectionService] Background reconnect attempt $_reconnectAttempts');

      _device = BluetoothDevice.fromId(watchId);
      await _connectionSubscription?.cancel();
      _connectionSubscription = _device!.connectionState.listen(
        (state) => _handleBleStateChange(state, watchId, name),
      );

      try {
        await _device!.connect(
          license: License.free,
          timeout: const Duration(seconds: 10),
          autoConnect: false,
        );
        // Connection succeeded — handleBleStateChange will trigger setup
      } catch (e) {
        debugPrint(
            '[BleConnectionService] Background reconnect failed: $e');
        if (!_isCancelled) {
          final cp = currentPhase;
          if (cp is Reconnecting && cp.isBackground) {
            _scheduleBackgroundAttempt(watchId, name);
          }
        }
      }
    });
  }

  void _startRssiUpdates() {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      readAndUpdateRssi();
    });
  }

  void _stopRssiUpdates() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
  }

  void _cleanup() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopRssiUpdates();
    _device = null;
    _services = null;
  }

  void _setPhase(ConnectionPhase phase) {
    _phaseController.add(phase);
    // Keep Connection model in sync for backwards compat
    _updateConnectionModel(Connection(
      watchId: _watchId,
      watchName: _watchName,
      state: phase.watchConnectionState,
      rssi: currentConnection.rssi,
      mtu: currentConnection.mtu,
      phyMode: currentConnection.phyMode,
      dleEnabled: currentConnection.dleEnabled,
      isCharging: currentConnection.isCharging,
      reconnectionCount: _reconnectAttempts,
      connectedAt: phase is Connected ? currentConnection.connectedAt : null,
      lastActivityAt: currentConnection.lastActivityAt,
      errorType: phase is PhaseError ? phase.type : null,
      errorDetails: phase is PhaseError ? phase.details : null,
    ));
  }

  /// Update connection model fields (e.g. isCharging from protocol messages).
  /// Used by WatchService to update charging state from protocol data.
  void updateConnectionField(Connection Function(Connection) updater) {
    final updated = updater(_connectionController.value);
    _connectionController.add(updated);
  }

  void _updateConnectionModel(Connection connection) {
    _connectionController.add(connection);
  }

  BluetoothService? _findService(Guid uuid) {
    return _services?.cast<BluetoothService?>().firstWhere(
          (s) => s?.uuid == uuid,
          orElse: () => null,
        );
  }
}

Guid _guid(String uuid) => Guid(uuid);
