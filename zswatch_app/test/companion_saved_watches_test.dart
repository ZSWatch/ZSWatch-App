import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/providers/auto_reconnect_provider.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/companion_watch_providers.dart';
import 'package:zswatch_app/providers/watch_providers.dart' as database;
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/start/start_page_screen.dart';

import 'support/host_sqlite.dart';

const address = 'AA:BB:CC:DD:EE:FF';
Map<String, Object?> state({bool active = false, bool ready = false}) => {
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': active,
  'protocol_ready': ready,
  'phase': ready
      ? 'ready'
      : active
      ? 'connecting'
      : 'stopped',
  'generation': 7,
  'event_cursor': 1,
  'events': <Object?>[],
  'recordings': <String, Object?>{},
  'address': address,
  'watch_info': {
    'address': address,
    'first_seen_ms': 1000,
    'firmware_version': 'live-firmware',
    'battery_level': 87,
    'status_generation': 7,
  },
};

Future<void> seed(AppDatabase db) async {
  await db
      .into(db.watches)
      .insert(
        WatchesCompanion.insert(
          id: address.toLowerCase(),
          name: 'ZSWatch',
          customName: const Value('My watch'),
          firmwareVersion: const Value('stale-firmware'),
          batteryLevel: const Value(12),
          isPrimary: const Value(true),
          createdAt: DateTime.utc(2025),
          lastConnectedAt: Value(DateTime.utc(2026)),
        ),
      );
  await db
      .into(db.watches)
      .insert(
        WatchesCompanion.insert(
          id: '11:22:33:44:55:66',
          name: 'Other watch',
          createdAt: DateTime.utc(2025),
        ),
      );
  await db
      .into(db.voiceMemos)
      .insert(
        VoiceMemosCompanion.insert(
          filename: 'fixture',
          timestampUtc: 1000,
          durationMs: 2000,
          sizeBytes: 3000,
          processingStatus: const Value('summarizing'),
        ),
      );
}

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureHostSqlite();

  test('v6 upgrade removes only prototype chat history', () async {
    final directory = await Directory.systemTemp.createTemp('chat-removal-');
    final file = File('${directory.path}/app.db');
    var db = AppDatabase.forTesting(
      NativeDatabase(file),
      recoverLegacyProcessing: false,
    );
    try {
      await seed(db);
      final watches = await db.getAllWatches();
      final memos = await db.select(db.voiceMemos).get();
      // Model an existing v6 database containing the prototype-only table.
      await db.customStatement(
        'CREATE TABLE chat_history (id INTEGER PRIMARY KEY)',
      );
      await db.customStatement('INSERT INTO chat_history VALUES (1)');
      await db.customStatement('PRAGMA user_version = 6');
      await db.close();
      db = AppDatabase.forTesting(
        NativeDatabase(file),
        recoverLegacyProcessing: false,
      );
      expect(await db.getAllWatches(), watches);
      expect(await db.select(db.voiceMemos).get(), memos);
      expect(
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='chat_history'",
            )
            .get(),
        isEmpty,
      );
      expect(db.schemaVersion, 7);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'native database reopen preserves processing; legacy reopen recovers it',
    () async {
      final directory = await Directory.systemTemp.createTemp('companion-db-');
      final file = File('${directory.path}/app.db');
      var db = AppDatabase.forTesting(
        NativeDatabase(file),
        recoverLegacyProcessing: false,
      );
      try {
        await seed(db);
        final before = await db.select(db.voiceMemos).get();
        await db.close();
        db = AppDatabase.forTesting(
          NativeDatabase(file),
          recoverLegacyProcessing: false,
        );
        expect(await db.getAllWatches(), hasLength(2));
        expect(await db.select(db.voiceMemos).get(), before);
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          7,
        );
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        final recovered = await db.select(db.voiceMemos).getSingle();
        expect(recovered.processingStatus, 'failed');
        expect(recovered.summary, isNull);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'saved metadata follows renames without creating connection or stale battery',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        recoverLegacyProcessing: false,
      );
      await seed(db);
      final snapshots = StreamController<CompanionPrototypeSnapshot>();
      final container = ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          database.databaseProvider.overrideWithValue(db),
          companionSnapshotProvider.overrideWith((ref) => snapshots.stream),
          watchServiceProvider.overrideWith(
            (ref) => throw StateError('Legacy BLE'),
          ),
        ],
      );
      container.listen(currentWatchProvider, (_, _) {});
      try {
        await container.read(database.allWatchesProvider.future);
        snapshots.add(
          CompanionPrototypeSnapshot.decode(state(active: true, ready: true)),
        );
        await flush();
        var watch = container.read(currentWatchProvider)!;
        expect(watch.id, address);
        expect(watch.displayName, 'My watch');
        expect(watch.firmwareVersion, 'live-firmware');
        expect(watch.batteryLevel, 87);
        expect(container.read(isWatchConnectedProvider), true);
        final beforeWatches = await db.getAllWatches();
        final beforeMemos = await db.select(db.voiceMemos).get();
        final rename = container.read(companionRenameWatchProvider);
        await rename(address.toLowerCase(), ' Renamed ');
        await flush();
        expect(container.read(currentWatchProvider)!.displayName, 'Renamed');
        final afterWatches = await db.getAllWatches();
        expect(
          afterWatches.first.copyWith(customName: const Value('My watch')),
          beforeWatches.first,
        );
        expect(afterWatches.last, beforeWatches.last);
        expect(await db.select(db.voiceMemos).get(), beforeMemos);
        await expectLater(rename('missing', 'Name'), throwsStateError);
        expect(await db.getAllWatches(), afterWatches);
        await rename(address.toLowerCase(), null);
        await flush();
        expect(container.read(currentWatchProvider)!.displayName, 'ZSWatch');
        snapshots.add(CompanionPrototypeSnapshot.decode(state()));
        await flush();
        watch = container.read(currentWatchProvider)!;
        expect(watch.displayName, 'ZSWatch');
        expect(container.read(batteryLevelProvider), isNull);
        expect(container.read(isWatchConnectedProvider), false);
      } finally {
        container.dispose();
        await snapshots.close();
        await db.close();
      }
    },
  );

  test('ambiguous aliases cannot choose another saved name', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      recoverLegacyProcessing: false,
    );
    await seed(db);
    await db
        .into(db.watches)
        .insert(
          WatchesCompanion.insert(
            id: 'Aa:Bb:Cc:Dd:Ee:Ff',
            name: 'Ambiguous',
            createdAt: DateTime.utc(2025),
          ),
        );
    final container = ProviderContainer(
      overrides: [
        nativeCompanionRuntimeProvider.overrideWithValue(true),
        database.databaseProvider.overrideWithValue(db),
        companionSnapshotProvider.overrideWith(
          (ref) => Stream.value(CompanionPrototypeSnapshot.decode(state())),
        ),
      ],
    );
    container.listen(currentWatchProvider, (_, _) {});
    try {
      await container.read(database.allWatchesProvider.future);
      await flush();
      expect(container.read(currentWatchProvider)!.customName, isNull);
    } finally {
      container.dispose();
      await db.close();
    }
  });

  testWidgets(
    'existing saved-watch tile connects explicitly and rename dialog stays metadata only',
    (tester) async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        recoverLegacyProcessing: false,
      );
      await tester.runAsync(() => seed(db));
      var rows = (await tester.runAsync(db.getAllWatches))!;
      await tester.runAsync(db.close);
      final catalogue = StreamController<List<WatchEntity>>.broadcast();
      final snapshots = StreamController<CompanionPrototypeSnapshot>();
      final calls = <MethodCall>[];
      var permissions = 0;
      const channel = MethodChannel('dev.zswatch.app/companion_v1');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {'version': 1, 'accepted': true};
      });
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nativeCompanionRuntimeProvider.overrideWithValue(true),
              database.allWatchesProvider.overrideWith(
                (ref) => catalogue.stream,
              ),
              companionRenameWatchProvider.overrideWithValue((id, name) async {
                rows = rows
                    .map(
                      (row) => row.id == id
                          ? row.copyWith(customName: Value(name))
                          : row,
                    )
                    .toList();
                catalogue.add(rows);
              }),
              companionForgetWatchProvider.overrideWithValue((id) async {
                throw StateError('Forget must not run during rename');
              }),
              companionSnapshotProvider.overrideWith((ref) => snapshots.stream),
              companionConnectionPermissionsProvider.overrideWithValue(
                () async {
                  permissions++;
                },
              ),
              watchServiceProvider.overrideWith(
                (ref) => throw StateError('Legacy BLE'),
              ),
              autoReconnectServiceProvider.overrideWith(
                (ref) => throw StateError('Legacy reconnect'),
              ),
            ],
            child: const MaterialApp(home: StartPageScreen()),
          ),
        );
        catalogue.add(rows);
        snapshots.add(CompanionPrototypeSnapshot.decode(state()));
        await tester.pumpAndSettle();
        expect(find.text('My watch'), findsNWidgets(2));
        expect(calls, isEmpty);
        expect(permissions, 0);
        final tile = find.byKey(ValueKey(address.toLowerCase()));
        await tester.tap(
          find.descendant(of: tile, matching: find.byTooltip('Watch Settings')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Forget Watch'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'UI renamed');
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('UI renamed'), findsNWidgets(2));
        expect(calls, isEmpty);
        await tester.tap(
          find.descendant(of: tile, matching: find.text('UI renamed')),
        );
        await tester.pump();
        expect(permissions, 1);
        expect(calls.single.method, 'start');
        expect(calls.single.arguments, {'version': 1, 'address': address});
        expect(find.text('Watch disconnected'), findsOneWidget);
        snapshots.add(CompanionPrototypeSnapshot.decode(state(active: true)));
        await tester.pump();
        await tester.pump();
        await tester.tap(find.text('Other watch'));
        await tester.pump();
        expect(calls, hasLength(1));
        expect(find.text('Cancel connection'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        messenger.setMockMethodCallHandler(channel, null);
        unawaited(snapshots.close());
        unawaited(catalogue.close());
        await tester.pump();
      }
    },
  );

  test('Android selection accepts MACs and rejects old iOS IDs', () {
    expect(isCompanionWatchAddress(address.toLowerCase()), true);
    expect(isCompanionWatchAddress('bad'), false);
    expect(
      isCompanionWatchAddress('7AFB25CA-1234-ABCD-DCBA-ABCDEF123456'),
      false,
    );
  });
}
