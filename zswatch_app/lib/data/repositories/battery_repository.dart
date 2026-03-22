import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/watch_providers.dart';
import '../database/app_database.dart';

/// Repository for battery readings
///
/// Handles:
/// - Storing battery samples when received from watch
/// - Querying battery history for charts
/// - Calculating battery drain rates
class BatteryRepository {
  final AppDatabase _db;

  BatteryRepository(this._db);

  /// Insert a battery reading
  Future<int> insertBatteryReading({
    required String watchId,
    required int level,
    bool isCharging = false,
    DateTime? timestamp,
  }) {
    return _db.insertBatteryReading(
      BatteryReadingsCompanion(
        watchId: Value(watchId),
        level: Value(level),
        isCharging: Value(isCharging),
        timestamp: Value(timestamp ?? DateTime.now()),
      ),
    );
  }

  /// Get battery readings for a watch within date range
  Future<List<BatteryReadingEntity>> getBatteryReadings({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) {
    return _db.getBatteryReadings(watchId: watchId, from: from, to: to);
  }

  /// Get battery readings for the last 24 hours
  Future<List<BatteryReadingEntity>> getLast24Hours(String watchId) {
    final now = DateTime.now();
    return getBatteryReadings(
      watchId: watchId,
      from: now.subtract(const Duration(hours: 24)),
      to: now,
    );
  }

  /// Get battery readings for the last 7 days
  Future<List<BatteryReadingEntity>> getLast7Days(String watchId) {
    final now = DateTime.now();
    return getBatteryReadings(
      watchId: watchId,
      from: now.subtract(const Duration(days: 7)),
      to: now,
    );
  }

  /// Get the latest battery reading for a watch
  Future<BatteryReadingEntity?> getLatestReading(String watchId) async {
    final now = DateTime.now();
    final readings = await getBatteryReadings(
      watchId: watchId,
      from: now.subtract(const Duration(days: 1)),
      to: now,
    );
    return readings.isNotEmpty ? readings.last : null;
  }

  /// Calculate average battery drain per hour over a period
  Future<double?> calculateDrainRatePerHour({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) async {
    final readings = await getBatteryReadings(
      watchId: watchId,
      from: from,
      to: to,
    );

    if (readings.length < 2) return null;

    // Focus on discharging readings only
    final dischargingReadings = readings
        .where((r) => !r.isCharging)
        .toList(growable: false);
    if (dischargingReadings.length < 2) return null;

    // Find the start of the current discharge cycle (last upward jump → new slope)
    int startIndex = 0;
    for (int i = 1; i < dischargingReadings.length; i++) {
      final prev = dischargingReadings[i - 1];
      final curr = dischargingReadings[i];
      if (curr.level > prev.level) {
        startIndex = i;
      }
    }

    final start = dischargingReadings[startIndex];
    final end = dischargingReadings.last;

    // Use the full window up to "to" so long idle periods don't inflate the rate
    final effectiveEndTime = to.isAfter(end.timestamp) ? to : end.timestamp;
    final elapsedMinutes = effectiveEndTime
        .difference(start.timestamp)
        .inMinutes;

    // Require a reasonable span to avoid noisy spikes
    if (elapsedMinutes < 30) return null;

    final drain = start.level - end.level;
    if (drain <= 0) return null;

    return drain / (elapsedMinutes / 60);
  }

  /// Calculate estimated battery life based on recent drain rate
  Future<Duration?> estimateRemainingTime(String watchId) async {
    final now = DateTime.now();
    final drainRate = await calculateDrainRatePerHour(
      watchId: watchId,
      from: now.subtract(const Duration(hours: 24)),
      to: now,
    );

    if (drainRate == null || drainRate <= 0) return null;

    final latest = await getLatestReading(watchId);
    if (latest == null || latest.isCharging) return null;
    if (now.difference(latest.timestamp) > const Duration(hours: 2)) {
      return null; // avoid estimating from stale data
    }

    final hoursRemaining = latest.level / drainRate;
    return Duration(minutes: (hoursRemaining * 60).round());
  }

  /// Get daily battery snapshots for the last N days
  /// Returns one reading per day (first reading of each day)
  Future<List<BatteryReadingEntity>> getDailySnapshots({
    required String watchId,
    int days = 7,
  }) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - days);
    final to = now;

    final readings = await getBatteryReadings(
      watchId: watchId,
      from: from,
      to: to,
    );

    // Group by date and take first reading of each day
    final Map<String, BatteryReadingEntity> dailyReadings = {};
    for (final reading in readings) {
      final dateKey =
          '${reading.timestamp.year}-${reading.timestamp.month}-${reading.timestamp.day}';
      if (!dailyReadings.containsKey(dateKey)) {
        dailyReadings[dateKey] = reading;
      }
    }

    return dailyReadings.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Delete old battery readings
  Future<int> deleteOldReadings(DateTime cutoff) {
    return _db.deleteOldBatteryReadings(cutoff);
  }
}

/// Provider for battery repository
final batteryRepositoryProvider = Provider<BatteryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BatteryRepository(db);
});
