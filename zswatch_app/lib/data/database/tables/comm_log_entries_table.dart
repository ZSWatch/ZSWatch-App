import 'package:drift/drift.dart';

/// Communication log entries table - BLE message logging for debugging
///
/// Stores all BLE communication with rotation at 5,000 entries or 5MB.
/// Used by developers for protocol debugging and troubleshooting.
@DataClassName('CommLogEntryEntity')
class CommLogEntries extends Table {
  /// Auto-incrementing row identifier
  IntColumn get id => integer().autoIncrement()();

  /// Message direction (incoming/outgoing)
  TextColumn get direction => text()();

  /// Protocol type (gadgetbridge/extended/mcumgr/unknown)
  TextColumn get protocol => text()();

  /// GATT characteristic UUID (if applicable)
  TextColumn get characteristic => text().nullable()();

  /// Message payload (truncated to 1KB max)
  TextColumn get payload => text()();

  /// Original payload size in bytes (before truncation)
  IntColumn get payloadSize => integer().named('payload_size')();

  /// When the message was sent/received
  DateTimeColumn get timestamp => dateTime()();
}
