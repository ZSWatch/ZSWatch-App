import 'dart:convert';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../data/models/companion_recording.dart';
import '../voice_memo/ogg_opus_writer.dart';
import '../voice_memo/transcription_engine.dart';
import '../voice_memo/verified_companion_recording.dart';
import 'companion_voice_processor.dart';
import 'openrouter_client.dart';

/// The watch's Chat app names recordings `chat_...` for a new question and
/// `chatr_...` for a reply to the answer it shows.
enum ChatKind { question, reply }

ChatKind? chatKindOf(String filename) {
  if (filename.startsWith('chatr_')) return ChatKind.reply;
  if (filename.startsWith('chat_')) return ChatKind.question;
  return null;
}

/// Category the native owners use to send the result as an Chat answer.
const chatCategory = 'chat';

/// Keeps one conversation per phone. A new question continues it only shortly
/// after the last answer; a reply continues it for longer.
class ChatConversationStore {
  ChatConversationStore(this.file);

  static const questionWindow = Duration(minutes: 1);
  static const replyWindow = Duration(minutes: 10);
  static const maxMessages = 12;

  final File file;

  Future<List<Map<String, String>>> load(
    String watchId,
    ChatKind kind,
    DateTime now,
  ) async {
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! Map || value['watch_id'] != watchId) return [];
      final updated = DateTime.fromMillisecondsSinceEpoch(
        value['updated_ms'] as int,
      );
      final window = kind == ChatKind.reply ? replyWindow : questionWindow;
      if (now.difference(updated) > window) return [];
      return [
        for (final m in value['messages'] as List)
          {
            'role': (m as Map)['role'] as String,
            'content': m['content'] as String,
          },
      ];
    } on Object {
      return [];
    }
  }

  Future<void> save(
    String watchId,
    List<Map<String, String>> messages,
    DateTime now,
  ) async {
    final kept = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    await file.writeAsString(
      jsonEncode({
        'watch_id': watchId,
        'updated_ms': now.millisecondsSinceEpoch,
        'messages': kept,
      }),
      flush: true,
    );
  }
}

/// Answers a question recording. Failures become a short answer for the watch
/// instead of a failed job, since a late retry of a question is useless.
Future<Map<String, Object?>> answerCompanionQuestion({
  required CompanionRecording recording,
  required ChatKind kind,
  required List<String> models,
  required OpenRouterClient? client,
  required Directory support,
  required Future<void> Function(String transcript) saveTranscript,
  required CompanionVoiceCancellation control,
  DateTime Function() clock = DateTime.now,
}) async {
  Map<String, Object?> result(String question, String answer) => {
    'version': 1,
    'transcript': question,
    'summary': answer,
    'category': chatCategory,
    'actions': <Object?>[],
  };
  if (client == null) {
    return result(
      '',
      'Chat needs OpenRouter. Add an OpenRouter API key in the ZSWatch app.',
    );
  }
  TranscriptionEngine? engine;
  control.bind(() async {
    client.close();
    await engine?.cancel();
  });
  try {
    return await _answer(
      recording,
      kind,
      models,
      client,
      support,
      saveTranscript,
      control,
      clock,
      result,
      (e) => engine = e,
    );
  } finally {
    control.unbind();
  }
}

