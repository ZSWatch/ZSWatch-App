import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/ai_providers.dart';
import 'package:zswatch_app/providers/openrouter_providers.dart';
import 'package:zswatch_app/providers/settings_providers.dart';
import 'package:zswatch_app/providers/voice_memo_providers.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/voice_memo/transcription_engine.dart';
import 'package:zswatch_app/ui/widgets/companion_voice_policy_tile.dart';

final _onDevice = onDeviceProcessingProvider.overrideWith(
  (ref) => PrefBoolNotifier(null, SettingsKeys.onDeviceProcessing, true),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final selected in [false, true]) {
    testWidgets(
      'voice options save ${selected ? 'while disconnected' : 'before pairing'}',
      (tester) async {
        final ios = defaultTargetPlatform == TargetPlatform.iOS;
        final address = selected
            ? (ios
                  ? 'FE88C737-593F-DB9B-732D-E11FF4C463F5'
                  : 'AA:BB:CC:DD:EE:FF')
            : '';
        final fields = <String, Object?>{
          'version': 1,
          'owner': ios ? 'ios_companion_native' : 'android_service_native',
          'runtime_active': false,
          'protocol_ready': false,
          'phase': 'stopped',
          'generation': 1,
          'event_cursor': 0,
          'events': <Object?>[],
          'recordings': <String, Object?>{},
          'address': address,
          'desired_running': false,
        };
        final values = StreamController<CompanionPrototypeSnapshot>.broadcast();
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'cloudCredential') {
            return {'version': 1, 'key': 'fixture-key'};
          }
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
              onDeviceProcessingProvider.overrideWith(
                (ref) => PrefBoolNotifier(null, 'mode', false),
              ),
              openRouterSttModelProvider.overrideWith(
                (ref) => PrefStringNotifier(null, 'stt', 'google/stt'),
              ),
              openRouterAnalysisModelProvider.overrideWith(
                (ref) => PrefStringNotifier(null, 'llm', 'google/llm'),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: CompanionVoicePolicyTile()),
            ),
          ),
        );
        values.add(CompanionPrototypeSnapshot.decode(fields));
        await tester.pumpAndSettle();
        final automatic = find.widgetWithText(
          SwitchListTile,
          'Automatically process new recordings',
        );
        final analysis = find.widgetWithText(
          SwitchListTile,
          'Analyze after transcription',
        );
        expect(tester.widget<SwitchListTile>(automatic).onChanged, isNotNull);
        expect(tester.widget<SwitchListTile>(analysis).onChanged, isNotNull);
        expect(calls, isEmpty);
        await tester.tap(automatic);
        await tester.pumpAndSettle();
        expect((calls.last.arguments as Map)['watch_id'], address);
        expect((calls.last.arguments as Map)['enabled'], true);
        expect(tester.widget<SwitchListTile>(automatic).value, true);
        await tester.tap(analysis);
        await tester.pumpAndSettle();
        expect((calls.last.arguments as Map)['analysis_enabled'], false);
        expect((calls.last.arguments as Map)['enabled'], true);
        expect(
          calls.every(
            (call) => [
              'cloudCredential',
              'configureVoiceProcessing',
            ].contains(call.method),
          ),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox());
        await values.close();
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

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
            _onDevice,
            companionSnapshotProvider.overrideWith((ref) => values.stream),

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
            transcriptionModelStatusProvider.overrideWith(
              (ref, type) async => const TranscriptionModelLocalStatus(
                downloaded: true,
                localSizeBytes: 1,
                localPath: '/owned/model.bin',
              ),
            ),
            llmModelDownloadedProvider.overrideWith((ref) async => true),
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

  testWidgets(
    'automatic opt-in requires downloaded models; transcription-only does not need an LLM',
    (tester) async {
      for (final flags in [
        (false, true, true),
        (true, false, true),
        (true, false, false),
      ]) {
        final calls = <MethodCall>[];
        final fields = <String, Object?>{
          'version': 1,
          'owner': 'ios_companion_native',
          'platform': 'ios',
          'runtime_active': true,
          'protocol_ready': true,
          'phase': 'ready',
          'generation': 1,
          'event_cursor': 0,
          'events': <Object?>[],
          'recordings': <String, Object?>{},
          'address': 'FE88C737-593F-DB9B-732D-E11FF4C463F5',
          'desired_running': true,
          'voice_processing_policy': {'analysis_enabled': flags.$3},
        };
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return fields;
        });
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(flags),
            overrides: [
              _onDevice,
              companionSnapshotProvider.overrideWith(
                (ref) =>
                    Stream.value(CompanionPrototypeSnapshot.decode(fields)),
              ),
              transcriptionEngineTypeProvider.overrideWith(
                (ref) => TranscriptionEngineTypeNotifier(null),
              ),
              selectedAiModelIdProvider.overrideWith(
                (ref) => SelectedAiModelIdNotifier(null),
              ),
              aiCorrectionEnabledProvider.overrideWith(
                (ref) => AiCorrectionEnabledNotifier(null),
              ),
              transcriptionModelStatusProvider.overrideWith(
                (ref, type) async => TranscriptionModelLocalStatus(
                  downloaded: flags.$1,
                  localSizeBytes: null,
                  localPath: '/owned/model.bin',
                ),
              ),
              llmModelDownloadedProvider.overrideWith((ref) async => flags.$2),
            ],
            child: const MaterialApp(
              home: Scaffold(body: CompanionVoicePolicyTile()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        await tester.tap(
          find.widgetWithText(
            SwitchListTile,
            'Automatically process new recordings',
          ),
        );
        await tester.pumpAndSettle();
        if (!flags.$1 || (flags.$3 && !flags.$2)) {
          expect(calls, isEmpty);
          expect(find.text('Download models'), findsOneWidget);
          expect(
            find.textContaining(
              flags.$1 ? 'selected analysis model' : 'selected speech model',
            ),
            findsOneWidget,
          );
        } else {
          expect(calls.single.method, 'configureVoiceProcessing');
          expect((calls.single.arguments as Map)['analysis_enabled'], false);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('iOS on-device only transcribes and never needs an LLM', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <MethodCall>[];
    final fields = <String, Object?>{
      'version': 1,
      'owner': 'ios_companion_native',
      'platform': 'ios',
      'runtime_active': true,
      'protocol_ready': true,
      'phase': 'ready',
      'generation': 1,
      'event_cursor': 0,
      'events': <Object?>[],
      'recordings': <String, Object?>{},
      'address': 'FE88C737-593F-DB9B-732D-E11FF4C463F5',
      'desired_running': true,
      'voice_processing_policy': {'analysis_enabled': true},
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return fields;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _onDevice,
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(CompanionPrototypeSnapshot.decode(fields)),
          ),
          transcriptionEngineTypeProvider.overrideWith(
            (ref) => TranscriptionEngineTypeNotifier(null),
          ),
          selectedAiModelIdProvider.overrideWith(
            (ref) => SelectedAiModelIdNotifier(null),
          ),
          aiCorrectionEnabledProvider.overrideWith(
            (ref) => AiCorrectionEnabledNotifier(null),
          ),
          transcriptionModelStatusProvider.overrideWith(
            (ref, type) async => const TranscriptionModelLocalStatus(
              downloaded: true,
              localSizeBytes: null,
              localPath: '/owned/model.bin',
            ),
          ),
          llmModelDownloadedProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CompanionVoicePolicyTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Analyze after transcription'), findsNothing);
    await tester.tap(
      find.widgetWithText(
        SwitchListTile,
        'Automatically process new recordings',
      ),
    );
    await tester.pumpAndSettle();
    expect((calls.single.arguments as Map)['analysis_enabled'], false);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('OpenRouter by default: needs a key, then analyzes on iOS', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    for (final key in [null, 'sk-or-v1-test']) {
      final calls = <MethodCall>[];
      final fields = <String, Object?>{
        'version': 1,
        'owner': 'ios_companion_native',
        'platform': 'ios',
        'runtime_active': true,
        'protocol_ready': true,
        'phase': 'ready',
        'generation': 1,
        'event_cursor': 0,
        'events': <Object?>[],
        'recordings': <String, Object?>{},
        'address': 'FE88C737-593F-DB9B-732D-E11FF4C463F5',
        'desired_running': true,
      };
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'cloudCredential') {
          return {'version': 1, 'key': key};
        }
        return fields;
      });
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(key),
          overrides: [
            companionSnapshotProvider.overrideWith(
              (ref) => Stream.value(CompanionPrototypeSnapshot.decode(fields)),
            ),
            onDeviceProcessingProvider.overrideWith(
              (ref) => PrefBoolNotifier(
                null,
                SettingsKeys.onDeviceProcessing,
                false,
              ),
            ),
            openRouterSttModelProvider.overrideWith(
              (ref) => PrefStringNotifier(null, 'stt', 'google/stt'),
            ),
            openRouterAnalysisModelProvider.overrideWith(
              (ref) => PrefStringNotifier(null, 'llm', 'google/llm'),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CompanionVoicePolicyTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('Analyze after transcription'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(
          SwitchListTile,
          'Automatically process new recordings',
        ),
      );
      await tester.pumpAndSettle();
      if (key == null) {
        expect(calls.map((c) => c.method), ['cloudCredential']);
        expect(find.text('Add key'), findsOneWidget);
      } else {
        expect(calls.last.method, 'configureVoiceProcessing');
        expect(calls.last.arguments, {
          'version': 1,
          'watch_id': 'FE88C737-593F-DB9B-732D-E11FF4C463F5',
          'enabled': true,
          'transcription_model': 'openrouter:google/stt',
          'analysis_model': 'openrouter:google/llm',
          'correct_transcription': false,
          'analysis_enabled': true,
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
