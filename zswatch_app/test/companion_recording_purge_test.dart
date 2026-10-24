import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_recording.dart';
import 'package:zswatch_app/providers/companion_recording_import_providers.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/voice_memo_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/voice_memos/companion_voice_memos_view.dart';

import 'companion_recording_controls_test.dart'
    show receipt, identity, snapshot;

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
    'permanent deletion requires confirmation and keeps cleanup failures visible',
    (tester) async {
      final state = snapshot({
        identity('trash'): receipt('trash', state: 'deleted'),
        identity('pending'): {
          ...receipt('pending', state: 'deleted'),
          'purged': true,
          'purge_pending': true,
        },
        identity('gone'): {
          ...receipt('gone', state: 'deleted'),
          'purged': true,
          'purge_pending': false,
        },
      });
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return state.fields;
          });
      await mount(tester, state);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Deleted'));
      await tester.pumpAndSettle();
      expect(find.text('gone'), findsNothing);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.textContaining('Deletion awaiting cleanup'), findsOneWidget);
      expect(find.byTooltip('Retry permanent deletion'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete permanently from phone'));
      await tester.pumpAndSettle();
      expect(find.text('Delete permanently from phone?'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.byTooltip('Delete permanently from phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['purgeRecordings']);
      expect((calls.single.arguments as Map)['identities'], [
        identity('trash'),
      ]);
    },
  );
  test(
    'purge flags cannot claim a downloaded receipt or unrequested cleanup',
    () {
      expect(
        () => CompanionRecording.decode(identity('one'), {
          ...receipt('one'),
          'purged': true,
        }),
        throwsFormatException,
      );
      expect(
        () => CompanionRecording.decode(identity('one'), {
          ...receipt('one', state: 'deleted'),
          'purge_pending': true,
        }),
        throwsFormatException,
      );
    },
  );
}
