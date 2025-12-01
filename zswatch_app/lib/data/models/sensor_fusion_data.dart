import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// Sensor fusion data from the watch's onboard IMU fusion algorithm
///
/// The watch performs sensor fusion onboard using Madgwick/Mahony algorithm,
/// outputting a quaternion (w, x, y, z) representing the device orientation.
/// This data is streamed via GATT characteristic ADAFRUIT_CHAR_3D at ~5Hz.
@immutable
class SensorFusionData {
  /// Quaternion w component (scalar part)
  final double w;

  /// Quaternion x component (vector i)
  final double x;

  /// Quaternion y component (vector j)
  final double y;

  /// Quaternion z component (vector k)
  final double z;

  /// Timestamp when the data was received
  final DateTime timestamp;

  const SensorFusionData({
    required this.w,
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  /// Create from BLE notification data (16 bytes = 4 floats, little-endian)
  ///
  /// Data format from firmware: [w, x, y, z] as float32 little-endian
  factory SensorFusionData.fromBleData(List<int> data) {
    if (data.length < 16) {
      throw ArgumentError('Sensor fusion data requires 16 bytes, got ${data.length}');
    }

    final bytes = ByteData.sublistView(Uint8List.fromList(data));
    return SensorFusionData(
      w: bytes.getFloat32(0, Endian.little),
      x: bytes.getFloat32(4, Endian.little),
      y: bytes.getFloat32(8, Endian.little),
      z: bytes.getFloat32(12, Endian.little),
      timestamp: DateTime.now(),
    );
  }

  /// Create identity quaternion with current timestamp
  factory SensorFusionData.identity() {
    return SensorFusionData(
      w: 1.0,
      x: 0.0,
      y: 0.0,
      z: 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// Quaternion magnitude (should be ~1.0 for unit quaternion)
  double get magnitude => math.sqrt(w * w + x * x + y * y + z * z);

  /// Get normalized quaternion
  SensorFusionData get normalized {
    final mag = magnitude;
    if (mag == 0) return this;
    return SensorFusionData(
      w: w / mag,
      x: x / mag,
      y: y / mag,
      z: z / mag,
      timestamp: timestamp,
    );
  }

  /// Get conjugate (inverse for unit quaternions)
  /// q* = (w, -x, -y, -z)
  SensorFusionData get conjugate {
    return SensorFusionData(
      w: w,
      x: -x,
      y: -y,
      z: -z,
      timestamp: timestamp,
    );
  }

  /// Get inverse quaternion
  /// q⁻¹ = q* / |q|²
  SensorFusionData get inverse {
    final magSquared = w * w + x * x + y * y + z * z;
    if (magSquared == 0) return this;
    return SensorFusionData(
      w: w / magSquared,
      x: -x / magSquared,
      y: -y / magSquared,
      z: -z / magSquared,
      timestamp: timestamp,
    );
  }

  /// Multiply this quaternion by another (Hamilton product)
  /// Used for combining rotations: result = this * other
  SensorFusionData multiply(SensorFusionData other) {
    return SensorFusionData(
      w: w * other.w - x * other.x - y * other.y - z * other.z,
      x: w * other.x + x * other.w + y * other.z - z * other.y,
      y: w * other.y - x * other.z + y * other.w + z * other.x,
      z: w * other.z + x * other.y - y * other.x + z * other.w,
      timestamp: DateTime.now(),
    );
  }

  /// Apply an offset correction by multiplying with offset inverse
  /// q_corrected = q_raw * q_offset_inverse
  /// This gives the relative rotation from the offset orientation
  SensorFusionData applyOffset(SensorFusionData offset) {
    // To get rotation relative to offset: q_relative = q_current * q_offset^-1
    return this.multiply(offset.inverse);
  }

  /// Convert quaternion to Euler angles (roll, pitch, yaw) in radians
  ///
  /// Uses aerospace sequence (ZYX): yaw, pitch, roll
  /// Returns (roll, pitch, yaw) in radians
  EulerAngles toEulerAngles() {
    // Roll (x-axis rotation)
    final sinrCosp = 2 * (w * x + y * z);
    final cosrCosp = 1 - 2 * (x * x + y * y);
    final roll = math.atan2(sinrCosp, cosrCosp);

    // Pitch (y-axis rotation)
    final sinp = 2 * (w * y - z * x);
    double pitch;
    if (sinp.abs() >= 1) {
      pitch = math.pi / 2 * sinp.sign; // Use 90 degrees if out of range
    } else {
      pitch = math.asin(sinp);
    }

    // Yaw (z-axis rotation)
    final sinyCosp = 2 * (w * z + x * y);
    final cosyCosp = 1 - 2 * (y * y + z * z);
    final yaw = math.atan2(sinyCosp, cosyCosp);

    return EulerAngles(
      roll: roll,
      pitch: pitch,
      yaw: yaw,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SensorFusionData &&
          runtimeType == other.runtimeType &&
          w == other.w &&
          x == other.x &&
          y == other.y &&
          z == other.z;

  @override
  int get hashCode => Object.hash(w, x, y, z);

  @override
  String toString() =>
      'SensorFusionData(w: ${w.toStringAsFixed(4)}, x: ${x.toStringAsFixed(4)}, '
      'y: ${y.toStringAsFixed(4)}, z: ${z.toStringAsFixed(4)})';

  /// Format for display with specified decimal places
  String toDisplayString([int decimals = 3]) {
    return 'w: ${w.toStringAsFixed(decimals)}, '
        'x: ${x.toStringAsFixed(decimals)}, '
        'y: ${y.toStringAsFixed(decimals)}, '
        'z: ${z.toStringAsFixed(decimals)}';
  }
}

/// Euler angles representation (roll, pitch, yaw)
@immutable
class EulerAngles {
  /// Roll (rotation around X-axis) in radians
  final double roll;

  /// Pitch (rotation around Y-axis) in radians
  final double pitch;

  /// Yaw (rotation around Z-axis) in radians
  final double yaw;

  const EulerAngles({
    required this.roll,
    required this.pitch,
    required this.yaw,
  });

  /// Roll in degrees
  double get rollDegrees => roll * 180 / math.pi;

  /// Pitch in degrees
  double get pitchDegrees => pitch * 180 / math.pi;

  /// Yaw in degrees
  double get yawDegrees => yaw * 180 / math.pi;

  @override
  String toString() =>
      'EulerAngles(roll: ${rollDegrees.toStringAsFixed(1)}°, '
      'pitch: ${pitchDegrees.toStringAsFixed(1)}°, '
      'yaw: ${yawDegrees.toStringAsFixed(1)}°)';

  /// Format for display
  String toDisplayString([int decimals = 1]) {
    return 'Roll: ${rollDegrees.toStringAsFixed(decimals)}°, '
        'Pitch: ${pitchDegrees.toStringAsFixed(decimals)}°, '
        'Yaw: ${yawDegrees.toStringAsFixed(decimals)}°';
  }
}
