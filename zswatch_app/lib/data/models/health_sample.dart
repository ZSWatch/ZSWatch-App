import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_sample.freezed.dart';

/// Types of health data that can be stored
enum HealthType {
  /// Daily/hourly step count
  steps,

  /// Heart rate in BPM
  heartRate,

  /// Sleep duration in minutes (future)
  sleep,

  /// Activity state (walking, running, etc.)
  activity,
}

/// Time granularity for health samples
enum Granularity {
  /// Live streaming data
  realtime,

  /// Per-hour aggregates
  hourly,

  /// Per-day totals
  daily,

  /// Per-week totals
  weekly,

  /// Per-month totals
  monthly,
}

/// Extension methods for HealthType enum
extension HealthTypeExtension on HealthType {
  /// Convert to database string
  String get dbName {
    switch (this) {
      case HealthType.steps:
        return 'steps';
      case HealthType.heartRate:
        return 'heartRate';
      case HealthType.sleep:
        return 'sleep';
      case HealthType.activity:
        return 'activity';
    }
  }

  /// Parse from database string
  static HealthType fromString(String value) {
    switch (value) {
      case 'steps':
        return HealthType.steps;
      case 'heartRate':
        return HealthType.heartRate;
      case 'sleep':
        return HealthType.sleep;
      case 'activity':
        return HealthType.activity;
      default:
        throw ArgumentError('Unknown health type: $value');
    }
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case HealthType.steps:
        return 'Steps';
      case HealthType.heartRate:
        return 'Heart Rate';
      case HealthType.sleep:
        return 'Sleep';
      case HealthType.activity:
        return 'Activity';
    }
  }

  /// Unit of measurement
  String get unit {
    switch (this) {
      case HealthType.steps:
        return 'steps';
      case HealthType.heartRate:
        return 'BPM';
      case HealthType.sleep:
        return 'min';
      case HealthType.activity:
        return '';
    }
  }
}

/// Extension methods for Granularity enum
extension GranularityExtension on Granularity {
  /// Convert to database string
  String get dbName {
    switch (this) {
      case Granularity.realtime:
        return 'realtime';
      case Granularity.hourly:
        return 'hourly';
      case Granularity.daily:
        return 'daily';
      case Granularity.weekly:
        return 'weekly';
      case Granularity.monthly:
        return 'monthly';
    }
  }

  /// Parse from database string
  static Granularity fromString(String value) {
    switch (value) {
      case 'realtime':
        return Granularity.realtime;
      case 'hourly':
        return Granularity.hourly;
      case 'daily':
        return Granularity.daily;
      case 'weekly':
        return Granularity.weekly;
      case 'monthly':
        return Granularity.monthly;
      default:
        throw ArgumentError('Unknown granularity: $value');
    }
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case Granularity.realtime:
        return 'Real-time';
      case Granularity.hourly:
        return 'Hourly';
      case Granularity.daily:
        return 'Daily';
      case Granularity.weekly:
        return 'Weekly';
      case Granularity.monthly:
        return 'Monthly';
    }
  }
}

/// Health sample model representing a single health data point
///
/// Used to store and retrieve health metrics like steps, heart rate,
/// and sleep data. Samples are stored in the local SQLite database
/// with 60-day retention.
@freezed
abstract class HealthSample with _$HealthSample {
  const HealthSample._();

  const factory HealthSample({
    /// Database row identifier (null for new samples)
    int? id,

    /// Foreign key to source watch
    required String watchId,

    /// Type of health data
    required HealthType type,

    /// Measured value (steps count, BPM, minutes, etc.)
    required double value,

    /// When the measurement was taken on the watch
    required DateTime timestamp,

    /// Time granularity of this sample
    required Granularity granularity,

    /// When the data was received by the app
    required DateTime syncedAt,
  }) = _HealthSample;

  /// Create a new health sample (not yet persisted)
  factory HealthSample.create({
    required String watchId,
    required HealthType type,
    required double value,
    required DateTime timestamp,
    required Granularity granularity,
  }) {
    return HealthSample(
      watchId: watchId,
      type: type,
      value: value,
      timestamp: timestamp,
      granularity: granularity,
      syncedAt: DateTime.now(),
    );
  }