Future<Map<String, Object?>> _answer(
  CompanionRecording recording,
  ChatKind kind,
  List<String> models,
  OpenRouterClient client,
  Directory support,
  Future<void> Function(String transcript) saveTranscript,
  CompanionVoiceCancellation control,
  DateTime Function() clock,
  Map<String, Object?> Function(String, String) result,
  void Function(TranscriptionEngine) onEngine,
) async {
  String question;
  try {
    question = await _transcribe(
      recording,
      models[0],
      client,
      support,
      control,
      onEngine,
    );
    requireCompanionSpeech(question);
    await saveTranscript(question);
  } on PlatformException catch (e) {
    control.check();
    return result('', switch (e.code) {
      'NO_SPEECH' => "I didn't catch that. Try again.",
      'MODEL_MISSING' => 'The speech model is not downloaded on the phone.',
      _ => 'Transcription failed. Try again.',
    });
  } on OpenRouterFailure catch (e) {
    control.check();
    return result('', _failureText(e));
  }
  control.check();
  final store = ChatConversationStore(
    File(p.join(support.path, chatConversationFile)),
  );
  final now = clock();
  final history = await store.load(recording.watchId, kind, now);
  final messages = [
    ...history,
    {'role': 'user', 'content': question},
  ];
  final model = isOpenRouterModel(models[1])
      ? openRouterModelId(models[1])
      : OpenRouterRequest.defaultAnalysisModel;
  String answer;
  try {
    answer = await client.chat(
      model,
      OpenRouterRequest.chatPrompt(now),
      messages,
    );
  } on OpenRouterFailure catch (e) {
    control.check();
    return result(question, _failureText(e));
  }
  control.check();
  if (answer.isEmpty) return result(question, 'No answer. Try again.');
  await store.save(recording.watchId, [
    ...messages,
    {'role': 'assistant', 'content': answer},
  ], clock());
  debugPrint(
    '[CompanionChat] answered ${kind.name} with ${history.length} earlier messages',
  );
  return result(question, answer);
}

/// For an ordinary memo: answers it like a new question when the model judges
/// it to be one, else returns null and the memo is analysed as usual.
Future<String?> answerIfQuestion({
  required String transcript,
  required String watchId,
  required String model,
  required OpenRouterClient client,
  required Directory support,
  DateTime Function() clock = DateTime.now,
}) async {
  final now = clock();
  final messages = [
    {'role': 'user', 'content': transcript},
  ];
  String answer;
  try {
    answer = await client.chat(
      model,
      OpenRouterRequest.routePrompt(now),
      messages,
    );
  } on OpenRouterFailure catch (e) {
    debugPrint('[CompanionChat] routing failed, keeping memo: ${e.kind.name}');
    return null;
  }
  final cleaned = answer.trim();
  if (cleaned.isEmpty ||
      cleaned.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '') ==
          OpenRouterRequest.memoMarker) {
    return null;
  }
  // Start a conversation so the watch's Reply can follow up.
  await ChatConversationStore(
    File(p.join(support.path, chatConversationFile)),
  ).save(watchId, [
    ...messages,
    {'role': 'assistant', 'content': cleaned},
  ], clock());
  return cleaned;
}

const chatConversationFile = 'chat_conversation.json';

String _failureText(OpenRouterFailure failure) => switch (failure.kind) {
  OpenRouterFailureKind.auth =>
    'OpenRouter rejected the API key. Check it in the ZSWatch app.',
  OpenRouterFailureKind.credits => 'OpenRouter is out of credits.',
  OpenRouterFailureKind.retry => "Couldn't reach OpenRouter. Try again.",
  OpenRouterFailureKind.rejected => "OpenRouter couldn't answer that.",
};

Future<String> _transcribe(
  CompanionRecording recording,
  String sttModel,
  OpenRouterClient client,
  Directory support,
  CompanionVoiceCancellation control,
  void Function(TranscriptionEngine) onEngine,
) async {
  final verified = await loadVerifiedCompanionRecording(recording, support);
  control.check();
  final audio = OggOpusWriter.convert(verified.parsed);
  if (isOpenRouterModel(sttModel)) {
    return (await client.transcribe(openRouterModelId(sttModel), audio)).trim();
  }
  final engine = createTranscriptionEngine(
    TranscriptionEngineType.values.byName(sttModel),
  );
  onEngine(engine);
  final scratch = await Directory.systemTemp.createTemp('companion-chat-');
  try {
    if (!await engine.isAvailable()) {
      throw PlatformException(code: 'MODEL_MISSING');
    }
    final file = File(p.join(scratch.path, 'question.ogg'));
    await file.writeAsBytes(audio, flush: true);
    control.check();
    return (await engine.transcribe(file.path)).trim();
  } finally {
    await releaseCompanionTranscriber(engine);
    await scratch.delete(recursive: true);
  }
}
