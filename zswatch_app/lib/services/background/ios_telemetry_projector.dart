import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../data/models/companion_watch_identity.dart';
import 'companion_prototype_client.dart';

/// Flutter alone writes Drift. Data and the native receipt watermark commit in
/// one transaction, so replay after a lost native acknowledgement is harmless.
class IosTelemetryProjector {
  final AppDatabase db;
  const IosTelemetryProjector(this.db);

  Future<int?> project(CompanionPrototypeSnapshot snapshot) async {
    if (!snapshot.isIos) return null;
    final namespace = snapshot.fields['journal_id'];
    final rows = snapshot.fields['telemetry'];
    if (namespace is! String ||
        !isIosWatchAddress(namespace) ||
        rows is! List) {
      throw const FormatException('Invalid native telemetry batch');
    }
    if (rows.isEmpty) return null;
    return db.transaction(() async {
      final ledger = await (db.select(
        db.companionTelemetryCursors,
      )..where((row) => row.journalId.equals(namespace))).getSingleOrNull();
      var cursor = ledger?.sequence ?? 0;
      var previous = 0;
      var consumed = false;
      final forgotten = snapshot.fields['forgotten_watches'];
      for (final raw in rows) {
        if (raw is! Map ||
            raw['sequence'] is! int ||
            raw['address'] is! String ||
            !isIosWatchAddress(raw['address'] as String) ||
            raw['generation'] is! int ||
            raw['utc_ms'] is! int ||
            raw['payload'] is! Map ||
            !const ['connection', 'battery', 'health'].contains(raw['kind'])) {
          throw const FormatException('Invalid native telemetry receipt');
        }
        final sequence = raw['sequence'] as int;
        if (sequence <= previous) {
          throw const FormatException('Unordered telemetry receipts');
        }
        previous = sequence;
        if (sequence <= cursor) {
          consumed = true;
          continue;
        }
        final address = (raw['address'] as String).toUpperCase();
        final generation = raw['generation'] as int;
        final tombstone = forgotten is Map ? forgotten[address] : null;
        if (tombstone is int && generation <= tombstone) {
          cursor = sequence;
          consumed = true;
          continue;
        }
        final timestamp = _date(raw['utc_ms']);
        final watch = await (db.select(
          db.watches,
        )..where((row) => row.id.upper().equals(address))).getSingleOrNull();
        // Catalogue creates rows only from a verified Ready receipt. Wait for
        // that writer rather than resurrecting a forgotten/missing watch here.
        if (watch == null) break;
        final payload = raw['payload'] as Map;
        switch (raw['kind']) {
          case 'connection':
            final type = payload['event_type'];
            if (!const [
              'connected',
              'disconnected',
              'reconnect_attempt',
              'reconnect_failed',
            ].contains(type)) {
              throw const FormatException('Invalid connection receipt');
            }
            await db
                .into(db.connectionEvents)
                .insert(
                  ConnectionEventsCompanion.insert(
                    watchId: watch.id,
                    eventType: type as String,
                    timestamp: timestamp,
                    reason: Value(payload['reason'] as String?),
                    sessionId: Value('$namespace:$generation'),
                  ),
                );
          case 'battery':
            final level = payload['level'];
            if (level is! int ||
                level < 0 ||
                level > 100 ||
                payload['is_charging'] is! bool) {
              throw const FormatException('Invalid battery receipt');
            }
            await db
                .into(db.batteryReadings)
                .insert(
                  BatteryReadingsCompanion.insert(
                    watchId: watch.id,
                    level: level,
                    timestamp: timestamp,
                    isCharging: Value(payload['is_charging'] as bool),
                  ),
                );
          case 'health':
            final measured = payload['ts'] == null
                ? timestamp
                : _date(payload['ts']);
            Future<void> sample(
              String type,
              num value,
              String granularity,
            ) async {
              await db
                  .into(db.healthSamples)
                  .insert(
                    HealthSamplesCompanion.insert(
                      watchId: watch.id,
                      type: type,
                      value: value.toDouble(),
                      timestamp: measured,
                      granularity: granularity,
                      syncedAt: timestamp,
                    ),
                  );
            }
            final steps = payload['stp'];
            final heart = payload['hrm'];
            if (steps is int && steps >= 0 && steps <= 10000000) {
              await sample('steps', steps, 'realtime');
            }
            if (heart is int && heart > 0 && heart <= 300) {
              await sample('heartRate', heart, 'realtime');
            }
            const activities = [
              'UNKNOWN',
              'NOT_WORN',
              'DEEP_SLEEP',
              'LIGHT_SLEEP',
              'REM_SLEEP',
              'ACTIVITY',
              'RUNNING',
              'WALKING',
              'SWIMMING',
              'CYCLING',
              'EXERCISE',
            ];
            final activity = activities.indexOf(
              payload['act'] as String? ?? '',
            );
            if (activity >= 0) await sample('activity', activity, 'realtime');
        }
        cursor = sequence;
        consumed = true;
      }
      if (!consumed || cursor == 0) return null;
      // Keep the existing 60-day history policy in the same transaction as the
      // receipt cursor. A lost native ACK must not resurrect expired samples.
      await db.cleanupOldData();
      await db
          .into(db.companionTelemetryCursors)
          .insertOnConflictUpdate(
            CompanionTelemetryCursorsCompanion.insert(
              journalId: namespace,
              sequence: cursor,
            ),
          );
      return cursor;
    });
  }

  DateTime _date(Object? millis) {
    if (millis is! int || millis <= 0 || millis > 8640000000000000) {
      throw const FormatException('Invalid telemetry timestamp');
    }
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}
