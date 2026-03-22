import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/ble_uuids.dart';
import 'ble_service.dart';

/// Helper class for GATT operations
///
/// Provides high-level methods for common BLE GATT operations
/// used in ZSWatch communication.
class GattOperations {
  final BleService _bleService;
  StreamSubscription<Uint8List>? _nusSubscription;
  final _nusDataController = StreamController<String>.broadcast();

  GattOperations(this._bleService);

  /// Stream of NUS data (decoded strings from Gadgetbridge protocol)
  Stream<String> get nusDataStream => _nusDataController.stream;

  /// Dispose resources
  Future<void> dispose() async {
    await _nusSubscription?.cancel();
    await _nusDataController.close();
  }

  /// Setup NUS (Nordic UART Service) for Gadgetbridge communication
  ///
  /// Discovers services and subscribes to the NUS RX characteristic.
  Future<void> setupNus() async {
    final services = await _bleService.discoverServices();

    // Find NUS service
    final nusService = services.cast<BluetoothService?>().firstWhere(
      (s) => s?.uuid == NusUuids.service,
      orElse: () => null,
    );

    if (nusService == null) {
      throw StateError('NUS service not found on device');
    }

    // Find RX characteristic (notify)
    final rxChar = nusService.characteristics
        .cast<BluetoothCharacteristic?>()
        .firstWhere(
          (c) => c?.uuid == NusUuids.rxCharacteristic,
          orElse: () => null,
        );

    if (rxChar == null) {
      throw StateError('NUS RX characteristic not found');
    }

    // Subscribe to notifications
    final stream = await _bleService.subscribeToCharacteristic(rxChar);
    _nusSubscription = stream.listen(_handleNusData);
  }

  void _handleNusData(Uint8List data) {
    try {
      // Decode as UTF-8 string
      final message = utf8.decode(data);
      _nusDataController.add(message);
    } catch (e) {
      // If UTF-8 decode fails, try as raw bytes
      _nusDataController.addError(e);
    }
  }

  /// Send data via NUS (Nordic UART Service)
  Future<void> sendNusData(String data) async {
    final services = _bleService.findService(NusUuids.service);
    if (services == null) {
      throw StateError('NUS service not available');
    }

    final txChar = _bleService.findCharacteristic(
      services,
      NusUuids.txCharacteristic,
    );

    if (txChar == null) {
      throw StateError('NUS TX characteristic not found');
    }

    final bytes = Uint8List.fromList(utf8.encode(data));
    await _bleService.writeCharacteristic(txChar, bytes);
  }

  /// Read battery level from standard Battery Service
  Future<int?> readBatteryLevel() async {
    final service = _bleService.findService(BatteryUuids.service);
    if (service == null) return null;

    final char = _bleService.findCharacteristic(service, BatteryUuids.level);
    if (char == null) return null;

    final data = await _bleService.readCharacteristic(char);
    if (data.isEmpty) return null;

    return data[0];
  }

  /// Subscribe to battery level notifications
  Future<Stream<int>?> subscribeToBatteryLevel() async {
    final service = _bleService.findService(BatteryUuids.service);
    if (service == null) return null;

    final char = _bleService.findCharacteristic(service, BatteryUuids.level);
    if (char == null) return null;

    final stream = await _bleService.subscribeToCharacteristic(char);
    return stream.map((data) => data.isNotEmpty ? data[0] : 0);
  }

  /// Subscribe to heart rate measurements
  Future<Stream<int>?> subscribeToHeartRate() async {
    final service = _bleService.findService(HeartRateUuids.service);
    if (service == null) return null;

    final char = _bleService.findCharacteristic(
      service,
      HeartRateUuids.measurement,
    );
    if (char == null) return null;

    final stream = await _bleService.subscribeToCharacteristic(char);
    return stream.map(_parseHeartRateMeasurement);
  }

  /// Parse heart rate measurement per Bluetooth specification
  int _parseHeartRateMeasurement(Uint8List data) {
    if (data.isEmpty) return 0;

    // First byte contains flags
    final flags = data[0];
    final isUint16 = (flags & 0x01) != 0;

    if (isUint16 && data.length >= 3) {
      // 16-bit heart rate value
      return data[1] | (data[2] << 8);
    } else if (data.length >= 2) {
      // 8-bit heart rate value
      return data[1];
    }

    return 0;
  }

  /// Read device information from Device Information Service
  Future<Map<String, String>> readDeviceInfo() async {
    final info = <String, String>{};

    final service = _bleService.findService(DeviceInfoUuids.service);
    if (service == null) return info;

    // Read manufacturer name
    final manufacturerChar = _bleService.findCharacteristic(
      service,
      DeviceInfoUuids.manufacturerName,
    );
    if (manufacturerChar != null) {
      final data = await _bleService.readCharacteristic(manufacturerChar);
      info['manufacturer'] = utf8.decode(data);
    }

    // Read model number
    final modelChar = _bleService.findCharacteristic(
      service,
      DeviceInfoUuids.modelNumber,
    );
    if (modelChar != null) {
      final data = await _bleService.readCharacteristic(modelChar);
      info['model'] = utf8.decode(data);
    }

    // Read firmware revision
    final firmwareChar = _bleService.findCharacteristic(
      service,
      DeviceInfoUuids.firmwareRevision,
    );
    if (firmwareChar != null) {
      final data = await _bleService.readCharacteristic(firmwareChar);
      info['firmware'] = utf8.decode(data);
    }

    // Read hardware revision
    final hardwareChar = _bleService.findCharacteristic(
      service,
      DeviceInfoUuids.hardwareRevision,
    );
    if (hardwareChar != null) {
      final data = await _bleService.readCharacteristic(hardwareChar);
      info['hardware'] = utf8.decode(data);
    }

    return info;
  }

  /// Check if a service is available on the connected device
  bool hasService(Guid serviceUuid) {
    return _bleService.findService(serviceUuid) != null;
  }

  /// Check if NUS service is available
  bool get hasNusService => hasService(NusUuids.service);

  /// Check if Extended API service is available
  bool get hasExtendedApiService => hasService(ZswatchExtendedUuids.service);

  /// Check if MCUmgr service is available
  bool get hasMcumgrService => hasService(McumgrUuids.service);

  /// Check if Heart Rate service is available
  bool get hasHeartRateService => hasService(HeartRateUuids.service);

  /// Check if Battery service is available
  bool get hasBatteryService => hasService(BatteryUuids.service);

  /// Check if Sensor service is available
  bool get hasSensorService => hasService(SensorServiceUuids.service);
}
