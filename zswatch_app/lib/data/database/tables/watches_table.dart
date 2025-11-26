import 'package:drift/drift.dart';

/// Watches table - stores paired ZSWatch devices
///
/// Each watch is identified by its BLE device ID (MAC address on Android,
/// UUID on iOS). Only one watch can be marked as primary at a time.
@DataClassName('WatchEntity')
class Watches extends Table {
  /// BLE device identifier (MAC address or UUID)
  TextColumn get id => text()();

  /// Advertised device name (e.g., "ZSWatch")
  TextColumn get name => text()();

  /// Last known firmware version from `t:"ver"` message
  TextColumn get firmwareVersion => text().nullable()();

  /// Hardware revision if available
  TextColumn get hardwareVersion => text().nullable()();

  /// Last known battery percentage (0-100)
  IntColumn get batteryLevel => integer().nullable()();

  /// Currently selected/active watch
  BoolColumn get isPrimary =>
      boolean().withDefault(const Constant(false)).named('is_primary')();

  /// Whether firmware supports Extended ZSWatch API
  BoolColumn get supportsExtendedApi => boolean()
      .withDefault(const Constant(false))
      .named('supports_extended_api')();

  /// Timestamp of last successful connection
  DateTimeColumn get lastConnectedAt =>
      dateTime().nullable().named('last_connected_at')();

  /// When the device was first paired
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

