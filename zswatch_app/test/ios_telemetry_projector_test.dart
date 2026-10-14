import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/background/ios_telemetry_projector.dart';

void main() {
  const watch = 'F31A05BD-1C30-4B66-AAC0-157004320111';
  const journal = 'F31A05BD-1C30-4B66-AAC0-157004320222';
  final now = DateTime.now().millisecondsSinceEpoch;
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
    'events': <Object?>[],
    'recordings': <String, Object?>{},
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
  test('60-day retention and replay watermark commit together', () async {
    final expired = now - const Duration(days: 61).inMilliseconds;
    final recent = now - const Duration(days: 59).inMilliseconds;
    final batch = snapshot([
      receipt(1, 'connection', {'event_type': 'connected'})
        ..['utc_ms'] = expired,
      receipt(2, 'battery', {'level': 85, 'is_charging': false})
        ..['utc_ms'] = expired,
      receipt(3, 'health', {'stp': 100, 'hrm': 70})
        ..['utc_ms'] = expired,
      receipt(4, 'connection', {'event_type': 'connected'})
        ..['utc_ms'] = recent,
      receipt(5, 'battery', {'level': 87, 'is_charging': false})
        ..['utc_ms'] = recent,
      receipt(6, 'health', {'stp': 200, 'hrm': 72})
        ..['utc_ms'] = recent,
    ]);
    expect(await projector.project(batch), 6);
    expect(await projector.project(batch), 6);
    expect(await db.select(db.connectionEvents).get(), hasLength(1));
    expect(await db.select(db.batteryReadings).get(), hasLength(1));
    final samples = await db.select(db.healthSamples).get();
    expect(samples, hasLength(2));
    expect(samples.map((sample) => sample.value), containsAll([200, 72]));
    expect(await db.select(db.watches).get(), hasLength(1));
    expect(
      (await db.select(db.companionTelemetryCursors).get()).single.sequence,
      6,
    );
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
