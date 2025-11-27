import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/ble_constants.dart';
import 'ble_service.dart';

// ignore_for_file: unawaited_futures

/// Implementation of BleService using flutter_blue_plus
class BleServiceImpl implements BleService {
  BluetoothDevice? _connectedDevice;
  List<BluetoothService>? _discoveredServices;
  BleConnectionInfo? _currentConnection;
  final Map<String, ScannedDevice> _scannedDevices = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final _connectionStateController =
      StreamController<BleConnectionInfo?>.broadcast();
  final _scanResultsController =
      StreamController<List<ScannedDevice>>.broadcast();

  bool _isScanning = false;
  int _reconnectionCount = 0;
  bool _autoReconnect = true;

  @override
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  @override
  Stream<BleConnectionInfo?> get connectionState =>
      _connectionStateController.stream;

  @override
  Stream<List<ScannedDevice>> get scanResults => _scanResultsController.stream;

  @override
  BleConnectionInfo? get currentConnection => _currentConnection;

  @override
  bool get isConnected =>
      _currentConnection?.state == BleConnectionState.connected;

  @override
  bool get isScanning => _isScanning;

  @override
  Future<void> initialize() async {
    // Set log level for debugging
    FlutterBluePlus.setLogLevel(LogLevel.warning);
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    await disconnect();
    await _connectionStateController.close();
    await _scanResultsController.close();
  }

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    List<Guid>? withServices,
  }) async {
    if (_isScanning) {
      await stopScan();
    }

    _scannedDevices.clear();
    _isScanning = true;

    _updateConnectionState(
      (_currentConnection ?? const BleConnectionInfo(
        deviceId: '',
        state: BleConnectionState.disconnected,
      )).copyWith(state: BleConnectionState.scanning),
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        // Filter for ZSWatch devices
        final deviceName = result.device.advName;
        if (deviceName.isNotEmpty &&
            deviceName.startsWith(BleConfig.deviceNamePrefix)) {
          final scanned = ScannedDevice(
            id: result.device.remoteId.str,
            name: deviceName,
            rssi: result.rssi,
            device: result.device,
            discoveredAt: DateTime.now(),
          );
          _scannedDevices[scanned.id] = scanned;
          _scanResultsController.add(_scannedDevices.values.toList());
        }
      }
    });

    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: withServices ?? [],
      androidScanMode: AndroidScanMode.lowLatency,
    );

    // Auto-stop tracking when scan completes
    unawaited(Future<void>.delayed(timeout, () {
      if (_isScanning) {
        _isScanning = false;
        if (_currentConnection?.state == BleConnectionState.scanning) {
          _updateConnectionState(
            _currentConnection!.copyWith(
              state: BleConnectionState.disconnected,
            ),
          );
        }
      }
    }));
  }

  @override
  Future<void> stopScan() async {
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
  }

  @override
  Future<void> connect(
    BluetoothDevice device, {
    bool autoReconnect = true,
  }) async {
    _autoReconnect = autoReconnect;
    _reconnectionCount = 0;

    _updateConnectionState(BleConnectionInfo(
      deviceId: device.remoteId.str,
      state: BleConnectionState.connecting,
    ));

    try {
      // Listen to connection state changes
      _connectionSubscription?.cancel();
      _connectionSubscription =
          device.connectionState.listen(_handleConnectionStateChange);

      await device.connect(
        license: License.free,
        timeout: BleConfig.connectionTimeout,
        mtu: autoReconnect ? null : 512, // autoConnect is incompatible with mtu
        autoConnect: autoReconnect,
      );

      _connectedDevice = device;

      _updateConnectionState(BleConnectionInfo(
        deviceId: device.remoteId.str,
        state: BleConnectionState.connected,
        connectedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        reconnectionCount: _reconnectionCount,
      ));
    } catch (e) {
      _updateConnectionState(BleConnectionInfo(
        deviceId: device.remoteId.str,
        state: BleConnectionState.error,
        reconnectionCount: _reconnectionCount,
      ));
      rethrow;
    }
  }

  void _handleConnectionStateChange(BluetoothConnectionState state) {
    if (_connectedDevice == null) return;

    switch (state) {
      case BluetoothConnectionState.connected:
        _updateConnectionState(
          (_currentConnection ?? BleConnectionInfo(
            deviceId: _connectedDevice!.remoteId.str,
            state: BleConnectionState.connected,
          )).copyWith(
            state: BleConnectionState.connected,
            connectedAt: _currentConnection?.connectedAt ?? DateTime.now(),
            lastActivityAt: DateTime.now(),
          ),
        );
      case BluetoothConnectionState.disconnected:
        if (_autoReconnect &&
            _reconnectionCount < BleConfig.maxReconnectionAttempts) {
          _handleReconnection();
        } else {
          _updateConnectionState(
            (_currentConnection ?? BleConnectionInfo(
              deviceId: _connectedDevice!.remoteId.str,
              state: BleConnectionState.disconnected,
            )).copyWith(
              state: BleConnectionState.disconnected,
            ),
          );
          _cleanupConnection();
        }
      // ignore: deprecated_member_use
      case BluetoothConnectionState.connecting:
        _updateConnectionState(
          (_currentConnection ?? BleConnectionInfo(
            deviceId: _connectedDevice!.remoteId.str,
            state: BleConnectionState.connecting,
          )).copyWith(
            state: BleConnectionState.connecting,
          ),
        );
      // ignore: deprecated_member_use
      case BluetoothConnectionState.disconnecting:
        // Transitional state - wait for disconnect
        break;
    }
  }

  Future<void> _handleReconnection() async {
    _reconnectionCount++;
    _updateConnectionState(
      (_currentConnection ?? BleConnectionInfo(
        deviceId: _connectedDevice!.remoteId.str,
        state: BleConnectionState.reconnecting,
      )).copyWith(
        state: BleConnectionState.reconnecting,
        reconnectionCount: _reconnectionCount,
      ),
    );

    await Future<void>.delayed(BleConfig.reconnectionDelay);

    if (_connectedDevice != null &&
        _reconnectionCount < BleConfig.maxReconnectionAttempts) {
      try {
        await _connectedDevice!.connect(
          timeout: BleConfig.connectionTimeout,
          autoConnect: true,
        );
      } catch (_) {
        // Will be handled by connection state listener
      }
    }
  }

  void _cleanupConnection() {
    _connectedDevice = null;
    _discoveredServices = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  @override
  Future<void> disconnect() async {
    _autoReconnect = false;
    final device = _connectedDevice;
    _cleanupConnection();

    if (device != null) {
      await device.disconnect();
    }

    _updateConnectionState(null);
  }

  @override
  Future<int> negotiateMtu(int requestedMtu) async {
    if (_connectedDevice == null) {
      throw StateError('Not connected to a device');
    }

    final mtu = await _connectedDevice!.requestMtu(requestedMtu);

    _updateConnectionState(
      _currentConnection?.copyWith(mtu: mtu),
    );

    return mtu;
  }

  @override
  Future<void> request2MPhy() async {
    if (_connectedDevice == null) {
      throw StateError('Not connected to a device');
    }

    // Request 2M PHY for faster throughput
    await _connectedDevice!.requestConnectionPriority(
      connectionPriorityRequest: ConnectionPriority.high,
    );

    // Note: PHY mode reporting is not directly available in flutter_blue_plus
    // The actual PHY negotiation happens at the BLE stack level
    _updateConnectionState(
      _currentConnection?.copyWith(phyMode: BlePhyMode.phy2M),
    );
  }

  @override
  Future<void> enableDle() async {
    // DLE is typically enabled automatically with MTU negotiation
    // on modern BLE stacks. This is a placeholder for explicit DLE handling.
    _updateConnectionState(
      _currentConnection?.copyWith(dleEnabled: true),
    );
  }

  @override
  Future<int> readRssi() async {
    if (_connectedDevice == null) {
      throw StateError('Not connected to a device');
    }

    final rssi = await _connectedDevice!.readRssi();

    _updateConnectionState(
      _currentConnection?.copyWith(rssi: rssi, lastActivityAt: DateTime.now()),
    );

    return rssi;
  }

  @override
  Future<List<BluetoothService>> discoverServices() async {
    if (_connectedDevice == null) {
      throw StateError('Not connected to a device');
    }

    _discoveredServices = await _connectedDevice!.discoverServices();
    return _discoveredServices!;
  }

  @override
  Future<void> writeCharacteristic(
    BluetoothCharacteristic characteristic,
    Uint8List data, {
    bool withResponse = true,
  }) async {
    await characteristic.write(
      data,
      withoutResponse: !withResponse,
    );

    _updateConnectionState(
      _currentConnection?.copyWith(lastActivityAt: DateTime.now()),
    );
  }

  @override
  Future<Uint8List> readCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    final data = await characteristic.read();

    _updateConnectionState(
      _currentConnection?.copyWith(lastActivityAt: DateTime.now()),
    );

    return Uint8List.fromList(data);
  }

  @override
  Future<Stream<Uint8List>> subscribeToCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    await characteristic.setNotifyValue(true);
    return characteristic.onValueReceived
        .map((data) => Uint8List.fromList(data));
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    await characteristic.setNotifyValue(false);
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  @override
  Future<void> requestBluetoothEnable() async {
    await FlutterBluePlus.turnOn();
  }

  @override
  BluetoothService? findService(Guid serviceUuid) {
    return _discoveredServices?.cast<BluetoothService?>().firstWhere(
          (s) => s?.uuid == serviceUuid,
          orElse: () => null,
        );
  }

  @override
  BluetoothCharacteristic? findCharacteristic(
    BluetoothService service,
    Guid characteristicUuid,
  ) {
    return service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
          (c) => c?.uuid == characteristicUuid,
          orElse: () => null,
        );
  }

  void _updateConnectionState(BleConnectionInfo? state) {
    _currentConnection = state;
    _connectionStateController.add(state);
  }
}

