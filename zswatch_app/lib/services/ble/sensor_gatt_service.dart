import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/ble_constants.dart';
import '../../data/models/sensor_reading.dart';

// Convert String UUIDs to Guid for flutter_blue_plus
Guid _guid(String uuid) => Guid(uuid);

/// Service client for zsw_gatt_sensor_server on watch
///
/// The firmware implements separate GATT services for each sensor type
/// (Adafruit Bluefruit format). Available sensors:
/// - Temperature (°C)
/// - Accelerometer (3-axis, raw values)
/// - Light (lux)
/// - Gyroscope (3-axis, raw values)
/// - Magnetometer (3-axis, raw values)
/// - Humidity (%)
/// - Pressure (hPa)
///
/// Data is streamed via GATT notifications at ~10Hz when enabled.
class SensorGattService {
  final BluetoothDevice _device;
  List<BluetoothService>? _services;

  // Characteristics for each sensor type
  BluetoothCharacteristic? _tempChar;
  BluetoothCharacteristic? _accelChar;
  BluetoothCharacteristic? _lightChar;
  BluetoothCharacteristic? _gyroChar;
  BluetoothCharacteristic? _magChar;
  BluetoothCharacteristic? _humidityChar;
  BluetoothCharacteristic? _pressureChar;

  // Subscriptions
  StreamSubscription<List<int>>? _tempSubscription;
  StreamSubscription<List<int>>? _accelSubscription;
  StreamSubscription<List<int>>? _lightSubscription;
  StreamSubscription<List<int>>? _gyroSubscription;
  StreamSubscription<List<int>>? _magSubscription;
  StreamSubscription<List<int>>? _humiditySubscription;
  StreamSubscription<List<int>>? _pressureSubscription;

  // Stream controllers
  final _tempController = StreamController<SensorReading>.broadcast();
  final _accelController = StreamController<SensorReading>.broadcast();
  final _lightController = StreamController<SensorReading>.broadcast();
  final _gyroController = StreamController<SensorReading>.broadcast();
  final _magController = StreamController<SensorReading>.broadcast();
  final _humidityController = StreamController<SensorReading>.broadcast();
  final _pressureController = StreamController<SensorReading>.broadcast();

  bool _isConnected = false;

  SensorGattService(this._device);

  /// Stream of temperature readings
  Stream<SensorReading> get temperatureStream => _tempController.stream;

  /// Stream of accelerometer readings
  Stream<SensorReading> get accelerometerStream => _accelController.stream;

  /// Stream of light sensor readings
  Stream<SensorReading> get lightStream => _lightController.stream;

  /// Stream of gyroscope readings
  Stream<SensorReading> get gyroscopeStream => _gyroController.stream;

  /// Stream of magnetometer readings
  Stream<SensorReading> get magnetometerStream => _magController.stream;

  /// Stream of humidity readings
  Stream<SensorReading> get humidityStream => _humidityController.stream;

  /// Stream of pressure readings
  Stream<SensorReading> get pressureStream => _pressureController.stream;

  /// Combined stream of all sensor readings
  Stream<SensorReading> get allSensorsStream {
    return StreamGroup.merge([
      _tempController.stream,
      _accelController.stream,
      _lightController.stream,
      _gyroController.stream,
      _magController.stream,
      _humidityController.stream,
      _pressureController.stream,
    ]);
  }

  /// Whether the sensor service is connected and ready
  bool get isConnected => _isConnected;

  /// Which sensors are available
  bool get hasTemperature => _tempChar != null;
  bool get hasAccelerometer => _accelChar != null;
  bool get hasLight => _lightChar != null;
  bool get hasGyroscope => _gyroChar != null;
  bool get hasMagnetometer => _magChar != null;
  bool get hasHumidity => _humidityChar != null;
  bool get hasPressure => _pressureChar != null;

  /// Initialize the sensor service
  ///
  /// Call this after the BLE connection is established and services are discovered.
  /// Each sensor type has its own GATT service in the Adafruit format.
  Future<bool> initialize(List<BluetoothService> services) async {
    try {
      _services = services;

      // Find characteristics in their respective services
      _tempChar = _findCharInService(
        SensorServiceUuids.temperatureService,
        SensorServiceUuids.temperatureChar,
      );
      _accelChar = _findCharInService(
        SensorServiceUuids.accelerometerService,
        SensorServiceUuids.accelerometerChar,
      );
      _lightChar = _findCharInService(
        SensorServiceUuids.lightService,
        SensorServiceUuids.lightChar,
      );
      _gyroChar = _findCharInService(
        SensorServiceUuids.gyroscopeService,
        SensorServiceUuids.gyroscopeChar,
      );
      _magChar = _findCharInService(
        SensorServiceUuids.magnetometerService,
        SensorServiceUuids.magnetometerChar,
      );
      _humidityChar = _findCharInService(
        SensorServiceUuids.humidityService,
        SensorServiceUuids.humidityChar,
      );
      _pressureChar = _findCharInService(
        SensorServiceUuids.pressureService,
        SensorServiceUuids.pressureChar,
      );

      debugPrint('[SensorGatt] Found sensors: '
          'temp=${_tempChar != null}, '
          'accel=${_accelChar != null}, '
          'light=${_lightChar != null}, '
          'gyro=${_gyroChar != null}, '
          'mag=${_magChar != null}, '
          'humidity=${_humidityChar != null}, '
          'pressure=${_pressureChar != null}');

      _isConnected = true;
      return true;
    } catch (e) {
      debugPrint('[SensorGatt] Initialize error: $e');
      return false;
    }
  }

