import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zswatch_app/data/database/companion_recording_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_recording.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/companion_recording_import_providers.dart';
import 'package:zswatch_app/providers/voice_memo_providers.dart';
import 'package:zswatch_app/providers/watch_providers.dart' as database;
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/voice_memos/voice_memos_screen.dart';

const watchId = 'AA:BB:CC:DD:EE:FF';
const hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
Map<String, Object?> record({
  String address = watchId,
  String state = 'pending',
  int timestamp = 1000,
}) => {
  'address': address,
  'filename': 'memo_001',
  'timestamp': timestamp,
  'duration_ms': 2000,
  'size_bytes': 100,
  'state': state,
};
String identity(Map<String, Object?> value) =>
    '${value['address']}:${value['filename']}:'
    '${value['timestamp']}:${value['size_bytes']}:${value['duration_ms']}';
CompanionPrototypeSnapshot snapshot(
  Map<String, Object?> recordings, {
  bool ready = true,
}) => CompanionPrototypeSnapshot.decode({
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': ready,
  'protocol_ready': ready,
  'phase': ready ? 'ready' : 'stopped',
  'event_cursor': 1,
  'generation': 7,
  'events': <Object?>[],
  'address': watchId,
  'recording_sync_enabled': false,
  'recording_list': {'address': watchId, 'generation': 7, 'count': 3},
  'recordings': recordings,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'saved result stays selected; latest failed or missing-model job shows its own recovery status',
    (tester) async {
      const savedId =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const failedId =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      final saved = {
        ...record(state: 'downloaded'),
        'local_path': '/private/raw.zsw_opus',
        'sha256': hash,
      };
      for (final mode in ['saved', 'failed', 'blocked']) {
        final preferSaved = mode == 'saved';
        final blocked = mode == 'blocked';
        final requested = <String>[];
        final state = CompanionPrototypeSnapshot.decode({
          ...snapshot({identity(saved): saved}).fields,
          'voice_jobs': [
            {
              'job_id': savedId,
              'watch_id': watchId,
              'recording_id': identity(saved),
              'generation': 1,
              'state': 'delivered',
              if (preferSaved) 'selected': true,
            },
            {
              'job_id': failedId,
              'watch_id': watchId,
              'recording_id': identity(saved),
              'generation': 2,
              'state': blocked ? 'blocked' : 'failed',
              'last_error': 'model_missing',
            },
          ],
        });
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(preferSaved),
            overrides: [
              companionSnapshotProvider.overrideWith(
                (ref) => Stream.value(state),
              ),
              companionRecordingImportsProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              companionVoiceJobProvider.overrideWith((ref, id) async {
                requested.add(id);
                return id == savedId
                    ? {
                        'state': 'delivered',
                        'result': {
                          'transcript': 'Previously saved speech',
                          'summary': 'Previously saved summary',
                          'actions': <Object?>[],
                        },
                      }
                    : {
                        'state': blocked ? 'blocked' : 'failed',
                        'last_error': 'model_missing',
                      };
              }),
              database.databaseProvider.overrideWith(
                (ref) => throw StateError('Unexpected DB'),
              ),

              transcriptionEngineProvider.overrideWith(
                (ref) => throw StateError('Unexpected inference'),
              ),
            ],
            child: const MaterialApp(home: VoiceMemosScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            preferSaved
                ? 'Processed • Shown on watch'
                : blocked
                ? 'Selected model not downloaded'
                : 'Processing failed',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(ValueKey(identity(saved))));
        await tester.pumpAndSettle();
        expect(requested, [preferSaved ? savedId : failedId]);
        expect(
          find.text('Previously saved speech'),
          preferSaved ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Reason: model_missing'),
          preferSaved ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Download models'),
          blocked ? findsOneWidget : findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  test(
    'receipt identity retains watch and metadata; failed/pending hashes never mean a completed receipt',
    () {
      final pending = {
        ...record(),
        'local_path': '/private/raw.zsw_opus',
        'sha256': hash,
      };
      final receipt = CompanionRecording.decode(identity(pending), pending);
      expect(receipt.hasCommittedReceipt, false);
      expect(receipt.timestampUtc.isUtc, true);
      expect(receipt.timestampUtc.millisecondsSinceEpoch, 1000000);
      final other = record(address: 'other-watch-uuid');
      expect(
        CompanionRecording.decode(identity(other), other).identity,
        isNot(receipt.identity),
      );
      final changed = record(timestamp: 1001);
      expect(
        CompanionRecording.decode(identity(changed), changed).identity,
        isNot(receipt.identity),
      );
      final failed = {
        ...pending,
        'state': 'failed',
        'error': 'transfer_timeout',
      };
      expect(
        CompanionRecording.decode(identity(failed), failed).hasCommittedReceipt,
        false,
      );
    },
  );

  test(
    'a downloaded journal entry requires its receipt metadata and exact identity',
    () {
      final value = {
        ...record(state: 'downloaded'),
        'local_path': '/private/raw.zsw_opus',
        'sha256': hash,
      };
      expect(
        CompanionRecording.decode(identity(value), value).hasCommittedReceipt,
        true,
      );
      for (final invalid in [
        {...value, 'sha256': null},
        {...value, 'sha256': 'bad-hash'},
        {...value, 'local_path': null},
        {...value, 'local_path': 'relative'},
        {...value, 'state': 'synced'},
        {...value, 'timestamp': 1000.0},
        {...value, 'filename': '../memo'},
        {...value, 'size_bytes': 0},
      ]) {
        expect(
          () => CompanionRecording.decode(identity(invalid), invalid),
          throwsFormatException,
        );
      }
      expect(
        () => CompanionRecording.decode('wrong-identity', value),
        throwsFormatException,
      );
    },
  );

  test(
    'native recording provider preserves distinct identities and sorts consistently without a database',
    () async {
      final older = record();
      final newer = record(timestamp: 1001);
      final secondWatch = record(address: 'second-watch');
      final container = ProviderContainer(
        overrides: [
          companionRecordingImportsProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(
              snapshot({
                identity(older): older,
                identity(newer): newer,
                identity(secondWatch): secondWatch,
              }),
            ),
          ),
          database.databaseProvider.overrideWith(
            (ref) => throw StateError('Unexpected DB'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(companionSnapshotProvider.future);
      final receipts = container.read(companionRecordingsProvider).requireValue;
      expect(receipts.length, 3);
      expect(receipts.first.identity, identity(newer));
      expect(receipts.map((r) => r.identity).toSet().length, 3);
      expect(() => receipts.clear(), throwsUnsupportedError);
    },
  );

  testWidgets(
    'existing Voice Notes screen shows native receipts without starting legacy sync, DB or AI',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final calls = <String>[];
      const channel = MethodChannel('dev.zswatch.app/companion_v1');
      final pending = record();
      final failed = {
        ...record(timestamp: 1001),
        'state': 'failed',
        'error': 'transfer_timeout',
      };
      final saved = {
        ...record(timestamp: 1002, state: 'downloaded'),
        'local_path': '/private/raw.zsw_opus',
        'sha256': hash,
      };
      final otherWatch = record(address: 'second-watch');
      final state = snapshot({
        identity(pending): pending,
        identity(failed): failed,
        identity(saved): saved,
        identity(otherWatch): otherWatch,
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return state.fields;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companionRecordingImportsProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            companionSnapshotProvider.overrideWith(
              (ref) => Stream.value(state),
            ),
            database.databaseProvider.overrideWith(
              (ref) => throw StateError('Unexpected DB'),
            ),

            voiceMemoRepositoryProvider.overrideWith(
              (ref) => throw StateError('Unexpected repository'),
            ),
            transcriptionEngineProvider.overrideWith(
              (ref) => throw StateError('Unexpected AI'),
            ),
          ],
          child: const MaterialApp(home: VoiceMemosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Downloads paused'), findsOneWidget);
      expect(find.textContaining('Download failed'), findsOneWidget);
      expect(find.textContaining('Waiting — downloads paused'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ListTile &&
              [
                identity(pending),
                identity(failed),
                identity(saved),
              ].any((id) => widget.key == ValueKey(id)),
        ),
        findsNWidgets(3),
      );
      expect(calls, isEmpty); // Opening the screen sends no sync/model command.
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh recording list'));
      await tester.pumpAndSettle();
      expect(calls, ['requestRecordingList']);
      expect(state.fields['recording_sync_enabled'], false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'playback preparation is explicit, local and safe if the view closes',
    (tester) async {
      final saved = {
        ...record(state: 'downloaded'),
        'local_path': '/private/raw.zsw_opus',
        'sha256': hash,
      };
      final state = snapshot({identity(saved): saved}, ready: false);
      final pending = Completer<ImportedRecording>();
      var prepares = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companionSnapshotProvider.overrideWith(
              (ref) => Stream.value(state),
            ),
            companionRecordingImportsProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            companionPreparePlaybackProvider.overrideWithValue((recording) {
              prepares++;
              return pending.future;
            }),

            transcriptionEngineProvider.overrideWith(
              (ref) => throw StateError('Unexpected AI'),
            ),
          ],
          child: const MaterialApp(home: VoiceMemosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(prepares, 0);
      await tester.tap(find.byTooltip('Prepare playback'));
      await tester.pump();
      expect(prepares, 1);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('Prepare playback'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      pending.completeError(StateError('interrupted'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preparation failure retains the original and offers retry', (
    tester,
  ) async {
    final saved = {
      ...record(state: 'downloaded'),
      'local_path': '/private/raw.zsw_opus',
      'sha256': hash,
    };
    var prepares = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          companionSnapshotProvider.overrideWith(
            (ref) =>
                Stream.value(snapshot({identity(saved): saved}, ready: false)),
          ),
          companionRecordingImportsProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          companionPreparePlaybackProvider.overrideWithValue((recording) async {
            prepares++;
            throw StateError('invalid');
          }),

          transcriptionEngineProvider.overrideWith(
            (ref) => throw StateError('Unexpected AI'),
          ),
        ],
        child: const MaterialApp(home: VoiceMemosScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Prepare playback'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not prepare playback. The original recording is retained.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Prepare playback'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(prepares, 1);
    expect(saved['state'], 'downloaded');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'stale imports do not claim playback readiness; successful preparation opens the local player',
    (tester) async {
      final saved = {
        ...record(state: 'downloaded'),
        'local_path': '/private/raw.zsw_opus',
        'sha256': hash,
      };
      final stale = ImportedRecording(
        identity: identity(saved),
        watchId: watchId,
        filename: 'memo_001',
        timestampUtc: 1000,
        durationMs: 2000,
        sizeBytes: 100,
        sourcePath: '/private/raw.zsw_opus',
        sourceSha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        playbackPath: '/nonexistent/playback.ogg',
        playbackSha256: hash,
        converterVersion: 1,
        importedAt: DateTime.utc(2026),
      );
      var prepares = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companionSnapshotProvider.overrideWith(
              (ref) => Stream.value(
                snapshot({identity(saved): saved}, ready: false),
              ),
            ),
            companionRecordingImportsProvider.overrideWith(
              (ref) => Stream.value([stale]),
            ),
            companionPreparePlaybackProvider.overrideWithValue((
              recording,
            ) async {
              prepares++;
              return stale.copyWith(sourceSha256: hash);
            }),

            transcriptionEngineProvider.overrideWith(
              (ref) => throw StateError('Unexpected AI'),
            ),
          ],
          child: const MaterialApp(home: VoiceMemosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(prepares, 0);
      expect(find.byTooltip('Play recording'), findsNothing);
      await tester.tap(find.byTooltip('Prepare playback'));
      await tester.pumpAndSettle();
      expect(prepares, 1);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Audio file not found'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