  /// Create a realtime heart rate sample
  factory HealthSample.heartRate({
    required String watchId,
    required int bpm,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return HealthSample(
      watchId: watchId,
      type: HealthType.heartRate,
      value: bpm.toDouble(),
      timestamp: now,
      granularity: Granularity.realtime,
      syncedAt: DateTime.now(),
    );
  }

  /// Create a step count sample
  factory HealthSample.steps({
    required String watchId,
    required int steps,
    required DateTime timestamp,
    Granularity granularity = Granularity.hourly,
  }) {
    return HealthSample(
      watchId: watchId,
      type: HealthType.steps,
      value: steps.toDouble(),
      timestamp: timestamp,
      granularity: granularity,
      syncedAt: DateTime.now(),
    );
  }

  /// Create an activity state sample
  ///
  /// The value stores the activity state as an integer:
  /// 0=unknown, 1=notWorn, 2=deepSleep, 3=lightSleep, 4=remSleep,
  /// 5=still(activity), 6=running, 7=walking, 8=swimming, 9=cycling, 10=exercise
  factory HealthSample.activity({
    required String watchId,
    required int activityStateValue,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return HealthSample(
      watchId: watchId,
      type: HealthType.activity,
      value: activityStateValue.toDouble(),
      timestamp: now,
      granularity: Granularity.realtime,
      syncedAt: DateTime.now(),
    );
  }

  /// Value as integer (for steps)
  int get intValue => value.round();

  /// Formatted value with unit
  String get formattedValue {
    switch (type) {
      case HealthType.steps:
        return '${intValue.toString()} ${type.unit}';
      case HealthType.heartRate:
        return '${intValue.toString()} ${type.unit}';
      case HealthType.sleep:
        final hours = intValue ~/ 60;
        final minutes = intValue % 60;
        if (hours > 0) {
          return '${hours}h ${minutes}m';
        }
        return '${minutes}m';
      case HealthType.activity:
        return intValue.toString();
    }
  }

  /// Check if this is a valid heart rate reading (30-250 BPM)
  bool get isValidHeartRate {
    if (type != HealthType.heartRate) return true;
    return value >= 30 && value <= 250;
  }

  /// Check if this is a valid step count (non-negative)
  bool get isValidSteps {
    if (type != HealthType.steps) return true;
    return value >= 0;
  }
}

/// Aggregated health data for a time period
@freezed
abstract class HealthAggregate with _$HealthAggregate {
  const HealthAggregate._();

  const factory HealthAggregate({
    /// Type of health data
    required HealthType type,

    /// Start of the period
    required DateTime periodStart,

    /// End of the period
    required DateTime periodEnd,

    /// Granularity of the aggregate
    required Granularity granularity,

    /// Total/sum value (for steps)
    required double total,

    /// Average value (for heart rate)
    required double average,

    /// Minimum value in the period
    required double min,

    /// Maximum value in the period
    required double max,

    /// Number of samples in the aggregate
    required int sampleCount,
  }) = _HealthAggregate;

  /// Create from a list of samples
  ///
  /// Note: For steps, we use the maximum value since the watch sends cumulative
  /// daily steps, not incremental counts.
  factory HealthAggregate.fromSamples({
    required List<HealthSample> samples,
    required DateTime periodStart,
    required DateTime periodEnd,
    required Granularity granularity,
  }) {
    if (samples.isEmpty) {
      const type = HealthType.steps; // Default
      return HealthAggregate(
        type: type,
        periodStart: periodStart,
        periodEnd: periodEnd,
        granularity: granularity,
        total: 0,
        average: 0,
        min: 0,
        max: 0,
        sampleCount: 0,
      );
    }

    final type = samples.first.type;
    final values = samples.map((s) => s.value).toList();
    final sum = values.reduce((a, b) => a + b);
    final average = sum / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    // For steps, use max value (cumulative) instead of sum
    final total = type == HealthType.steps ? max : sum;

    return HealthAggregate(
      type: type,
      periodStart: periodStart,
      periodEnd: periodEnd,
      granularity: granularity,
      total: total,
      average: average,
      min: min,
      max: max,
      sampleCount: samples.length,
    );
  }

  /// Get the primary display value based on health type
  double get displayValue {
    switch (type) {
      case HealthType.steps:
        return total;
      case HealthType.heartRate:
        return average;
      case HealthType.sleep:
        return total;
      case HealthType.activity:
        return total;
    }
  }

  /// Formatted display value with unit
  String get formattedDisplayValue {
    switch (type) {
      case HealthType.steps:
        return '${total.round()} ${type.unit}';
      case HealthType.heartRate:
        return '${average.round()} ${type.unit}';
      case HealthType.sleep:
        final hours = total.round() ~/ 60;
        final minutes = total.round() % 60;
        if (hours > 0) {
          return '${hours}h ${minutes}m';
        }
        return '${minutes}m';
      case HealthType.activity:
        return '$sampleCount samples';
    }
  }
}
