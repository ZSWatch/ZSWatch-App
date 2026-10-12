import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/settings_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/voice_memo/transcription_engine.dart';
import 'package:zswatch_app/ui/widgets/companion_voice_policy_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets(
    'opening settings never processes audio; opt-in captures chosen models',
    (tester) async {
      final fields = <String, Object?>{
        'version': 1,
        'owner': 'android_service_native',
        'runtime_active': true,
        'protocol_ready': true,
        'phase': 'ready',
        'generation': 1,
        'event_cursor': 0,
        'events': <Object?>[],
        'recordings': <String, Object?>{},
        'address': 'AA:BB:CC:DD:EE:FF',
        'desired_running': true,
      };
      final values = StreamController<CompanionPrototypeSnapshot>.broadcast();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        fields['voice_processing_policy'] = Map<Object?, Object?>.from(
          call.arguments as Map,
        );
        values.add(CompanionPrototypeSnapshot.decode(fields));
        return fields;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companionSnapshotProvider.overrideWith((ref) => values.stream),
            watchServiceProvider.overrideWith(
              (ref) => throw StateError('No Dart BLE'),
            ),
            transcriptionEngineTypeProvider.overrideWith(
              (ref) =>
                  TranscriptionEngineTypeNotifier(null)
                    ..setType(TranscriptionEngineType.kbWhisperBase),
            ),
            selectedAiModelIdProvider.overrideWith(
              (ref) => SelectedAiModelIdNotifier(null)..setModelId('qwen'),
            ),
            aiCorrectionEnabledProvider.overrideWith(
              (ref) => AiCorrectionEnabledNotifier(null),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CompanionVoicePolicyTile()),
          ),
        ),
      );
      values.add(CompanionPrototypeSnapshot.decode(fields));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      final automatic = find.widgetWithText(
        SwitchListTile,
        'Automatically process new recordings',
      );
      await tester.tap(automatic);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(automatic).value, true);
      expect(calls.single.method, 'configureVoiceProcessing');
      expect(calls.single.arguments, {
        'version': 1,
        'watch_id': 'AA:BB:CC:DD:EE:FF',
        'enabled': true,
        'transcription_model': 'kbWhisperBase',
        'analysis_model': 'qwen',
        'correct_transcription': false,
        'analysis_enabled': true,
      });
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Analyze after transcription'),
      );
      await tester.pumpAndSettle();
      expect((calls.last.arguments as Map)['analysis_enabled'], false);
      expect((calls.last.arguments as Map)['enabled'], true);
      await tester.tap(automatic);
      await tester.pumpAndSettle();
      expect(calls.map((call) => (call.arguments as Map)['enabled']), [
        true,
        true,
        false,
      ]);
      expect(tester.widget<SwitchListTile>(automatic).value, false);
      await tester.pumpWidget(const SizedBox());
      await values.close();
    },
  );
}