  BluetoothCharacteristic? _findCharInService(
    String serviceUuid,
    String charUuid,
  ) {
    final service = _services?.cast<BluetoothService?>().firstWhere(
          (s) => s?.uuid == _guid(serviceUuid),
          orElse: () => null,
        );
    if (service == null) return null;

    return service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
          (c) => c?.uuid == _guid(charUuid),
          orElse: () => null,
        );
  }

  // =========================================================================
  // Temperature
  // =========================================================================

  /// Start streaming temperature data
  Future<void> startTemperature() async {
    if (_tempChar == null) {
      debugPrint('[SensorGatt] Temperature not available');
      return;
    }

    try {
      await _tempChar!.setNotifyValue(true);
      _tempSubscription = _tempChar!.onValueReceived.listen(_handleTempData);
      debugPrint('[SensorGatt] Temperature streaming started');
    } catch (e) {
      debugPrint('[SensorGatt] Failed to start temperature: $e');
    }
  }

  /// Stop streaming temperature data
  Future<void> stopTemperature() async {
    await _tempSubscription?.cancel();
    _tempSubscription = null;
    try {
      await _tempChar?.setNotifyValue(false);
    } catch (_) {}
  }

  void _handleTempData(List<int> data) {
    if (data.length < 4) return;

    // Firmware sends float (4 bytes, little-endian)
    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    final celsius = bytes.getFloat32(0, Endian.little);

    _tempController.add(SensorReading.temperature(celsius: celsius));
  }

  // =========================================================================
  // Accelerometer
  // =========================================================================

  /// Start streaming accelerometer data
  Future<void> startAccelerometer() async {
    if (_accelChar == null) {
      debugPrint('[SensorGatt] Accelerometer not available');
      return;
    }

    try {
      await _accelChar!.setNotifyValue(true);
      _accelSubscription = _accelChar!.onValueReceived.listen(_handleAccelData);
      debugPrint('[SensorGatt] Accelerometer streaming started');
    } catch (e) {
      debugPrint('[SensorGatt] Failed to start accelerometer: $e');
    }
  }

  /// Stop streaming accelerometer data
  Future<void> stopAccelerometer() async {
    await _accelSubscription?.cancel();
    _accelSubscription = null;
    try {
      await _accelChar?.setNotifyValue(false);
    } catch (_) {}
  }

  void _handleAccelData(List<int> data) {
    if (data.length < 12) return;

    // Firmware sends 3x float (12 bytes total, little-endian)
    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    final x = bytes.getFloat32(0, Endian.little);
    final y = bytes.getFloat32(4, Endian.little);
    final z = bytes.getFloat32(8, Endian.little);

    _accelController.add(SensorReading.accelerometer(x: x, y: y, z: z));
  }

  // =========================================================================
  // Light
  // =========================================================================

  /// Start streaming light sensor data
  Future<void> startLight() async {
    if (_lightChar == null) {
      debugPrint('[SensorGatt] Light sensor not available');
      return;
    }

    try {
      await _lightChar!.setNotifyValue(true);
      _lightSubscription = _lightChar!.onValueReceived.listen(_handleLightData);
      debugPrint('[SensorGatt] Light streaming started');
    } catch (e) {
      debugPrint('[SensorGatt] Failed to start light: $e');
    }
  }

  /// Stop streaming light sensor data
  Future<void> stopLight() async {
    await _lightSubscription?.cancel();
    _lightSubscription = null;
    try {
      await _lightChar?.setNotifyValue(false);
    } catch (_) {}
  }

  void _handleLightData(List<int> data) {
    if (data.length < 4) return;

    // Firmware sends float (4 bytes, little-endian)
    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    final lux = bytes.getFloat32(0, Endian.little);

    _lightController.add(SensorReading.light(lux: lux));
  }

  // =========================================================================
  // Gyroscope
  // =========================================================================

  /// Start streaming gyroscope data
  Future<void> startGyroscope() async {
    if (_gyroChar == null) {
      debugPrint('[SensorGatt] Gyroscope not available');
      return;
    }

    try {
      await _gyroChar!.setNotifyValue(true);
      _gyroSubscription = _gyroChar!.onValueReceived.listen(_handleGyroData);
      debugPrint('[SensorGatt] Gyroscope streaming started');
    } catch (e) {
      debugPrint('[SensorGatt] Failed to start gyroscope: $e');
    }
  }

  /// Stop streaming gyroscope data
  Future<void> stopGyroscope() async {
    await _gyroSubscription?.cancel();
    _gyroSubscription = null;
    try {
      await _gyroChar?.setNotifyValue(false);
    } catch (_) {}
  }

  void _handleGyroData(List<int> data) {
    if (data.length < 12) return;

    // Firmware sends 3x float (12 bytes total, little-endian)
    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    final x = bytes.getFloat32(0, Endian.little);
    final y = bytes.getFloat32(4, Endian.little);
    final z = bytes.getFloat32(8, Endian.little);

    _gyroController.add(SensorReading.gyroscope(x: x, y: y, z: z));
  }

  // =========================================================================
  // Magnetometer
  // =========================================================================

  /// Start streaming magnetometer data
  Future<void> startMagnetometer() async {
    if (_magChar == null) {
      debugPrint('[SensorGatt] Magnetometer not available');
      return;
    }

    try {
      await _magChar!.setNotifyValue(true);
      _magSubscription = _magChar!.onValueReceived.listen(_handleMagData);
      debugPrint('[SensorGatt] Magnetometer streaming started');
    } catch (e) {
      debugPrint('[SensorGatt] Failed to start magnetometer: $e');
    }
  }

  /// Stop streaming magnetometer data
  Future<void> stopMagnetometer() async {
    await _magSubscription?.cancel();
    _magSubscription = null;
    try {
      await _magChar?.setNotifyValue(false);
    } catch (_) {}
  }

  void _handleMagData(List<int> data) {
    if (data.length < 12) return;

    // Firmware sends 3x float (12 bytes total, little-endian)
    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    final x = bytes.getFloat32(0, Endian.little);
    final y = bytes.getFloat32(4, Endian.little);
    final z = bytes.getFloat32(8, Endian.little);

    _magController.add(SensorReading.magnetometer(x: x, y: y, z: z));
  }

  // =========================================================================
  // Humidity
  // =========================================================================

  /// Start streaming humidity data
  Future<void> startHumidity() async {
    if (_humidityChar == null) {
      debugPrint('[SensorGatt] Humidity not available');
      return;
    }

    try {
      await _humidityChar!.setNotifyValue(true);
      _humiditySubscription =
          _humidityChar!.onValueReceived.listen(_handleHumidityData);
      debugPrint('[SensorGatt] Humidity streaming started');
    } catch (e) {
      debugPrint('[SensorGatt] Failed to start humidity: $e');
    }
  }

  /// Stop streaming humidity data
  Future<void> stopHumidity() async {
    await _humiditySubscription?.cancel();
    _humiditySubscription = null;
    try {
      await _humidityChar?.setNotifyValue(false);
    } catch (_) {}
  }

  void _handleHumidityData(List<int> data) {
    if (data.length < 4) return;

    // Firmware sends float (4 bytes, little-endian)
    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    final percent = bytes.getFloat32(0, Endian.little);

    _humidityController.add(SensorReading.humidity(percent: percent));
  }

  // =========================================================================
  // Pressure
  // =========================================================================

  /// Start streaming pressure data
  Future<void> startPressure() async {
    if (_pressureChar == null) {
      debugPrint('[SensorGatt] Pressure not available');
      return;
    }

    try {
      await _pressureChar!.setNotifyValue(true);
      _pressureSubscription =
          _pressureChar!.onValueReceived.listen(_handlePressureData);
      debugPrint('[SensorGatt] Pressure streaming started');
    } catch (e) {
      debugPrint('[SensorGatt] Failed to start pressure: $e');
    }
  }

  /// Stop streaming pressure data
  Future<void> stopPressure() async {
    await _pressureSubscription?.cancel();
    _pressureSubscription = null;
    try {
      await _pressureChar?.setNotifyValue(false);
    } catch (_) {}
  }

  void _handlePressureData(List<int> data) {
    if (data.length < 4) return;

    // Firmware sends float (4 bytes, little-endian)
    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    final hPa = bytes.getFloat32(0, Endian.little);

    _pressureController.add(SensorReading.pressure(hPa: hPa));
  }

  // =========================================================================
  // Utility methods
  // =========================================================================

  /// Start all available sensors
  Future<void> startAll() async {
    await startTemperature();
    await startAccelerometer();
    await startLight();
    await startGyroscope();
    await startMagnetometer();
    await startHumidity();
    await startPressure();
  }

  /// Stop all sensors
  Future<void> stopAll() async {
    await stopTemperature();
    await stopAccelerometer();
    await stopLight();
    await stopGyroscope();
    await stopMagnetometer();
    await stopHumidity();
    await stopPressure();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopAll();
    await _tempController.close();
    await _accelController.close();
    await _lightController.close();
    await _gyroController.close();
    await _magController.close();
    await _humidityController.close();
    await _pressureController.close();
    _isConnected = false;
  }
}

/// Extension to merge multiple streams
class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>.broadcast();
    final subscriptions = <StreamSubscription<T>>[];

    for (final stream in streams) {
      final sub = stream.listen(
        controller.add,
        onError: controller.addError,
      );
      subscriptions.add(sub);
    }

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }
}
