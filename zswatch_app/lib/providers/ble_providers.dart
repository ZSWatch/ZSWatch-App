import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/models/connection.dart';
import '../data/models/connection_state.dart';
import '../services/ble/ble_scanner.dart';
import 'base_async_notifier.dart';
import 'watch_service_provider.dart';

/// Provider for the BLE scanner singleton.
final bleScannerProvider = Provider<BleScanner>((ref) {
  final scanner = BleScanner();
  ref.onDispose(() => scanner.dispose());
  return scanner;
});

/// Provider for Bluetooth adapter state.
final bluetoothAdapterStateProvider =
    StreamProvider<BluetoothAdapterState>((ref) {
  return FlutterBluePlus.adapterState;
});

/// Provider for whether Bluetooth is available and on.
final isBluetoothAvailableProvider = Provider<bool>((ref) {
  final adapterState = ref.watch(bluetoothAdapterStateProvider);
  return adapterState.valueOrNull == BluetoothAdapterState.on;
});

/// Provider for scanned devices during scan.
final scannedDevicesProvider = StreamProvider<List<ScannedWatch>>((ref) {
  final scanner = ref.watch(bleScannerProvider);
  return scanner.scanResults;
});

/// Provider for whether currently scanning.
final isScanningProvider = StreamProvider<bool>((ref) {
  return FlutterBluePlus.isScanning;
});

/// Provider for BLE connection state — derives from BleConnectionService.
final bleConnectionProvider = StreamProvider<Connection>((ref) {
  final ble = ref.watch(bleConnectionServiceProvider);
  return ble.connectionStream;
});

/// Provider for current connection info (non-stream).
final currentConnectionProvider = Provider<Connection?>((ref) {
  final asyncValue = ref.watch(bleConnectionProvider);
  return asyncValue.valueOrNull;
});

/// Provider for connection state enum.
final connectionStateProvider = Provider<WatchConnectionState>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.state ?? WatchConnectionState.disconnected;
});

/// Provider for connection status (simplified boolean).
final isConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(connectionStateProvider);
  return state == WatchConnectionState.connected;
});

/// Provider for whether connecting or reconnecting.
final isConnectingProvider = Provider<bool>((ref) {
  final state = ref.watch(connectionStateProvider);
  return state.isConnectingOrReconnecting;
});

/// Provider for connection RSSI.
final connectionRssiProvider = Provider<int?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.rssi;
});

/// Provider for connection MTU.
final connectionMtuProvider = Provider<int?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.mtu;
});

/// Provider for connected watch ID.
final connectedWatchIdProvider = Provider<String?>((ref) {
  final connection = ref.watch(currentConnectionProvider);
  return connection?.isConnected == true ? connection?.watchId : null;
});

/// Notifier for BLE operations (scanning, permissions).
class BleNotifier extends BaseAsyncNotifier {
  final BleScanner _scanner;

  BleNotifier(this._scanner);

  /// Initialize BLE (check adapter state).
  Future<void> initialize() => run(() async {
        await FlutterBluePlus.adapterState.first;
      });

  /// Request Bluetooth permissions.
  Future<bool> requestPermissions() async {
    try {
      await FlutterBluePlus.startScan(
          timeout: const Duration(milliseconds: 100));
      await FlutterBluePlus.stopScan();
      return true;
    } catch (e) {
      final results = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ].request();

      final hasBluetooth =
          (results[Permission.bluetoothScan]?.isGranted ?? false) ||
              (results[Permission.bluetooth]?.isGranted ?? false);
      final hasConnect =
          results[Permission.bluetoothConnect]?.isGranted ?? true;

      return hasBluetooth && hasConnect;
    }
  }

  /// Check if permissions are granted.
  Future<bool> checkPermissions() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothAdapterState.unknown,
      );
      return adapterState != BluetoothAdapterState.unauthorized;
    } catch (e) {
      return false;
    }
  }

  /// Start scanning for devices.
  Future<void> startScan({Duration? timeout}) => run(() async {
        await _scanner.startScan(
          timeout: timeout ?? const Duration(seconds: 15),
        );
      });

  /// Stop scanning.
  Future<void> stopScan() async {
    await _scanner.stopScan();
    reset();
  }

  /// Turn on Bluetooth (Android only).
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // May not be supported
    }
  }

  /// Open Bluetooth settings.
  Future<void> openBluetoothSettings() async {
    await openAppSettings();
  }
}

/// Provider for BLE operations notifier.
final bleNotifierProvider =
    StateNotifierProvider<BleNotifier, AsyncValue<void>>((ref) {
  final scanner = ref.watch(bleScannerProvider);
  return BleNotifier(scanner);
});

/// Provider for BLE permission status.
final blePermissionsProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.read(bleNotifierProvider.notifier);
  return notifier.checkPermissions();
});
