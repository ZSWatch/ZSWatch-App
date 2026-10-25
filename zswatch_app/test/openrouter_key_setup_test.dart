import 'dart:convert';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zswatch_app/providers/openrouter_providers.dart';
import 'package:zswatch_app/providers/settings_providers.dart';
import 'package:zswatch_app/services/ai/openrouter_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<ProviderContainer> setup({
    String address = '',
    int statusCode = 200,
    bool failPolicy = false,
    required List<MethodCall> calls,
  }) async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.openRouterSttModel: 'chosen/speech',
      SettingsKeys.openRouterAnalysisModel: 'chosen/analysis',
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'cloudCredential') {
        return {'version': 1, 'key': 'previous-fixture-key'};
      }
      if (call.method == 'setCloudCredential') return null;
      if (call.method == 'configureVoiceProcessing' && failPolicy) {
        throw PlatformException(code: 'fixture-policy-failure');
      }
      return {
        'version': 1,
        'owner': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios_companion_native'
            : 'android_service_native',
        'runtime_active': false,
        'protocol_ready': false,
        'phase': 'stopped',
        'generation': 1,
        'event_cursor': 1,
        'events': <Object?>[],
        'recordings': <String, Object?>{},
        'address': address,
        'desired_running': false,
      };
    });
    final container = ProviderContainer(
      overrides: [
        openRouterClientFactoryProvider.overrideWithValue(
          (key) => OpenRouterClient(
            key,
            client: MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer fixture-key');
              return http.Response(
                jsonEncode({
                  'data': {'label': 'fixture', 'usage': 0},
                  'error': {'message': 'rejected'},
                }),
                statusCode,
              );
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedPreferencesProvider.future);
    container.read(openRouterKeyProvider);
    await Future<void>.value();
    return container;
  }

  for (final selected in [false, true]) {
    testWidgets(
      'saving a verified key enables both voice options ${selected ? 'for selected watch' : 'before pairing'}',
      (tester) async {
        final address = !selected
            ? ''
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'FE88C737-593F-DB9B-732D-E11FF4C463F5'
            : 'AA:BB:CC:DD:EE:FF';
        final calls = <MethodCall>[];
        final container = await setup(address: address, calls: calls);
        expect(calls.map((call) => call.method), ['cloudCredential']);
        await container
            .read(openRouterKeyProvider.notifier)
            .save('  fixture-key  ');
        expect(calls.map((call) => call.method), [
          'cloudCredential',
          'setCloudCredential',
          'snapshot',
          'configureVoiceProcessing',
        ]);
        expect(calls.last.arguments, {
          'version': 1,
          'watch_id': address,
          'enabled': true,
          'analysis_enabled': true,
          'transcription_model': 'openrouter:chosen/speech',
          'analysis_model': 'openrouter:chosen/analysis',
          'correct_transcription': false,
        });
        expect(
          container.read(openRouterKeyProvider).valueOrNull,
          'fixture-key',
        );
        // Reading the saved key again must not turn explicitly disabled options on.
        container.invalidate(openRouterKeyProvider);
        container.read(openRouterKeyProvider);
        await tester.pump(const Duration(milliseconds: 1));
        expect(calls.last.method, 'cloudCredential');
        expect(
          calls.where((call) => call.method == 'configureVoiceProcessing'),
          hasLength(1),
        );
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  test('rejected key changes neither credentials nor voice options', () async {
    final calls = <MethodCall>[];
    final container = await setup(statusCode: 401, calls: calls);
    await expectLater(
      container.read(openRouterKeyProvider.notifier).save('fixture-key'),
      throwsA(isA<OpenRouterFailure>()),
    );
    expect(calls.map((call) => call.method), ['cloudCredential']);
    expect(
      container.read(openRouterKeyProvider).valueOrNull,
      'previous-fixture-key',
    );
  });

  test(
    'failed policy save reports that automatic setup is incomplete',
    () async {
      final calls = <MethodCall>[];
      final container = await setup(failPolicy: true, calls: calls);
      await expectLater(
        container.read(openRouterKeyProvider.notifier).save('fixture-key'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('automatic voice processing could not be enabled'),
          ),
        ),
      );
    },
  );
}
