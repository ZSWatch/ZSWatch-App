import 'package:drift/drift.dart';

import 'watches_table.dart';

/// Health samples table - time-series health data from watch
///
/// Stores step counts, heart rate readings, and other health metrics.
/// Data is retained for 60 days with automatic cleanup.
@DataClassName('HealthSampleEntity')
class HealthSamples extends Table {
  /// Auto-incrementing row identifier
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to source watch
  TextColumn get watchId =>
      text().references(Watches, #id).named('watch_id')();

  /// Type of health data (steps, heartRate, sleep)
  TextColumn get type => text()();

  /// Measured value (steps count, BPM, minutes)
  RealColumn get value => real()();

  /// When the measurement was taken on the watch
  DateTimeColumn get timestamp => dateTime()();

  /// Time granularity (realtime, hourly, daily, weekly, monthly)
  TextColumn get granularity => text()();

  /// When the data was received by the app
  DateTimeColumn get syncedAt => dateTime().named('synced_at')();
}

