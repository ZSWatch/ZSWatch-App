import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/companion_watch_providers.dart';
import 'package:zswatch_app/providers/watch_providers.dart' as database;
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/background/companion_watch_catalogue.dart';
import 'support/host_sqlite.dart';

const address = 'AA:BB:CC:DD:EE:FF';
Map<String, Object?> saved({
  int generation = 8,
  int readyGeneration = 7,
  int battery = 87,
}) => {
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': false,
  'protocol_ready': false,
  'phase': 'stopped',
  'generation': generation,
  'event_cursor': 10,
  'events': <Object?>[],
  'recordings': <String, Object?>{},
  'address': address,
  'last_ready': {
    'address': address,
    'generation': readyGeneration,
    'utc_ms': 1700000000123,
  },
  'watch_info': {
    'address': address,
    'version_generation': readyGeneration,
    'status_generation': readyGeneration,
    'firmware_version': '0.8.1',
    'hardware_version': 'watchdk',
    'battery_level': battery,
  },
};
CompanionPrototypeSnapshot snapshot([Map<String, Object?>? fields]) =>
    CompanionPrototypeSnapshot.decode(fields ?? saved());
CompanionWatchMetadata metadata([Map<String, Object?>? fields]) =>
    CompanionWatchMetadata.fromSnapshot(snapshot(fields))!;
