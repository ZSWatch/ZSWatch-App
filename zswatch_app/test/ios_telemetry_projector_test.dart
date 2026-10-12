import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/background/ios_telemetry_projector.dart';

void main() {
  const watch = 'F31A05BD-1C30-4B66-AAC0-157004320111';
  const journal = 'F31A05BD-1C30-4B66-AAC0-157004320222';
  const now = 1791830000000;
  late AppDatabase db;
  late IosTelemetryProjector projector;
  Map<String, Object?> receipt(
    int sequence,
    String kind,
    Map<String, Object?> payload,
  ) => {
    'sequence': sequence,
    'kind': kind,
    'address': watch,
    'generation': 3,
    'utc_ms': now,
    'payload': payload,
  };
  CompanionPrototypeSnapshot snapshot(
    List<Map<String, Object?>> receipts, {
    bool forgotten = false,
  }) => CompanionPrototypeSnapshot.decode({
    'version': 1,
    'owner': 'ios_companion_native',
    'runtime_active': true,
    'protocol_ready': true,
    'phase': 'ready',
    'generation': 3,
    'event_cursor': 4,
    'events': [],
    'recordings': {},
    'address': watch,
    'journal_id': journal,
    'telemetry': receipts,
    'forgotten_watches': {if (forgotten) watch: 4},
  });
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projector = IosTelemetryProjector(db);
    await db
        .into(db.watches)
        .insert(
          WatchesCompanion.insert(
            id: watch,
            name: 'ZSWatch',
            createdAt: DateTime.now(),
          ),
        );
  });
  tearDown(() => db.close());

  test(
    'replayed receipts commit health/battery/connection exactly once',
    () async {
      final batch = snapshot([
        receipt(1, 'connection', {'event_type': 'connected'}),
        receipt(2, 'battery', {'level': 87, 'is_charging': false}),
        receipt(3, 'health', {
          'stp': 1234,
          'hrm': 72,
          'act': 'WALKING',
          'ts': now,
        }),
      ]);
      expect(await projector.project(batch), 3);
      expect(
        await projector.project(batch),
        3,
      ); // DB commit survived a lost native ack.
      expect(await db.select(db.healthSamples).get(), hasLength(3));
      expect(await db.select(db.batteryReadings).get(), hasLength(1));
      final events = await db.select(db.connectionEvents).get();
      expect(events, hasLength(1));
      expect(events.single.sessionId, '$journal:3');
      expect(
        (await db.select(db.companionTelemetryCursors).get()).single.sequence,
        3,
      );
    },
  );
  test('malformed batch rolls back data and watermark together', () async {
    await expectLater(
      projector.project(
        snapshot([
          receipt(1, 'battery', {'level': 87, 'is_charging': false}),
          receipt(2, 'connection', {'event_type': 'fabricated'}),
        ]),
      ),
      throwsFormatException,
    );
    expect(await db.select(db.batteryReadings).get(), isEmpty);
    expect(await db.select(db.companionTelemetryCursors).get(), isEmpty);
  });
  test(
    'missing watch waits for catalogue without acknowledgement loop or resurrection',
    () async {
      await projector.project(
        snapshot([
          receipt(1, 'connection', {'event_type': 'connected'}),
        ]),
      );
      await db.deleteWatch(watch);
      expect(
        await projector.project(
          snapshot([
            receipt(2, 'battery', {'level': 87, 'is_charging': true}),
          ]),
        ),
        isNull,
      );
      expect(await db.select(db.watches).get(), isEmpty);
      expect(await db.select(db.batteryReadings).get(), isEmpty);
      expect(
        (await db.select(db.companionTelemetryCursors).get()).single.sequence,
        1,
      );
    },
  );
  test(
    'Forget tombstone consumes old receipts without restoring deleted history',
    () async {
      await db.deleteWatch(watch);
      expect(
        await projector.project(
          snapshot([
            receipt(1, 'health', {'stp': 1234, 'hrm': 72}),
          ], forgotten: true),
        ),
        1,
      );
      expect(await db.select(db.watches).get(), isEmpty);
      expect(await db.select(db.healthSamples).get(), isEmpty);
    },
  );
}
