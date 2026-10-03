import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_recording.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/voice_memo_providers.dart';
import 'package:zswatch_app/providers/watch_providers.dart' as database;
import 'package:zswatch_app/providers/watch_service_provider.dart';
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
          nativeCompanionRuntimeProvider.overrideWithValue(true),
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
            nativeCompanionRuntimeProvider.overrideWithValue(true),
            companionSnapshotProvider.overrideWith(
              (ref) => Stream.value(state),
            ),
            database.databaseProvider.overrideWith(
              (ref) => throw StateError('Unexpected DB'),
            ),
            watchServiceProvider.overrideWith(
              (ref) => throw StateError('Unexpected Dart BLE'),
            ),
            voiceMemoSyncServiceProvider.overrideWith(
              (ref) => throw StateError('Unexpected legacy sync'),
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
      expect(find.text('3 recordings • 1 saved on phone'), findsOneWidget);
      expect(find.text('Downloads paused'), findsOneWidget);
      expect(find.text('Latest watch list: 3 recordings'), findsOneWidget);
      expect(find.textContaining('Download failed'), findsOneWidget);
      expect(find.textContaining('Waiting — downloads paused'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(calls, isEmpty); // Opening the screen sends no sync/model command.
      await tester.tap(find.byTooltip('Refresh recording list'));
      await tester.pumpAndSettle();
      expect(calls, ['requestRecordingList']);
      expect(state.fields['recording_sync_enabled'], false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
