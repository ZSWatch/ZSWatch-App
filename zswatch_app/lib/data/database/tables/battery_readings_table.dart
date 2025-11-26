import 'package:drift/drift.dart';

import 'watches_table.dart';

/// Battery readings table - battery level samples for analytics
///
/// Samples are taken every 5 minutes when connected.
/// Data is retained for 60 days for trend analysis.
@DataClassName('BatteryReadingEntity')
class BatteryReadings extends Table {
  /// Auto-incrementing row identifier
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to source watch
  TextColumn get watchId =>
      text().references(Watches, #id).named('watch_id')();

  /// Battery percentage (0-100)
  IntColumn get level => integer()();

  /// Whether the watch is currently charging
  BoolColumn get isCharging =>
      boolean().withDefault(const Constant(false)).named('is_charging')();

  /// When the sample was taken
  DateTimeColumn get timestamp => dateTime()();
}

