import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/services.dart';

import '../../data/models/companion_recording.dart';
import '../voice_memo/transcription_engine.dart';
import 'companion_chat_processor.dart';
import 'companion_voice_processor.dart';
import 'openrouter_client.dart';

/// The watch names a dictated reply to a notification `reply_...`.
bool isReplyRecording(String filename) => filename.startsWith('reply_');

/// Category the native owners use to send a reply draft to the watch.
const replyCategory = 'reply';

/// A reply that could not be transcribed. The summary tells the watch why.
const replyErrorCategory = 'reply_error';

/// Transcribes a dictated reply. The transcript is the draft the watch shows
/// for review, so nothing is analysed or rewritten by a language model.
/// Failures become a short message for the watch instead of a failed job,
/// since a late retry of a reply is useless.
Future<Map<String, Object?>> transcribeCompanionReply({
  required CompanionRecording recording,
  required String sttModel,
  required OpenRouterClient? client,
  required Directory support,
  required Future<void> Function(String transcript) saveTranscript,
  required CompanionVoiceCancellation control,
}) async {
  Map<String, Object?> result(String category, String text) => {
    'version': 1,
    'transcript': category == replyCategory ? text : '',
    'summary': text,
    'category': category,
    'actions': <Object?>[],
  };
  if (isOpenRouterModel(sttModel) && client == null) {
    return result(
      replyErrorCategory,
      'Speech to text needs an OpenRouter API key in the ZSWatch app.',
    );
  }
  TranscriptionEngine? engine;
  control.bind(() async {
    client?.close();
    await engine?.cancel();
  });
  try {
    final text = await transcribeCompanionRecording(
      recording,
      sttModel,
      client,
      support,
      control,
      (e) => engine = e,
    );
    requireCompanionSpeech(text);
    control.check();
    await saveTranscript(text);
    return result(replyCategory, text);
  } on PlatformException catch (e) {
    control.check();
    return result(replyErrorCategory, switch (e.code) {
      'NO_SPEECH' => "I didn't catch that. Try again.",
      'MODEL_MISSING' => 'The speech model is not downloaded on the phone.',
      _ => 'Transcription failed. Try again.',
    });
  } on OpenRouterFailure catch (e) {
    control.check();
    return result(replyErrorCategory, openRouterFailureText(e));
  } finally {
    control.unbind();
  }
}
