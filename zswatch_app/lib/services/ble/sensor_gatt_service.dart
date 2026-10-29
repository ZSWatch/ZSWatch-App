import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../data/models/sensor_fusion_data.dart';
import '../../data/models/sensor_reading.dart';
import '../background/companion_prototype_client.dart';

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
  final CompanionPrototypeClient _native;
  StreamSubscription<Map<String, Object?>>? _nativeSubscription;
  final _connectionController = StreamController<bool>.broadcast();
  final Set<String> _nativeAvailable = {};
  int _nativeGeneration = 0;
  bool _disposed = false;

  // Characteristics for each sensor type

  // Subscriptions

  // Stream controllers
  final _tempController = StreamController<SensorReading>.broadcast();
  final _accelController = StreamController<SensorReading>.broadcast();
  final _lightController = StreamController<SensorReading>.broadcast();
  final _gyroController = StreamController<SensorReading>.broadcast();
  final _magController = StreamController<SensorReading>.broadcast();
  final _humidityController = StreamController<SensorReading>.broadcast();
  final _pressureController = StreamController<SensorReading>.broadcast();
  final _fusionController = StreamController<SensorFusionData>.broadcast();

  bool _isConnected = false;

  SensorGattService.native(this._native);
  Stream<bool> get connectionChanges => _connectionController.stream;

  Future<bool> initializeNative() async {
    final client = _native;
    _nativeSubscription = client.sensors().listen(
      _nativeEvent,
      onError: (Object error) {
        if (_disposed) return;
        _isConnected = false;
        _connectionController.add(false);
      },
    );
    try {
      final state = await client.sensorState();
      if (_disposed) return false;
      _nativeEvent(state);
      return _isConnected;
    } catch (_) {
      await _nativeSubscription?.cancel();
      _nativeSubscription = null;
      return false;
    }
  }

  void _nativeEvent(Map<String, Object?> event) {
    if (_disposed) return;
    final generation = event['generation'] as int;
    if (generation < _nativeGeneration) return;
    if (event['kind'] == 'state') {
      final names = event['available'];
      if (names is! List || !names.every((name) => name is String)) return;
      _nativeGeneration = generation;
      _nativeAvailable
        ..clear()
        ..addAll(names.cast<String>());
      _isConnected = names.isNotEmpty;
      _connectionController.add(_isConnected);
      return;
    }
    if (generation != _nativeGeneration || !_isConnected) return;
    final value = event['bytes'];
    if (value is! Uint8List) return;
    switch (event['sensor']) {
      case 'temperature':
        _handleTempData(value);
      case 'accelerometer':
        _handleAccelData(value);
      case 'light':
        _handleLightData(value);
      case 'gyroscope':
        _handleGyroData(value);
      case 'magnetometer':
        _handleMagData(value);
      case 'humidity':
        _handleHumidityData(value);
      case 'pressure':
        _handlePressureData(value);
      case 'fusion':
        _handleFusionData(value);
    }
  }

  Future<void> _nativeChange(String sensor, bool enabled) {
    if (!_isConnected) throw StateError('Connect the watch first');
    return _native.setSensor(_nativeGeneration, sensor, enabled);
  }

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

  /// Stream of sensor fusion (quaternion) readings
  Stream<SensorFusionData> get sensorFusionStream => _fusionController.stream;

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
  bool get hasTemperature => _nativeAvailable.contains('temperature');
  bool get hasAccelerometer => _nativeAvailable.contains('accelerometer');
  bool get hasLight => _nativeAvailable.contains('light');
  bool get hasGyroscope => _nativeAvailable.contains('gyroscope');
  bool get hasMagnetometer => _nativeAvailable.contains('magnetometer');
  bool get hasHumidity => _nativeAvailable.contains('humidity');
  bool get hasPressure => _nativeAvailable.contains('pressure');
  bool get hasSensorFusion => _nativeAvailable.contains('fusion');

  // =========================================================================
  // Temperature
  // =========================================================================

  /// Start streaming temperature data
  Future<void> startTemperature() async {
    return _nativeChange('temperature', true);
  }

  /// Stop streaming temperature data
  Future<void> stopTemperature() async {
    return _nativeChange('temperature', false);
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
    return _nativeChange('accelerometer', true);
  }

  /// Stop streaming accelerometer data
  Future<void> stopAccelerometer() async {
    return _nativeChange('accelerometer', false);
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
    return _nativeChange('light', true);
  }

  /// Stop streaming light sensor data
  Future<void> stopLight() async {
    return _nativeChange('light', false);
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
    return _nativeChange('gyroscope', true);
  }

  /// Stop streaming gyroscope data
  Future<void> stopGyroscope() async {
    return _nativeChange('gyroscope', false);
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
    return _nativeChange('magnetometer', true);
  }

  /// Stop streaming magnetometer data
  Future<void> stopMagnetometer() async {
    return _nativeChange('magnetometer', false);
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
    return _nativeChange('humidity', true);
  }

  /// Stop streaming humidity data
  Future<void> stopHumidity() async {
    return _nativeChange('humidity', false);
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
    return _nativeChange('pressure', true);
  }

  /// Stop streaming pressure data
  Future<void> stopPressure() async {
    return _nativeChange('pressure', false);
  }

  void _handlePressureData(List<int> data) {
    if (data.length < 4) return;

    // Firmware sends float (4 bytes, little-endian)
    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    final hPa = bytes.getFloat32(0, Endian.little);

    _pressureController.add(SensorReading.pressure(hPa: hPa));
  }

  // =========================================================================
  // Sensor Fusion (Quaternion)
  // =========================================================================

  /// Start streaming sensor fusion (quaternion) data
  Future<void> startSensorFusion() async {
    return _nativeChange('fusion', true);
  }

  /// Stop streaming sensor fusion data
  Future<void> stopSensorFusion() async {
    return _nativeChange('fusion', false);
  }

  void _handleFusionData(List<int> data) {
    if (data.length < 16) return;

    // Firmware sends quaternion [w, x, y, z] as 4x float32 little-endian
    try {
      final fusionData = SensorFusionData.fromBleData(data);
      _fusionController.add(fusionData);
    } catch (e) {
      debugPrint('[SensorGatt] Failed to parse fusion data: $e');
    }
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
    await startSensorFusion();
  }

  /// Stop all sensors
  Future<void> stopAll() async {
    for (final name in _nativeAvailable.toList()) {
      await _nativeChange(name, false);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _nativeSubscription?.cancel();

    await _tempController.close();
    await _accelController.close();
    await _lightController.close();
    await _gyroController.close();
    await _magController.close();
    await _humidityController.close();
    await _pressureController.close();
    await _fusionController.close();
    await _connectionController.close();
    _isConnected = false;
  }
}

/// Extension to merge multiple streams
class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>.broadcast();
    final subscriptions = <StreamSubscription<T>>[];

    for (final stream in streams) {
      final sub = stream.listen(controller.add, onError: controller.addError);
      subscriptions.add(sub);
    }

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      await controller.close();
    };

    return controller.stream;
  }
}
