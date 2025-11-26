import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE connection state
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  bonding,
  connected,
  reconnecting,
  error,
}

/// PHY mode for BLE connection
enum BlePhyMode {
  phy1M,
  phy2M,
}

/// Connection metadata
class BleConnectionInfo {
  final String deviceId;
  final BleConnectionState state;
  final int? rssi;
  final int? mtu;
  final BlePhyMode? phyMode;
  final bool dleEnabled;
  final int reconnectionCount;
  final DateTime? connectedAt;
  final DateTime? lastActivityAt;

  const BleConnectionInfo({
    required this.deviceId,
    required this.state,
    this.rssi,
    this.mtu,
    this.phyMode,
    this.dleEnabled = false,
    this.reconnectionCount = 0,
    this.connectedAt,
    this.lastActivityAt,
  });

  BleConnectionInfo copyWith({
    String? deviceId,
    BleConnectionState? state,
    int? rssi,
    int? mtu,
    BlePhyMode? phyMode,
    bool? dleEnabled,
    int? reconnectionCount,
    DateTime? connectedAt,
    DateTime? lastActivityAt,
  }) {
    return BleConnectionInfo(
      deviceId: deviceId ?? this.deviceId,
      state: state ?? this.state,
      rssi: rssi ?? this.rssi,
      mtu: mtu ?? this.mtu,
      phyMode: phyMode ?? this.phyMode,
      dleEnabled: dleEnabled ?? this.dleEnabled,
      reconnectionCount: reconnectionCount ?? this.reconnectionCount,
      connectedAt: connectedAt ?? this.connectedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }
}

/// Scanned device result
class ScannedDevice {
  final String id;
  final String name;
  final int rssi;
  final BluetoothDevice device;
  final DateTime discoveredAt;

  const ScannedDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
    required this.discoveredAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Abstract BLE service interface
///
/// Provides a clean abstraction over flutter_blue_plus for BLE operations.
/// This allows for easy mocking in tests and potential platform-specific
/// implementations.
abstract class BleService {
  /// Stream of BLE adapter state (on/off/unauthorized)
  Stream<BluetoothAdapterState> get adapterState;

  /// Stream of connection state changes
  Stream<BleConnectionInfo?> get connectionState;

  /// Stream of scanned devices during scan
  Stream<List<ScannedDevice>> get scanResults;

  /// Current connection info (null if not connected)
  BleConnectionInfo? get currentConnection;

  /// Check if currently connected
  bool get isConnected;

  /// Check if currently scanning
  bool get isScanning;

  /// Initialize the BLE service
  Future<void> initialize();

  /// Dispose resources
  Future<void> dispose();

  /// Start scanning for ZSWatch devices
  ///
  /// [timeout] - Duration to scan before auto-stopping
  /// [withServices] - Filter by service UUIDs (optional)
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    List<Guid>? withServices,
  });

  /// Stop scanning
  Future<void> stopScan();

  /// Connect to a device
  ///
  /// [device] - The device to connect to
  /// [autoReconnect] - Whether to auto-reconnect on disconnect
  Future<void> connect(
    BluetoothDevice device, {
    bool autoReconnect = true,
  });

  /// Disconnect from current device
  Future<void> disconnect();

  /// Negotiate MTU (Maximum Transmission Unit)
  ///
  /// Returns the negotiated MTU size.
  Future<int> negotiateMtu(int requestedMtu);

  /// Request 2M PHY mode for faster throughput
  Future<void> request2MPhy();

  /// Enable Data Length Extension (DLE)
  Future<void> enableDle();

  /// Read RSSI from connected device
  Future<int> readRssi();

  /// Discover services on connected device
  Future<List<BluetoothService>> discoverServices();

  /// Write data to a characteristic
  Future<void> writeCharacteristic(
    BluetoothCharacteristic characteristic,
    Uint8List data, {
    bool withResponse = true,
  });

  /// Read data from a characteristic
  Future<Uint8List> readCharacteristic(BluetoothCharacteristic characteristic);

  /// Subscribe to characteristic notifications
  Future<Stream<Uint8List>> subscribeToCharacteristic(
    BluetoothCharacteristic characteristic,
  );

  /// Unsubscribe from characteristic notifications
  Future<void> unsubscribeFromCharacteristic(
    BluetoothCharacteristic characteristic,
  );

  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable();

  /// Request Bluetooth to be enabled (Android only)
  Future<void> requestBluetoothEnable();

  /// Find a service by UUID on the connected device
  BluetoothService? findService(Guid serviceUuid);

  /// Find a characteristic by UUID within a service
  BluetoothCharacteristic? findCharacteristic(
    BluetoothService service,
    Guid characteristicUuid,
  );
}

