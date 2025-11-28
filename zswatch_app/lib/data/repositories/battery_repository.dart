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
    return _db.insertBatteryReading(BatteryReadingsCompanion(
      watchId: Value(watchId),
      level: Value(level),
      isCharging: Value(isCharging),
      timestamp: Value(timestamp ?? DateTime.now()),
    ));
  }

  /// Get battery readings for a watch within date range
  Future<List<BatteryReadingEntity>> getBatteryReadings({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) {
    return _db.getBatteryReadings(
      watchId: watchId,
      from: from,
      to: to,
    );
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

    // Filter out charging periods
    final dischargingReadings = <BatteryReadingEntity>[];
    for (int i = 0; i < readings.length; i++) {
      if (!readings[i].isCharging) {
        // Also check if this is part of a discharging sequence
        // (not immediately after charging)
        if (i == 0 || !readings[i - 1].isCharging) {
          dischargingReadings.add(readings[i]);
        }
      }
    }

    if (dischargingReadings.length < 2) return null;

    // Calculate drain between consecutive readings while discharging
    double totalDrain = 0;
    int drainSegments = 0;

    for (int i = 1; i < dischargingReadings.length; i++) {
      final prev = dischargingReadings[i - 1];
      final curr = dischargingReadings[i];

      // Only count if battery decreased
      if (curr.level < prev.level) {
        final drain = prev.level - curr.level;
        final hours = curr.timestamp.difference(prev.timestamp).inMinutes / 60;
        if (hours > 0) {
          totalDrain += drain / hours;
          drainSegments++;
        }
      }
    }

    return drainSegments > 0 ? totalDrain / drainSegments : null;
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