Future<void> flush() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureHostSqlite();

  test(
    'old journals and malformed Ready receipts cannot fabricate saved watches',
    () {
      final old = saved()..remove('last_ready');
      expect(CompanionWatchMetadata.fromSnapshot(snapshot(old)), isNull);
      for (final changes in [
        {'address': '11:22:33:44:55:66'},
        {'address': 'bad'},
        {'generation': 9},
        {'generation': 0},
        {'generation': 7.0},
        {'utc_ms': 0},
        {'utc_ms': '1700000000000'},
        {'utc_ms': 8640000000000001},
      ]) {
        final fields = saved();
        fields['last_ready'] = {...fields['last_ready'] as Map, ...changes};
        expect(CompanionWatchMetadata.fromSnapshot(snapshot(fields)), isNull);
      }
    },
  );

  test(
    'historical readiness is not live status and ignores other-generation versions/battery',
    () {
      final fields = saved();
      final info = fields['watch_info'] as Map;
      info['version_generation'] = 8;
      info['status_generation'] = 8;
      final value = metadata(fields);
      expect(value.firmware, isNull);
      expect(value.hardware, isNull);
      expect(value.battery, isNull);
      expect(value.readyAt.millisecondsSinceEpoch, 1700000000000);
      expect(snapshot(fields).runtimeActive, false);
      expect(snapshot(fields).protocolReady, false);
      info['address'] = '11:22:33:44:55:66';
      expect(metadata(fields).firmware, isNull);
    },
  );

  test(
    'new watch saves once and reattachment survives actual file-backed reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'companion-catalogue-',
      );
      final file = File('${directory.path}/app.db');
      var db = AppDatabase.forTesting(
        NativeDatabase(file),
        recoverLegacyProcessing: false,
      );
      try {
        final catalogue = CompanionWatchCatalogue(db);
        await catalogue.save(metadata());
        final first = await db.getAllWatches();
        expect(first, hasLength(1));
        expect(first.single.id, address);
        expect(first.single.isPrimary, false);
        expect(first.single.customName, isNull);
        expect(first.single.firmwareVersion, '0.8.1');
        expect(first.single.batteryLevel, 87);
        final changes =
            (await db
                    .customSelect('SELECT total_changes() AS count')
                    .getSingle())
                .read<int>('count');
        await catalogue.save(metadata());
        expect(
          (await db.customSelect('SELECT total_changes() AS count').getSingle())
              .read<int>('count'),
          changes,
        );
        expect(await db.getAllWatches(), first);
        await db.close();
        db = AppDatabase.forTesting(
          NativeDatabase(file),
          recoverLegacyProcessing: false,
        );
        await CompanionWatchCatalogue(db).save(metadata());
        expect(await db.getAllWatches(), first);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'legacy row keeps ID/name/custom name/primary/history and unrelated voice data',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        recoverLegacyProcessing: false,
      );
      try {
        await db
            .into(db.watches)
            .insert(
              WatchesCompanion.insert(
                id: address.toLowerCase(),
                name: 'Advertised name',
                customName: const Value('Personal name'),
                isPrimary: const Value(true),
                supportsExtendedApi: const Value(true),
                createdAt: DateTime.utc(2020),
                lastConnectedAt: Value(DateTime.utc(2021)),
                firmwareVersion: const Value('old'),
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
        final before = (await db.getAllWatches()).single;
        final voice = await db.select(db.voiceMemos).get();
        await CompanionWatchCatalogue(db).save(metadata());
        final after = (await db.getAllWatches()).single;
        expect(after.id, before.id);
        expect(after.name, before.name);
        expect(after.customName, before.customName);
        expect(after.isPrimary, before.isPrimary);
        expect(after.createdAt, before.createdAt);
        expect(after.supportsExtendedApi, before.supportsExtendedApi);
        expect(
          after.lastConnectedAt!.isAtSameMomentAs(metadata().readyAt),
          true,
        );
        expect(after.firmwareVersion, '0.8.1');
        expect(await db.select(db.voiceMemos).get(), voice);
        final older = saved();
        (older['last_ready'] as Map)['utc_ms'] = 1600000000000;
        await CompanionWatchCatalogue(db).save(metadata(older));
        expect((await db.getAllWatches()).single, after);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'ambiguous MAC aliases fail without writes; exact existing key has priority',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        recoverLegacyProcessing: false,
      );
      try {
        for (final id in [address.toLowerCase(), 'Aa:Bb:Cc:Dd:Ee:Ff']) {
          await db
              .into(db.watches)
              .insert(
                WatchesCompanion.insert(
                  id: id,
                  name: 'Preserved',
                  createdAt: DateTime.utc(2020),
                ),
              );
        }
        final before = await db.getAllWatches();
        await expectLater(
          CompanionWatchCatalogue(db).save(metadata()),
          throwsStateError,
        );
        expect(await db.getAllWatches(), before);
        await db
            .into(db.watches)
            .insert(
              WatchesCompanion.insert(
                id: address,
                name: 'Exact',
                createdAt: DateTime.utc(2020),
              ),
            );
        await CompanionWatchCatalogue(db).save(metadata());
        final after = await db.getAllWatches();
        expect(after.take(2), before);
        expect(after.last.name, 'Exact');
        expect(after.last.firmwareVersion, '0.8.1');
      } finally {
        await db.close();
      }
    },
  );

  test(
    'serial writer coalesces repeated events and keeps the latest pending metadata',
    () async {
      final firstWrite = Completer<void>();
      final writes = <CompanionWatchMetadata>[];
      var inFlight = 0;
      var maxInFlight = 0;
      final writer = CompanionWatchPersistence((value) async {
        writes.add(value);
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        if (writes.length == 1) await firstWrite.future;
        inFlight--;
      });
      try {
        writer.observe(snapshot());
        for (var i = 0; i < 100; i++) {
          writer.observe(snapshot());
        }
        writer.observe(snapshot(saved(battery: 80)));
        expect(writes, hasLength(1));
        expect(writer.state.isLoading, true);
        firstWrite.complete();
        await flush();
        expect(writes, hasLength(2));
        expect(writes.last.battery, 80);
        expect(maxInFlight, 1);
        writer.observe(snapshot(saved(battery: 80)));
        await flush();
        expect(writes, hasLength(2));
      } finally {
        writer.dispose();
      }
    },
  );

  test(
    'failed writes retry and disposal cannot write queued metadata or alter BLE',
    () async {
      var attempts = 0;
      final writer = CompanionWatchPersistence((value) async {
        attempts++;
        if (attempts == 1) throw StateError('Storage failed');
      });
      writer.observe(snapshot());
      await flush();
      expect(writer.state.hasError, true);
      writer.observe(snapshot());
      await flush();
      expect(attempts, 2);
      expect(writer.state.hasError, false);
      writer.dispose();
      final gate = Completer<void>();
      final writes = <CompanionWatchMetadata>[];
      final detached = CompanionWatchPersistence((value) async {
        writes.add(value);
        await gate.future;
      });
      detached.observe(snapshot());
      detached.observe(snapshot(saved(battery: 80)));
      detached.dispose();
      gate.complete();
      await flush();
      expect(writes, hasLength(1));
    },
  );

  test(
    'provider projects stopped history without acquiring legacy BLE and reattachment is idempotent',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        recoverLegacyProcessing: false,
      );
      ProviderContainer attach() => ProviderContainer(
        overrides: [
          database.databaseProvider.overrideWithValue(db),
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(snapshot()),
          ),
        ],
      );
      var container = attach();
      try {
        container.read(companionWatchPersistenceProvider);
        await flush();
        final first = await db.getAllWatches();
        expect(first, hasLength(1));
        expect(container.read(isWatchConnectedProvider), false);
        container.dispose();
        container = attach();
        container.read(companionWatchPersistenceProvider);
        await flush();
        expect(await db.getAllWatches(), first);
        expect(container.read(isWatchConnectedProvider), false);
      } finally {
        container.dispose();
        await db.close();
      }
    },
  );
}
