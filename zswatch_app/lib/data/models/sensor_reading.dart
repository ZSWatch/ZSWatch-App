import 'package:freezed_annotation/freezed_annotation.dart';

part 'sensor_reading.freezed.dart';

/// Type of sensor data
enum SensorType {
  /// 3-axis accelerometer (m/s²)
  accelerometer,

  /// 3-axis gyroscope (rad/s or deg/s)
  gyroscope,

  /// Temperature sensor (°C)
  temperature,

  /// Magnetometer/compass (μT)
  magnetometer,

  /// Barometric pressure (hPa)
  pressure,

  /// Ambient light sensor (lux)
  light,

  /// Humidity sensor (%)
  humidity,
}

/// A single sensor reading from the watch
@freezed
abstract class SensorReading with _$SensorReading {
  const SensorReading._();

  const factory SensorReading({
    /// Timestamp when the reading was received
    required DateTime timestamp,

    /// Type of sensor
    required SensorType type,

    /// X-axis value (for multi-axis sensors) or primary value
    required double x,

    /// Y-axis value (for multi-axis sensors)
    double? y,

    /// Z-axis value (for multi-axis sensors)
    double? z,

    /// Raw integer value (for PPG)
    int? rawValue,
  }) = _SensorReading;

  /// Create an accelerometer reading
  factory SensorReading.accelerometer({
    required double x,
    required double y,
    required double z,
  }) {
    return SensorReading(
      timestamp: DateTime.now(),
      type: SensorType.accelerometer,
      x: x,
      y: y,
      z: z,
    );
  }

  /// Create a gyroscope reading
  factory SensorReading.gyroscope({
    required double x,
    required double y,
    required double z,
  }) {
    return SensorReading(
      timestamp: DateTime.now(),
      type: SensorType.gyroscope,
      x: x,
      y: y,
      z: z,
    );
  }

  /// Create a temperature reading
  factory SensorReading.temperature({required double celsius}) {
    return SensorReading(
      timestamp: DateTime.now(),
      type: SensorType.temperature,
      x: celsius,
    );
  }

  /// Create a magnetometer reading
  factory SensorReading.magnetometer({
    required double x,
    required double y,
    required double z,
  }) {
    return SensorReading(
      timestamp: DateTime.now(),
      type: SensorType.magnetometer,
      x: x,
      y: y,
      z: z,
    );
  }

  /// Create a pressure reading
  factory SensorReading.pressure({required double hPa}) {
    return SensorReading(
      timestamp: DateTime.now(),
      type: SensorType.pressure,
      x: hPa,
    );
  }

  /// Create a light sensor reading
  factory SensorReading.light({required double lux}) {
    return SensorReading(
      timestamp: DateTime.now(),
      type: SensorType.light,
      x: lux,
    );
  }

  /// Create a humidity reading
  factory SensorReading.humidity({required double percent}) {
    return SensorReading(
      timestamp: DateTime.now(),
      type: SensorType.humidity,
      x: percent,
    );
  }

  /// Get the magnitude for multi-axis sensors
  double get magnitude {
    if (y != null && z != null) {
      return (x * x + y! * y! + z! * z!).abs();
    }
    return x.abs();
  }

  /// Get unit string for this sensor type
  String get unit {
    switch (type) {
      case SensorType.accelerometer:
        return 'm/s²';
      case SensorType.gyroscope:
        return '°/s';
      case SensorType.temperature:
        return '°C';
      case SensorType.magnetometer:
        return 'μT';
      case SensorType.pressure:
        return 'hPa';
      case SensorType.light:
        return 'lux';
      case SensorType.humidity:
        return '%';
    }
  }

  /// Get display name for this sensor type
  String get typeName {
    switch (type) {
      case SensorType.accelerometer:
        return 'Accelerometer';
      case SensorType.gyroscope:
        return 'Gyroscope';
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.magnetometer:
        return 'Magnetometer';
      case SensorType.pressure:
        return 'Pressure';
      case SensorType.light:
        return 'Light';
      case SensorType.humidity:
        return 'Humidity';
    }
  }

  /// Format the reading for display
  String get formatted {
    if (y != null && z != null) {
      return 'X: ${x.toStringAsFixed(2)}, Y: ${y!.toStringAsFixed(2)}, Z: ${z!.toStringAsFixed(2)} $unit';
    }
    if (rawValue != null) {
      return '$rawValue';
    }
    return '${x.toStringAsFixed(2)} $unit';
  }
}

/// Buffer for storing recent sensor readings for real-time display
class SensorBuffer {
  /// Maximum number of readings to keep
  final int maxSize;

  /// Sensor type for this buffer
  final SensorType type;

  /// List of readings (oldest first, newest last)
  final List<SensorReading> _readings = [];

  SensorBuffer({this.maxSize = 200, required this.type});

  /// Get all readings
  List<SensorReading> get readings => List.unmodifiable(_readings);

  /// Get the most recent reading
  SensorReading? get latest => _readings.isNotEmpty ? _readings.last : null;

  /// Number of readings in buffer
  int get length => _readings.length;

  /// Whether buffer is empty
  bool get isEmpty => _readings.isEmpty;

  /// Whether buffer is full
  bool get isFull => _readings.length >= maxSize;

  /// Add a reading to the buffer
  void add(SensorReading reading) {
    if (reading.type != type) return;
    _readings.add(reading);
    while (_readings.length > maxSize) {
      _readings.removeAt(0);
    }
  }

  /// Clear all readings
  void clear() {
    _readings.clear();
  }

  /// Get readings within a time window
  List<SensorReading> getWindow(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _readings.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }
}
