import 'package:drift/drift.dart';

import 'watches_table.dart';

/// Connection events table - tracks connection/disconnection events for analytics
///
/// Used to calculate:
/// - Connection uptime percentage
/// - Disconnection frequency and reasons
/// - Average session duration
/// - Reconnection success rate
@DataClassName('ConnectionEventEntity')
class ConnectionEvents extends Table {
  /// Auto-incrementing row identifier
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to source watch
  TextColumn get watchId =>
      text().references(Watches, #id).named('watch_id')();

  /// Type of event: connected, disconnected, reconnect_attempt, reconnect_failed
  TextColumn get eventType => text().named('event_type')();

  /// When the event occurred
  DateTimeColumn get timestamp => dateTime()();

  /// Reason for disconnection (only for disconnect events)
  /// Values: user_requested, connection_lost, device_unavailable, 
  ///         bluetooth_disabled, app_terminated, unknown
  TextColumn get reason => text().nullable()();

  /// Additional details (e.g., error message)
  TextColumn get details => text().nullable()();

  /// Session ID to group connect/disconnect pairs
  /// Generated as UUID when connection is established
  TextColumn get sessionId => text().nullable().named('session_id')();
}
