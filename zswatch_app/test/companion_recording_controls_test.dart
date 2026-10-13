import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/companion_recording_database.dart';
import 'package:zswatch_app/data/models/companion_recording.dart';
import 'package:zswatch_app/data/models/voice_memo.dart';
import 'package:zswatch_app/providers/companion_recording_import_providers.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/voice_memo_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/voice_memo/companion_recording_exporter.dart';
import 'package:zswatch_app/ui/screens/voice_memos/companion_voice_memos_view.dart';
import 'package:zswatch_app/ui/screens/voice_memos/retained_voice_memos_view.dart';

const watch = 'FE88C737-593F-DB9B-732D-E11FF4C463F5';
const hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
Map<String, Object?> receipt(
  String name, {
  bool archived = false,
  String state = 'downloaded',
}) => {
  'address': watch,
  'filename': name,
  'timestamp': 1000,
  'size_bytes': 100,
  'duration_ms': 1000,
  'state': state,
  'sha256': hash,
  'local_path': '/private/$name.zsw_opus',
  'archived': archived,
};
String identity(String name) => '$watch:$name:1000:100:1000';
CompanionPrototypeSnapshot snapshot(Map<String, Object?> records) =>
    CompanionPrototypeSnapshot.decode({
      'version': 1,
      'owner': 'ios_companion_native',
      'address': watch,
      'runtime_active': false,
      'protocol_ready': false,
      'generation': 1,
      'event_cursor': 1,
      'phase': 'stopped',
      'events': <Object?>[],
      'recordings': records,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> mount(
    WidgetTester tester,
    CompanionPrototypeSnapshot state,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => Stream.value(state)),
          companionRecordingImportsProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          watchServiceProvider.overrideWith(
            (ref) => throw StateError('Dart BLE must remain closed'),
          ),
          transcriptionEngineProvider.overrideWith(
            (ref) =>
                throw StateError('Opening controls must not start inference'),
          ),
        ],
        child: const MaterialApp(home: CompanionVoiceMemosView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'offline search matches private transcript identities; archive and trash stay separate',
    (tester) async {
      final state = snapshot({
        identity('speech'): receipt('speech'),
        identity('old'): receipt('old', archived: true),
        identity('deleted'): receipt('deleted', state: 'deleted'),
      });
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            expect(call.method, 'searchRecordings');
            expect((call.arguments as Map)['query'], 'shopping');
            return {
              'version': 1,
              'identities': [identity('speech')],
            };
          });
      await mount(tester, state);
      expect(find.text('speech'), findsOneWidget);
      expect(find.text('old'), findsNothing);
      expect(find.text('deleted'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Shopping');
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pumpAndSettle();
      expect(find.text('speech'), findsOneWidget);
      expect(methods, ['searchRecordings']);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await tester.pumpAndSettle();
      expect(find.text('old'), findsOneWidget);
      expect(find.text('speech'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Recently deleted'));
      await tester.pumpAndSettle();
      expect(find.text('deleted'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(methods, ['searchRecordings']);
    },
  );

  testWidgets(
    'batch delete submits only checked local identity and never sends a watch command',
    (tester) async {
      final state = snapshot({
        identity('one'): receipt('one'),
        identity('two'): receipt('two'),
      });
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return state.fields;
          });
      await mount(tester, state);
      await tester.tap(find.byTooltip('Select recordings'));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey(identity('one')));
      await tester.tap(
        find.descendant(of: row, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete selected'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('Delete from phone'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['removeRecordings']);
      expect((calls.single.arguments as Map)['identities'], [identity('one')]);
      expect(find.text('1 selected'), findsNothing);
    },
  );

  test(
    'older receipts decode defaults; deletion cannot claim verified playback',
    () {
      final row = CompanionRecording.decode(identity('one'), receipt('one'));
      expect(row.title, 'one');
      expect(row.archived, false);
      final deleted = CompanionRecording.decode(
        identity('one'),
        receipt('one', state: 'deleted'),
      );
      expect(deleted.hasCommittedReceipt, false);
      expect(
        () => CompanionRecording.decode(identity('one'), {
          ...receipt('one'),
          'archived': 'true',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'export verifies a copy, cleans temporary files, and retains original on share failure',
    () async {
      final directory = Directory(
        await (await Directory.systemTemp.createTemp(
          'voice-export-test-',
        )).resolveSymbolicLinks(),
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/source.ogg');
      await file.writeAsBytes([1, 2, 3]);
      final row = ImportedRecording(
        identity: identity('one'),
        watchId: watch,
        filename: 'one',
        timestampUtc: 1000,
        durationMs: 1000,
        sizeBytes: 100,
        sourcePath: '/private/raw',
        sourceSha256: hash,
        playbackPath: file.path,
        playbackSha256: sha256.convert([1, 2, 3]).toString(),
        converterVersion: 1,
        importedAt: DateTime.now(),
      );
      final exporter = CompanionRecordingExporter(
        temporaryDirectory: () async => directory,
      );
      String? staged;
      await expectLater(
        exporter.audio(row, (copy) async {
          staged = copy.path;
          expect(copy.path, isNot(file.path));
          expect(await copy.readAsBytes(), [1, 2, 3]);
          throw StateError('User closed share sheet');
        }),
        throwsStateError,
      );
      expect(File(staged!).existsSync(), false);
      expect(await file.readAsBytes(), [1, 2, 3]);
      await file.writeAsBytes([4]);
      await expectLater(
        exporter.audio(row, (_) async => fail('Corrupt file shared')),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'earlier notes remain readable without a BLE or inference owner',
    (tester) async {
      final memo = VoiceMemo(
        id: 7,
        filename: 'old_note',
        timestampUtc: DateTime.utc(2025),
        durationMs: 100,
        sizeBytes: 100,
        transcription: 'Previously saved private text',
        summary: 'Earlier saved note',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            retainedVoiceMemosProvider.overrideWith(
              (ref) => Stream.value([memo]),
            ),
            watchServiceProvider.overrideWith(
              (ref) => throw StateError('No BLE for earlier notes'),
            ),
            transcriptionEngineProvider.overrideWith(
              (ref) => throw StateError('No automatic inference'),
            ),
          ],
          child: const MaterialApp(home: RetainedVoiceMemosView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Earlier saved note'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('retained:7')));
      await tester.pumpAndSettle();
      expect(find.text('Previously saved private text'), findsOneWidget);
      expect(find.text('Copy transcript'), findsOneWidget);
      expect(find.text('Export text'), findsOneWidget);
    },
  );
}
