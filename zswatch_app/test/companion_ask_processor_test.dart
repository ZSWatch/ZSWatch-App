import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zswatch_app/data/models/companion_recording.dart';
import 'package:zswatch_app/services/ai/companion_ask_processor.dart';
import 'package:zswatch_app/services/ai/companion_voice_processor.dart';
import 'package:zswatch_app/services/ai/openrouter_client.dart';

import 'support/companion_recording_fixture.dart';

http.Response _reply(String text, [int status = 200]) => http.Response(
  jsonEncode(
    status == 200
        ? {
            'choices': [
              {
                'message': {'role': 'assistant', 'content': text},
              },
            ],
          }
        : {
            'error': {'code': status, 'message': text},
          },
  ),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recording names select the question kind', () {
    expect(askKindOf('ask_20261022_001349'), AskKind.question);
    expect(askKindOf('askr_20261022_001349'), AskKind.reply);
    expect(askKindOf('20261022_001349'), isNull);
    expect(askKindOf('REC_004'), isNull);
  });

  group('AskConversationStore', () {
    late Directory root;
    late AskConversationStore store;
    final start = DateTime.utc(2026, 10, 22, 2);
    final messages = [
      {'role': 'user', 'content': 'q'},
      {'role': 'assistant', 'content': 'a'},
    ];

    setUp(() async {
      root = await Directory.systemTemp.createTemp('ask-store-');
      store = AskConversationStore(File('${root.path}/c.json'));
    });
    tearDown(() => root.delete(recursive: true));

    test('a question continues only within a minute', () async {
      await store.save('W', messages, start);
      final soon = start.add(const Duration(seconds: 50));
      final late = start.add(const Duration(seconds: 70));
      expect(await store.load('W', AskKind.question, soon), messages);
      expect(await store.load('W', AskKind.question, late), isEmpty);
      expect(await store.load('W', AskKind.reply, late), messages);
      expect(await store.load('other', AskKind.reply, soon), isEmpty);
    });

    test('keeps only the latest messages', () async {
      await store.save('W', [
        for (var i = 0; i < 20; i++) {'role': 'user', 'content': '$i'},
      ], start);
      final kept = await store.load('W', AskKind.reply, start);
      expect(kept.length, AskConversationStore.maxMessages);
      expect(kept.last['content'], '19');
    });
  });

  group('voice processor', () {
    late Directory root;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('ask-voice-');
      messenger.setMockMethodCallHandler(paths, (call) async => root.path);
    });
    tearDown(() async {
      messenger.setMockMethodCallHandler(paths, null);
      await root.delete(recursive: true);
    });

    Map<String, Object?> request(
      CompanionRecording recording, {
      bool cloud = true,
      String? key = 'sk-or-v1-test',
    }) => {
      'version': 1,
      'spec': {
        'provider': 'dart-voice-v1',
        'backend': cloud ? 'openrouter' : 'local',
        'upload_authorized': cloud,
        'pipeline_revision': 'voice-v1',
        'recording_id': recording.identity,
        'input_sha256': recording.sha256,
        'watch_id': recording.watchId,
        'model': cloud
            ? 'openrouter:google/stt|openrouter:google/llm|false'
            : 'whisperTinyEn|qwen|false',
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

    /// Replies to transcription with [spoken] and to chat with [answer].
    OpenRouterClient Function(String) fake(
      String spoken,
      String Function(List<Object?> messages) answer, {
      List<List<Object?>>? chats,
    }) =>
        (key) => OpenRouterClient(
          key,
          client: MockClient((http) async {
            final messages =
                (jsonDecode(http.body) as Map<String, Object?>)['messages']!
                    as List;
            final first = messages.first as Map;
            if (first['content'] is List) return _reply(spoken);
            chats?.add(messages);
            return _reply(answer(messages));
          }),
        );

    test('a question recording is answered with its history', () async {
      final chats = <List<Object?>>[];
      final first = await seedCompanionRecording(
        root,
        filename: 'ask_20261022_001349',
      );
      final result = await processCompanionVoiceRecording(
        request(first),
        saveTranscript: (_) async {},
        cloudFactory: fake('Hur högt är Kebnekaise?', (_) => '2 097 meter.'),
      );
      expect(result['category'], askAiCategory);
      expect(result['summary'], '2 097 meter.');
      expect(result['transcript'], 'Hur högt är Kebnekaise?');

      final reply = await seedCompanionRecording(
        root,
        filename: 'askr_20261022_001410',
      );
      await processCompanionVoiceRecording(
        request(reply),
        saveTranscript: (_) async {},
        cloudFactory: fake(
          'Och Mont Blanc?',
          (_) => 'Cirka 4 806 meter.',
          chats: chats,
        ),
      );
      final sent = chats.single;
      expect(sent.length, 4); // system + earlier question/answer + reply
      expect((sent[1] as Map)['content'], 'Hur högt är Kebnekaise?');
      expect((sent[3] as Map)['content'], 'Och Mont Blanc?');
    });

    test('without OpenRouter a question explains the setup', () async {
      final recording = await seedCompanionRecording(
        root,
        filename: 'ask_20261022_001349',
      );
      final result = await processCompanionVoiceRecording(
        request(recording, cloud: false, key: null),
        saveTranscript: (_) async => fail('Nothing to transcribe'),
        cloudFactory: (_) => fail('No client without OpenRouter'),
      );
      expect(result['category'], askAiCategory);
      expect(result['summary'], contains('OpenRouter'));
    });

    test('provider failures still answer the watch', () async {
      final recording = await seedCompanionRecording(
        root,
        filename: 'ask_20261022_001349',
      );
      final result = await processCompanionVoiceRecording(
        request(recording),
        saveTranscript: (_) async => fail('Transcription failed'),
        cloudFactory: (key) => OpenRouterClient(
          key,
          client: MockClient((_) async => _reply('No credit', 402)),
        ),
      );
      expect(result['summary'], 'OpenRouter is out of credits.');
    });

    test('a memo that is a question is answered instead of saved', () async {
      final recording = await seedCompanionRecording(root);
      final result = await processCompanionVoiceRecording(
        request(recording),
        saveTranscript: (_) async {},
        cloudFactory: fake(
          'Vad är klockan i Tokyo?',
          (messages) => (messages.first as Map)['role'] == 'system'
              ? 'Klockan är 10:00 i Tokyo.'
              : fail('Not analysed as a memo'),
        ),
      );
      expect(result['category'], askAiCategory);
      expect(result['summary'], 'Klockan är 10:00 i Tokyo.');
      expect(result['actions'], isEmpty);
    });
  });
}
