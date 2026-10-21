import 'dart:convert';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zswatch_app/data/models/companion_recording.dart';
import 'package:zswatch_app/services/ai/companion_voice_processor.dart';
import 'package:zswatch_app/services/ai/openrouter_client.dart';

import 'support/companion_recording_fixture.dart';

http.Response _json(Object body, [int status = 200, Map<String, String>? h]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...?h},
    );

Map<String, Object?> _reply(String text) => {
  'choices': [
    {
      'message': {'role': 'assistant', 'content': text},
    },
  ],
  'usage': {'cost': 0.0001},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenRouterClient', () {
    test('transcribes Ogg Opus with zero-retention routing', () async {
      late Map<String, Object?> sent;
      late Map<String, String> headers;
      final client = OpenRouterClient(
        'sk-or-v1-test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/chat/completions');
          headers = request.headers;
          sent = jsonDecode(request.body) as Map<String, Object?>;
          return _json(_reply(' Sätt en timer på 10 minuter. '));
        }),
      );
      final text = await client.transcribe(
        'google/gemini-3.1-flash-lite',
        Uint8List.fromList(utf8.encode('OggS')),
      );
      expect(text, 'Sätt en timer på 10 minuter.');
      expect(headers['Authorization'], 'Bearer sk-or-v1-test');
      expect(sent['provider'], {'zdr': true, 'data_collection': 'deny'});
      final content =
          ((sent['messages']! as List).single as Map)['content'] as List;
      final audio = (content[1] as Map)['input_audio'] as Map;
      expect(audio['format'], 'ogg');
      expect(base64Decode(audio['data'] as String), utf8.encode('OggS'));
      expect(client.totalCost, closeTo(0.0001, 1e-9));
    });

    test('maps HTTP failures to what the scheduler does', () async {
      Future<OpenRouterFailureKind> kind(http.Response response) async {
        final client = OpenRouterClient(
          'k',
          client: MockClient((_) async => response),
        );
        try {
          await client.analyze('m', 'p');
        } on OpenRouterFailure catch (e) {
          return e.kind;
        }
        fail('No failure');
      }

      Map<String, Object?> error(int code, [String message = 'x']) => {
        'error': {'code': code, 'message': message},
      };
      expect(await kind(_json(error(401), 401)), OpenRouterFailureKind.auth);
      expect(await kind(_json(error(402), 402)), OpenRouterFailureKind.credits);
      expect(
        await kind(_json(error(402), 402, {'retry-after': '5'})),
        OpenRouterFailureKind.retry,
      );
      expect(await kind(_json(error(403), 403)), OpenRouterFailureKind.auth);
      expect(
        await kind(_json(error(403, 'flagged by moderation'), 403)),
        OpenRouterFailureKind.rejected,
      );
      expect(await kind(_json(error(429), 429)), OpenRouterFailureKind.retry);
      expect(await kind(_json(error(503), 503)), OpenRouterFailureKind.retry);
      expect(
        await kind(_json(error(400), 400)),
        OpenRouterFailureKind.rejected,
      );
      // Mid-request failures arrive in a 200 body.
      expect(await kind(_json(error(502))), OpenRouterFailureKind.retry);
      expect(
        await kind(http.Response('<html>', 502)),
        OpenRouterFailureKind.retry,
      );
      final offline = OpenRouterClient(
        'k',
        client: MockClient((_) => throw const SocketException('down')),
      );
      await expectLater(
        offline.analyze('m', 'p'),
        throwsA(
          isA<OpenRouterFailure>().having(
            (e) => e.kind,
            'kind',
            OpenRouterFailureKind.retry,
          ),
        ),
      );
    });

    test('reads key usage and limit', () async {
      final client = OpenRouterClient(
        'k',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/key');
          return _json({
            'data': {
              'label': 'sk-or-v1-abc...',
              'usage': 0.12,
              'usage_monthly': 0.03,
              'limit': 5,
              'limit_remaining': 4.88,
            },
          });
        }),
      );
      final info = await client.keyInfo();
      expect(info.usageMonthly, 0.03);
      expect(info.limit, 5);
      expect(info.limitRemaining, 4.88);
    });

    test('model list marks zero-retention models', () async {
      final models = await OpenRouterClient.fetchModels(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/endpoints/zdr')) {
            return _json({
              'data': [
                {'model_id': 'google/a'},
              ],
            });
          }
          return _json({
            'data': [
              {
                'id': 'google/a',
                'name': 'A',
                'pricing': {
                  'prompt': '0.00000025',
                  'completion': '0.0000015',
                  'audio': '0.0000005',
                },
                'architecture': {
                  'input_modalities': ['text', 'audio'],
                },
              },
              {
                'id': 'other/b',
                'name': 'B',
                'pricing': {'prompt': '0.0000001', 'completion': '0.0000004'},
                'architecture': {
                  'input_modalities': ['text'],
                },
              },
            ],
          });
        }),
      );
      expect(models.map((m) => (m.id, m.zdr, m.acceptsAudio)), [
        ('google/a', true, true),
        ('other/b', false, false),
      ]);
      expect(models.first.analysisCostPerMemo, closeTo(0.0006, 1e-6));
    });
  });

  group('cloud voice job', () {
    late Directory root;
    late CompanionRecording recording;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('voice-cloud-');
      recording = await seedCompanionRecording(root);
      messenger.setMockMethodCallHandler(paths, (call) async {
        if (call.method == 'getApplicationSupportDirectory') return root.path;
        if (call.method == 'getTemporaryDirectory') return root.path;
        throw StateError('Unexpected ${call.method}');
      });
    });
    tearDown(() async {
      messenger.setMockMethodCallHandler(paths, null);
      await root.delete(recursive: true);
    });

    Map<String, Object?> request({String? key = 'sk-or-v1-test'}) => {
      'version': 1,
      'spec': {
        'provider': 'dart-voice-v1',
        'backend': 'openrouter',
        'upload_authorized': true,
        'pipeline_revision': 'voice-v1',
        'recording_id': recording.identity,
        'input_sha256': recording.sha256,
        'watch_id': recording.watchId,
        'model': 'openrouter:google/stt|openrouter:google/llm|false',
      },
      'recording': {
        'address': recording.watchId,
        'filename': recording.filename,
        'timestamp': recording.timestampUtc.millisecondsSinceEpoch ~/ 1000,
        'duration_ms': recording.durationMs,
        'size_bytes': recording.sizeBytes,
        'state': 'downloaded',
        'local_path': recording.localPath,
        'sha256': recording.sha256,
      },
      if (key != null) 'credentials': {'openrouter_key': key},
    };

    test('transcribes and analyzes through OpenRouter', () async {
      final models = <String>[];
      final saved = <String>[];
      final result = await processCompanionVoiceRecording(
        request(),
        saveTranscript: (t) async => saved.add(t),
        cloudFactory: (key) {
          expect(key, 'sk-or-v1-test');
          return OpenRouterClient(
            key,
            client: MockClient((http) async {
              final body = jsonDecode(http.body) as Map<String, Object?>;
              models.add(body['model']! as String);
              final messages = body['messages']! as List;
              if ((messages.first as Map)['role'] == 'system') {
                return _json(_reply('MEMO'));
              }
              final message = messages.single as Map;
              if (message['content'] is List) {
                final audio =
                    ((message['content'] as List)[1] as Map)['input_audio']
                        as Map;
                // The watch's Opus is sent as Ogg Opus, not re-encoded.
                expect(
                  base64Decode(audio['data'] as String).take(4),
                  utf8.encode('OggS'),
                );
                return _json(_reply('Starta en timer på tio minuter'));
              }
              expect(message['content'], isNot(contains('/no_think')));
              return _json(
                _reply(
                  jsonEncode([
                    {
                      'intent': 'timer',
                      'title': 'Timer',
                      'datetime_expression_original': 'tio minuter',
                      'datetime_expression_english': '10 minutes',
                    },
                  ]),
                ),
              );
            }),
          );
        },
      );
      expect(models, ['google/stt', 'google/llm', 'google/llm']);
      expect(saved, ['Starta en timer på tio minuter']);
      final action = (result['actions']! as List).single as Map;
      expect(action['type'], 'timer');
      expect(action['duration_seconds'], 600);
    });

    test('a missing key blocks before any upload', () async {
      await expectLater(
        processCompanionVoiceRecording(
          request(key: null),
          saveTranscript: (_) async => fail('No transcript without a key'),
          cloudFactory: (_) => fail('No client without a key'),
        ),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'CLOUD_AUTH'),
        ),
      );
    });

    test('provider failures surface as scheduler codes', () async {
      for (final (status, code) in [
        (401, 'CLOUD_AUTH'),
        (402, 'CLOUD_CREDITS'),
        (503, 'CLOUD_RETRY'),
        (400, 'CLOUD_REJECTED'),
      ]) {
        await expectLater(
          processCompanionVoiceRecording(
            request(),
            saveTranscript: (_) async => fail('Nothing to save'),
            cloudFactory: (key) => OpenRouterClient(
              key,
              client: MockClient(
                (_) async => _json({
                  'error': {'code': status, 'message': 'x'},
                }, status),
              ),
            ),
          ),
          throwsA(isA<PlatformException>().having((e) => e.code, 'code', code)),
        );
      }
    });

    test('cloud models require recorded upload consent', () async {
      final spec = Map<String, Object?>.from(request()['spec']! as Map);
      for (final changed in [
        {...spec, 'upload_authorized': false},
        {...spec, 'backend': 'local'},
        {...spec, 'model': 'whisperTinyEn|qwen|false'},
      ]) {
        await expectLater(
          processCompanionVoiceRecording(
            {...request(), 'spec': changed},
            saveTranscript: (_) async {},
            cloudFactory: (_) => fail('Rejected before any client'),
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });

  test('analysis request strips the local /no_think suffix', () {
    final body = OpenRouterRequest.analysis(
      'm',
      'Memo:\nhi\n\n/no_think\nJSON:',
    );
    expect(
      ((body['messages']! as List).single as Map)['content'],
      'Memo:\nhi\n\nJSON:',
    );
  });
}
