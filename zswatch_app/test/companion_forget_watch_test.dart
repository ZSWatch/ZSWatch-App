import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/providers/companion_watch_providers.dart';
import 'package:zswatch_app/providers/watch_providers.dart' as database;
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/background/companion_watch_catalogue.dart';

import 'support/host_sqlite.dart';

const _address = 'AA:BB:CC:DD:EE:FF';

Map<String, Object?> _forgottenSnapshot() => {
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': false,
  'protocol_ready': false,
  'phase': 'stopped',
  'event_cursor': 3,
  'generation': 4,
  'address': '',
  'events': <Object?>[],
  'recordings': <String, Object?>{},
  'last_ready': null,
  'watch_info': null,
  'forgotten_watches': {_address: 4},
  'forget_receipt': {
    'address': _address,
    'generation': 4,
    'association_removed': true,
  },
};

CompanionPrototypeSnapshot _ready({int generation = 3, int cursor = 2}) =>
    CompanionPrototypeSnapshot.decode({
      ..._forgottenSnapshot(),
      'address': _address,
      'runtime_active': true,
      'protocol_ready': true,
      'phase': 'ready',
      'generation': generation,
      'event_cursor': cursor,
      'forgotten_watches': <String, int>{},
      'last_ready': {
        'address': _address,
        'generation': generation,
        'utc_ms': 1700000000000 + generation * 1000,
      },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureHostSqlite();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      recoverLegacyProcessing: false,
    );
    await db.upsertWatch(
      WatchesCompanion.insert(
        id: _address,
        name: 'ZSWatch',
        createdAt: DateTime.utc(2026),
      ),
    );
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await db.close();
  });

  test(
    'native Forget runs while the local row still exists, then deletes it',
    () async {
      var rowWasPresentAtNativeCommand = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'forgetWatch');
        rowWasPresentAtNativeCommand = await db.getWatchById(_address) != null;
        return _forgottenSnapshot();
      });
      final container = ProviderContainer(
        overrides: [database.databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await container.read(companionForgetWatchProvider)(_address);
      expect(rowWasPresentAtNativeCommand, isTrue);
      expect(await db.getWatchById(_address), isNull);
    },
  );

  test('native Forget failure leaves the local row intact', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'COMMAND_FAILED');
    });
    final container = ProviderContainer(
      overrides: [database.databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(companionForgetWatchProvider)(_address),
      throwsA(isA<PlatformException>()),
    );
    expect(await db.getWatchById(_address), isNotNull);
  });

  test(
    'lowercase legacy key and its history are deleted while voice data survives',
    () async {
      await db.deleteWatch(_address);
      final id = _address.toLowerCase();
      await db.upsertWatch(
        WatchesCompanion.insert(
          id: id,
          name: 'Legacy',
          createdAt: DateTime.utc(2020),
        ),
      );
      await db
          .into(db.batteryReadings)
          .insert(
            BatteryReadingsCompanion.insert(
              watchId: id,
              level: 80,
              timestamp: DateTime.utc(2020),
            ),
          );
      await db
          .into(db.voiceMemos)
          .insert(
            VoiceMemosCompanion.insert(
              filename: 'preserved',
              timestampUtc: 1,
              durationMs: 2,
              sizeBytes: 3,
              processingStatus: const Value('queued'),
            ),
          );
      final voice = await db.select(db.voiceMemos).get();
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect((call.arguments as Map)['address'], _address);
        expect(await db.getWatchById(id), isNotNull);
        return _forgottenSnapshot();
      });
      final container = ProviderContainer(
        overrides: [database.databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await container.read(companionForgetWatchProvider)(id);
      expect(await db.getAllWatches(), isEmpty);
      expect(await db.select(db.batteryReadings).get(), isEmpty);
      expect(await db.select(db.voiceMemos).get(), voice);
    },
  );

  test('unconfirmed native response cannot delete local data', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return _forgottenSnapshot()..remove('forget_receipt');
    });
    final container = ProviderContainer(
      overrides: [database.databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(companionForgetWatchProvider)(_address),
      throwsFormatException,
    );
    expect(await db.getWatchById(_address), isNotNull);
  });

  test(
    'in-flight and stale Ready saves cannot recreate a forgotten row',
    () async {
      final gate = Completer<void>();
      var writes = 0;
      var deleted = false;
      final writer = CompanionWatchPersistence((metadata) async {
        writes++;
        if (writes == 1) await gate.future;
        await CompanionWatchCatalogue(db).save(metadata);
      });
      addTearDown(writer.dispose);
      writer.observe(_ready());
      writer.observe(_ready(generation: 3, cursor: 3));
      final forgotten = writer.forget(
        _address,
        forgetNative: () async => 4,
        delete: () async {
          await db.deleteWatch(_address);
          deleted = true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(deleted, isFalse);
      writer.observe(_ready());
      gate.complete();
      await forgotten;
      expect(await db.getAllWatches(), isEmpty);
      writer.observe(_ready(generation: 3, cursor: 5));
      await Future<void>.delayed(Duration.zero);
      expect(writes, 1);
      expect(await db.getAllWatches(), isEmpty);
      // New explicit connection readiness after Forget may save the watch again.
      writer.observe(_ready(generation: 5, cursor: 6));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(writes, 2);
      expect(await db.getWatchById(_address), isNotNull);
    },
  );

  test(
    'native tombstone fences stale metadata after Flutter reattachment',
    () async {
      var writes = 0;
      final writer = CompanionWatchPersistence((metadata) async {
        writes++;
      });
      addTearDown(writer.dispose);
      writer.observe(CompanionPrototypeSnapshot.decode(_forgottenSnapshot()));
      writer.observe(_ready());
      writer.observe(
        CompanionPrototypeSnapshot.decode({
          ..._ready(generation: 3, cursor: 5).fields,
          'forgotten_watches': {_address: 4},
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(writes, 0);
    },
  );
}
