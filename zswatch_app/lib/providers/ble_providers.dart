import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../services/ble/ble_connection_manager.dart';
import '../services/ble/ble_scanner.dart';

/// Provider for the BLE scanner singleton
final bleScannerProvider = Provider<BleScanner>((ref) {
  final scanner = BleScanner();
  ref.onDispose(() => scanner.dispose());
  return scanner;
});

/// Provider for the BLE connection manager singleton
final bleConnectionManagerProvider = Provider<BleConnectionManager>((ref) {
  final manager = BleConnectionManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Provider for Bluetooth adapter state
final bluetoothAdapterStateProvider =
    StreamProvider<BluetoothAdapterState>((ref) {
  return FlutterBluePlus.adapterState;
});

/// Provider for whether Bluetooth is available and on
final isBluetoothAvailableProvider = Provider<bool>((ref) {
  final adapterState = ref.watch(bluetoothAdapterStateProvider);
  return adapterState.valueOrNull == BluetoothAdapterState.on;
});

/// Provider for scanned devices during scan
final scannedDevicesProvider = StreamProvider<List<ScannedWatch>>((ref) {
  final scanner = ref.watch(bleScannerProvider);
  return scanner.scanResults;
});

/// Provider for whether currently scanning
/// Provider for whether currently scanning (reactive stream)
final isScanningProvider = StreamProvider<bool>((ref) {
  return FlutterBluePlus.isScanning;
});

/// Provider for BLE connection state
final bleConnectionProvider = StreamProvider<Connection>((ref) {
  final manager = ref.watch(bleConnectionManagerProvider);
  return manager.connectionStream;
});

/// Provider for current connection info (non-stream)
final currentConnectionProvider = Provider<Connection?>((ref) {
  final asyncValue = ref.watch(bleConnectionProvider);
  return asyncValue.valueOrNull;
});

/// Provider for connection state enum
final connectionStateProvider = Provider<WatchConnectionState>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.state ?? WatchConnectionState.disconnected;
});

/// Provider for connection status (simplified boolean)
final isConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(connectionStateProvider);
  return state == WatchConnectionState.connected;
});

/// Provider for whether connecting or reconnecting
final isConnectingProvider = Provider<bool>((ref) {
  final state = ref.watch(connectionStateProvider);
  return state.isConnectingOrReconnecting;
});

/// Provider for connection RSSI
final connectionRssiProvider = Provider<int?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.rssi;
});

/// Provider for connection MTU
final connectionMtuProvider = Provider<int?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.mtu;
});

/// Provider for connected watch ID
final connectedWatchIdProvider = Provider<String?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.isConnected == true ? connection?.watchId : null;
});

/// Notifier for BLE operations
class BleNotifier extends StateNotifier<AsyncValue<void>> {
  final BleScanner _scanner;
  final BleConnectionManager _connectionManager;

  BleNotifier(this._scanner, this._connectionManager)
      : super(const AsyncValue.data(null));

  /// Initialize BLE (check adapter state)
  Future<void> initialize() async {
    state = const AsyncValue.loading();
    try {
      // Wait for adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        // BLE not available - not an error, just a state
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Request Bluetooth permissions using flutter_blue_plus
  Future<bool> requestPermissions() async {
    // Use flutter_blue_plus's built-in permission handling
    // This properly handles Android 12+ vs older versions
    try {
      // This triggers the system permission dialog
      await FlutterBluePlus.startScan(timeout: const Duration(milliseconds: 100));
      await FlutterBluePlus.stopScan();
      return true;
    } catch (e) {
      // If scan fails due to permissions, try requesting manually
      final results = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ].request();

      // Check if we got what we need
      final hasBluetooth = (results[Permission.bluetoothScan]?.isGranted ?? false) ||
                           (results[Permission.bluetooth]?.isGranted ?? false);
      final hasConnect = results[Permission.bluetoothConnect]?.isGranted ?? true;
      
      return hasBluetooth && hasConnect;
    }
  }

  /// Check if permissions are granted
  Future<bool> checkPermissions() async {
    // Quick check - try to get adapter state
    try {
      final state = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothAdapterState.unknown,
      );
      // If we can read adapter state, permissions are likely OK
      return state != BluetoothAdapterState.unauthorized;
    } catch (e) {
      return false;
    }
  }

  /// Start scanning for devices
  Future<void> startScan({Duration? timeout}) async {
    state = const AsyncValue.loading();
    try {
      await _scanner.startScan(
        timeout: timeout ?? const Duration(seconds: 15),
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await _scanner.stopScan();
    state = const AsyncValue.data(null);
  }

  /// Connect to a scanned device
  Future<void> connect(ScannedWatch device) async {
    state = const AsyncValue.loading();
    try {
      await _connectionManager.connect(device);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Connect to a device by ID (saved device)
  Future<void> connectById(String deviceId) async {
    state = const AsyncValue.loading();
    try {
      await _connectionManager.connectById(deviceId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Cancel pending connection
  void cancelPendingConnection() {
    _connectionManager.cancelPendingConnection();
    state = const AsyncValue.data(null);
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    state = const AsyncValue.loading();
    try {
      await _connectionManager.disconnect();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Read RSSI
  Future<int?> readRssi() async {
    try {
      return await _connectionManager.readRssi();
    } catch (_) {
      return null;
    }
  }

  /// Turn on Bluetooth (Android only)
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // May not be supported
    }
  }

  /// Open Bluetooth settings
  Future<void> openBluetoothSettings() async {
    await openAppSettings();
  }
}

/// Provider for BLE operations notifier
final bleNotifierProvider =
    StateNotifierProvider<BleNotifier, AsyncValue<void>>((ref) {
  final scanner = ref.watch(bleScannerProvider);
  final connectionManager = ref.watch(bleConnectionManagerProvider);
  return BleNotifier(scanner, connectionManager);
});

/// Provider for BLE permission status
final blePermissionsProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.read(bleNotifierProvider.notifier);
  return notifier.checkPermissions();
});
