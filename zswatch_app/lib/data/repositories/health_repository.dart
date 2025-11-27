import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/health_sample.dart';

/// Repository for health data operations
///
/// Provides a clean interface for CRUD operations on health samples,
/// abstracting the database layer from the rest of the app.
/// Includes 60-day data retention with automatic cleanup.
class HealthRepository {
  final AppDatabase _db;

  HealthRepository(this._db);

  // ==================== Read Operations ====================

  /// Get health samples for a watch within date range
  Future<List<HealthSample>> getSamples({
    required String watchId,
    required HealthType type,
    required DateTime from,
    required DateTime to,
  }) async {
    final entities = await _db.getHealthSamples(
      watchId: watchId,
      type: type.name,
      from: from,
      to: to,
    );
    return entities.map(_entityToModel).toList();
  }

  /// Get all samples of a type for a watch (limited)
  Future<List<HealthSample>> getRecentSamples({
    required String watchId,
    required HealthType type,
    int limit = 100,
  }) async {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 1));
    final samples = await getSamples(
      watchId: watchId,
      type: type,
      from: from,
      to: to,
    );
    if (samples.length > limit) {
      return samples.sublist(samples.length - limit);
    }
    return samples;
  }

  /// Get steps for a specific day (hourly breakdown)
  Future<List<HealthSample>> getDailySteps({
    required String watchId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return getSamples(
      watchId: watchId,
      type: HealthType.steps,
      from: startOfDay,
      to: endOfDay,
    );
  }

  /// Get heart rate samples for a specific day
  Future<List<HealthSample>> getDailyHeartRate({
    required String watchId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return getSamples(
      watchId: watchId,
      type: HealthType.heartRate,
      from: startOfDay,
      to: endOfDay,
    );
  }

  /// Get aggregated steps by day for a date range
  Future<List<HealthAggregate>> getStepsHistory({
    required String watchId,
    required DateTime from,
    required DateTime to,
    Granularity granularity = Granularity.daily,
  }) async {
    final samples = await getSamples(
      watchId: watchId,
      type: HealthType.steps,
      from: from,
      to: to,
    );

    return _aggregateSamples(
      samples: samples,
      from: from,
      to: to,
      granularity: granularity,
    );
  }

  /// Get aggregated heart rate by day for a date range
  Future<List<HealthAggregate>> getHeartRateHistory({
    required String watchId,
    required DateTime from,
    required DateTime to,
    Granularity granularity = Granularity.daily,
  }) async {
    final samples = await getSamples(
      watchId: watchId,
      type: HealthType.heartRate,
      from: from,
      to: to,
    );

    return _aggregateSamples(
      samples: samples,
      from: from,
      to: to,
      granularity: granularity,
    );
  }

  /// Get today's total steps
  /// 
  /// Note: The watch sends cumulative daily steps, so we return the maximum
  /// (most recent) value rather than summing all samples.
  Future<int> getTodaySteps(String watchId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final samples = await getSamples(
      watchId: watchId,
      type: HealthType.steps,
      from: startOfDay,
      to: now,
    );
    
    if (samples.isEmpty) return 0;
    // Return the maximum value since the watch sends cumulative daily steps
    return samples.map((s) => s.intValue).reduce((a, b) => a > b ? a : b);
  }

  /// Get latest heart rate reading
  Future<HealthSample?> getLatestHeartRate(String watchId) async {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final samples = await getSamples(
      watchId: watchId,
      type: HealthType.heartRate,
      from: oneHourAgo,
      to: now,
    );
    
    if (samples.isEmpty) return null;
    return samples.last;
  }

  // ==================== Write Operations ====================

  /// Insert a single health sample
  Future<int> insertSample(HealthSample sample) async {
    return _db.insertHealthSample(_modelToCompanion(sample));
  }

  /// Insert multiple health samples (batch)
  Future<void> insertSamples(List<HealthSample> samples) async {
    final companions = samples.map(_modelToCompanion).toList();
    return _db.insertHealthSamples(companions);
  }

  /// Insert a heart rate reading
  Future<int> insertHeartRate({
    required String watchId,
    required int bpm,
    DateTime? timestamp,
  }) {
    final sample = HealthSample.heartRate(
      watchId: watchId,
      bpm: bpm,
      timestamp: timestamp,
    );
    return insertSample(sample);
  }

  /// Insert a step count reading
  Future<int> insertSteps({
    required String watchId,
    required int steps,
    required DateTime timestamp,
    Granularity granularity = Granularity.hourly,
  }) {
    final sample = HealthSample.steps(
      watchId: watchId,
      steps: steps,
      timestamp: timestamp,
      granularity: granularity,
    );
    return insertSample(sample);
  }

  /// Insert an activity state reading
  Future<int> insertActivity({
    required String watchId,
    required int activityStateValue,
    DateTime? timestamp,
  }) {
    final sample = HealthSample.activity(
      watchId: watchId,
      activityStateValue: activityStateValue,
      timestamp: timestamp,
    );
    return insertSample(sample);
  }

  /// Get activity samples for a specific day
  Future<List<HealthSample>> getDailyActivity({
    required String watchId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return getSamples(
      watchId: watchId,
      type: HealthType.activity,
      from: startOfDay,
      to: endOfDay,
    );
  }

  /// Calculate activity breakdown (time spent in each state) for a day
  /// 
  /// Returns a Map of activity state value to duration spent in that state.
  /// The calculation works by assuming each sample represents the state until
  /// the next sample arrives (or end of day).
  Future<Map<int, Duration>> getActivityBreakdown({
    required String watchId,
    required DateTime date,
  }) async {
    final samples = await getDailyActivity(watchId: watchId, date: date);
    
    if (samples.isEmpty) {
      return {};
    }
    
    final breakdown = <int, Duration>{};
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final now = DateTime.now();
    final effectiveEnd = now.isBefore(endOfDay) ? now : endOfDay;
    
    // Sort by timestamp
    final sortedSamples = List<HealthSample>.from(samples)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    for (int i = 0; i < sortedSamples.length; i++) {
      final sample = sortedSamples[i];
      final stateValue = sample.intValue;
      
      // Calculate duration until next sample or end of day
      final DateTime nextTime;
      if (i + 1 < sortedSamples.length) {
        nextTime = sortedSamples[i + 1].timestamp;
      } else {
        nextTime = effectiveEnd;
      }
      
      final duration = nextTime.difference(sample.timestamp);
      if (duration.isNegative) continue;
      
      breakdown[stateValue] = (breakdown[stateValue] ?? Duration.zero) + duration;
    }
    
    return breakdown;
  }

  // ==================== Delete Operations ====================

  /// Delete old data (60-day retention policy)
  Future<int> cleanupOldData() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    return _db.deleteOldHealthSamples(cutoff);
  }

  /// Delete all health data for a watch
  Future<void> deleteWatchData(String watchId) async {
    // This is handled by cascade delete in app_database.dart
    // But we can add explicit method if needed
  }

  // ==================== Aggregation Helpers ====================

  List<HealthAggregate> _aggregateSamples({
    required List<HealthSample> samples,
    required DateTime from,
    required DateTime to,
    required Granularity granularity,
  }) {
    if (samples.isEmpty) return [];

    final type = samples.first.type;
    final aggregates = <HealthAggregate>[];

    // Group samples by period
    final Duration periodDuration;
    switch (granularity) {
      case Granularity.hourly:
        periodDuration = const Duration(hours: 1);
        break;
      case Granularity.daily:
        periodDuration = const Duration(days: 1);
        break;
      case Granularity.weekly:
        periodDuration = const Duration(days: 7);
        break;
      case Granularity.monthly:
        periodDuration = const Duration(days: 30);
        break;
      case Granularity.realtime:
        // For realtime, return one aggregate for the entire period
        return [
          HealthAggregate.fromSamples(
            samples: samples,
            periodStart: from,
            periodEnd: to,
            granularity: granularity,
          ),
        ];
    }

    // Normalize start time based on granularity
    DateTime periodStart;
    switch (granularity) {
      case Granularity.hourly:
        periodStart = DateTime(from.year, from.month, from.day, from.hour);
        break;
      case Granularity.daily:
      case Granularity.weekly:
      case Granularity.monthly:
        periodStart = DateTime(from.year, from.month, from.day);
        break;
      case Granularity.realtime:
        periodStart = from;
        break;
    }

    while (periodStart.isBefore(to)) {
      final periodEnd = periodStart.add(periodDuration);
      
      final periodSamples = samples.where((s) =>
          s.timestamp.isAfter(periodStart) && 
          s.timestamp.isBefore(periodEnd.add(const Duration(seconds: 1)))).toList();

      if (periodSamples.isNotEmpty) {
        aggregates.add(HealthAggregate.fromSamples(
          samples: periodSamples,
          periodStart: periodStart,
          periodEnd: periodEnd,
          granularity: granularity,
        ));
      } else {
        // Add empty aggregate for periods with no data
        aggregates.add(HealthAggregate(
          type: type,
          periodStart: periodStart,
          periodEnd: periodEnd,
          granularity: granularity,
          total: 0,
          average: 0,
          min: 0,
          max: 0,
          sampleCount: 0,
        ));
      }

      periodStart = periodEnd;
    }

    return aggregates;
  }

  // ==================== Mapping ====================

  HealthSample _entityToModel(HealthSampleEntity entity) {
    return HealthSample(
      id: entity.id,
      watchId: entity.watchId,
      type: HealthTypeExtension.fromString(entity.type),
      value: entity.value,
      timestamp: entity.timestamp,
      granularity: GranularityExtension.fromString(entity.granularity),
      syncedAt: entity.syncedAt,
    );
  }

  HealthSamplesCompanion _modelToCompanion(HealthSample sample) {
    return HealthSamplesCompanion(
      id: sample.id != null ? Value(sample.id!) : const Value.absent(),
      watchId: Value(sample.watchId),
      type: Value(sample.type.name),
      value: Value(sample.value),
      timestamp: Value(sample.timestamp),
      granularity: Value(sample.granularity.name),
      syncedAt: Value(sample.syncedAt),
    );
  }
}
