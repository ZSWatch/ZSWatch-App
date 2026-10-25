import 'dart:io';
import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/services.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/companion_recording.dart';
import '../voice_memo/transcription_engine.dart';
import '../voice_memo/verified_companion_recording.dart';
import '../voice_memo/ogg_opus_writer.dart';
import 'companion_chat_processor.dart';
import 'companion_reply_processor.dart';
import 'llm_service.dart';
import 'openrouter_client.dart';
import 'voice_note_ai_pipeline.dart';

/// Per-execution cancellation; durable job fencing stays in the native journal.
class CompanionVoiceCancellation {
  bool _cancelled = false;
  Future<void> Function()? _abort;

  bool get isCancelled => _cancelled;

  void check() {
    if (_cancelled) throw PlatformException(code: 'CANCELLED');
  }

  void bind(Future<void> Function() abort) {
    check();
    _abort = abort;
  }

  void unbind() => _abort = null;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _abort?.call();
  }
}

/// Shared Dart voice workflow. Platform adapters supply input and durable checkpoints.
/// Never owns BLE, schedules OS work, uploads audio or creates external actions.
Future<Map<String, Object?>> processCompanionVoiceRecording(
  Map<String, Object?> request, {
  required Future<void> Function(String transcript) saveTranscript,
  CompanionVoiceCancellation? cancellation,
  LlmService Function()? analyzerFactory,
  OpenRouterClient Function(String apiKey)? cloudFactory,
}) async {
  final control = cancellation ?? CompanionVoiceCancellation();
  control.check();
  final spec = Map<String, Object?>.from(request['spec'] as Map);
  final models = (spec['model'] as String? ?? '').split('|');
  // Consent to upload is recorded in the job when it is created.
  final cloud = models.any(isOpenRouterModel);
  if (request['version'] != 1 ||
      spec['provider'] != 'dart-voice-v1' ||
      spec['backend'] != (cloud ? 'openrouter' : 'local') ||
      spec['upload_authorized'] != cloud ||
      !['voice-v1', 'transcribe-v1'].contains(spec['pipeline_revision'])) {
    throw const FormatException('Unsupported voice processing request');
  }
  final recording = CompanionRecording.decode(
    spec['recording_id']! as String,
    Map<String, Object?>.from(request['recording'] as Map),
  );
  if (recording.sha256 != spec['input_sha256'] ||
      recording.watchId != spec['watch_id']) {
    throw const FormatException('Processing input differs from committed job');
  }
  if (models.length != 3 || !['true', 'false'].contains(models[2])) {
    throw const FormatException('Invalid processing configuration');
  }
  final cloudStt = isOpenRouterModel(models[0]);
  final sttType = cloudStt
      ? null
      : TranscriptionEngineType.values.byName(models[0]);
  final key = (request['credentials'] as Map?)?['openrouter_key'];
  final chatKind = chatKindOf(recording.filename);
  if (chatKind != null) {
    // Without a key the answer explains what to set up.
    final chatClient = cloud && key is String && key.isNotEmpty
        ? (cloudFactory ?? OpenRouterClient.new)(key)
        : null;
    try {
      return await answerCompanionQuestion(
        recording: recording,
        kind: chatKind,
        models: models,
        client: chatClient,
        support: Directory(
          await (await getApplicationSupportDirectory()).resolveSymbolicLinks(),
        ),
        saveTranscript: saveTranscript,
        control: control,
      );
    } finally {
      chatClient?.close();
    }
  }
  if (isReplyRecording(recording.filename)) {
    // Without a key the draft explains what to set up.
    final replyClient = cloudStt && key is String && key.isNotEmpty
        ? (cloudFactory ?? OpenRouterClient.new)(key)
        : null;
    try {
      return await transcribeCompanionReply(
        recording: recording,
        sttModel: models[0],
        client: replyClient,
        support: Directory(
          await (await getApplicationSupportDirectory()).resolveSymbolicLinks(),
        ),
        saveTranscript: saveTranscript,
        control: control,
      );
    } finally {
      replyClient?.close();
    }
  }
  OpenRouterClient? client;
  if (cloud) {
    if (key is! String || key.isEmpty) {
      throw PlatformException(code: 'CLOUD_AUTH');
    }
    client = (cloudFactory ?? OpenRouterClient.new)(key);
  }
  TranscriptionEngine? engine;
  LlmService? llm;
  control.bind(() async {
    client?.close();
    await Future.wait([
      if (engine != null) engine.cancel(),
      if (llm != null) llm.cancelProcessing(),
    ]);
  });
  Directory? scratch;
  try {
    final support = Directory(
      await (await getApplicationSupportDirectory()).resolveSymbolicLinks(),
    );
    final verified = await loadVerifiedCompanionRecording(recording, support);
    control.check();
    var transcript = request['transcript'] as String?;
    if (transcript == null && cloudStt) {
      transcript = (await client!.transcribe(
        openRouterModelId(models[0]),
        OggOpusWriter.convert(verified.parsed),
      )).trim();
      control.check();
      requireCompanionSpeech(transcript);
      await saveTranscript(transcript);
    }
    if (transcript == null) {
      final transcriber = createTranscriptionEngine(sttType!);
      engine = transcriber;
      if (!await transcriber.isAvailable()) {
        throw PlatformException(code: 'MODEL_MISSING');
      }
      control.check();
      scratch = await (await getTemporaryDirectory()).createTemp(
        'companion-voice-',
      );
      final audio = File(p.join(scratch.path, 'recording.ogg'));
      await audio.writeAsBytes(
        OggOpusWriter.convert(verified.parsed),
        flush: true,
      );
      control.check();
      transcript = (await transcriber.transcribe(audio.path)).trim();
      control.check();
      requireCompanionSpeech(transcript);
      // Complete this platform persistence callback before starting analysis.
      await saveTranscript(transcript);
      await releaseCompanionTranscriber(transcriber);
      engine = null;
    }
    control.check();
    requireCompanionSpeech(transcript);
    if (spec['pipeline_revision'] == 'transcribe-v1') {
      return {
        'version': 1,
        'transcript': transcript,
        'summary': '',
        'category': '',
        'actions': <Object?>[],
      };
    }
    if (client != null &&
        request['transcript'] == null &&
        isOpenRouterModel(models[1])) {
      final answer = await answerIfQuestion(
        transcript: transcript,
        watchId: recording.watchId,
        model: openRouterModelId(models[1]),
        client: client,
        support: support,
      );
      control.check();
      if (answer != null) {
        return {
          'version': 1,
          'transcript': transcript,
          'summary': answer,
          'category': chatCategory,
          'actions': <Object?>[],
        };
      }
    }
    final analyzer =
        (analyzerFactory?.call() ??
              LlmService(isCancelled: () => control.isCancelled))
          ..selectModel(models[1])
          ..referenceTime = recording.timestampUtc.toLocal();
    if (client != null) analyzer.useOpenRouter(client);
    llm = analyzer;
    if (!await analyzer.isModelDownloaded()) {
      throw PlatformException(code: 'MODEL_MISSING');
    }
    control.check();
    final result = analyzer.isBrainDump(transcript)
        ? await analyzer.processTranscriptBrainDump(
            transcript,
            correctTranscription: models[2] == 'true',
          )
        : await analyzer.processTranscript(
            transcript,
            correctTranscription: models[2] == 'true',
          );
    control.check();
    // Native result validation requires a summary. Actions without one keep
    // their titles as the summary instead of failing the whole result.
    final summary = result.summary.trim().isNotEmpty
        ? result.summary
        : result.actions
              .map((a) => a.title.trim())
              .where((t) => t.isNotEmpty)
              .join('; ');
    // Speech has already passed validation and is durably checkpointed. An
    // empty analysis is an analysis failure, not evidence of silent audio.
    if (summary.trim().isEmpty) {
      throw PlatformException(code: 'ANALYSIS_EMPTY');
    }
    return {
      'version': 1,
      'transcript': result.correctedTranscription ?? transcript,
      'summary': summary,
      'category': result.category,
      'actions': [
        for (final a in result.actions)
          {
            'type': a.type,
            'title': a.title,
            if (a.notes != null) 'notes': a.notes,
            if (a.dueDate != null) 'due_date': a.dueDate,
            if (a.startTime != null) 'start_time': a.startTime,
            if (a.location != null) 'location': a.location,
            if (a.durationSeconds != null)
              'duration_seconds': a.durationSeconds,
          },
      ],
    };
  } on OpenRouterFailure catch (e) {
    control.check();
    throw cloudPlatformException(e);
  } finally {
    control.unbind();
    client?.close();
    if (engine != null) await releaseCompanionTranscriber(engine);
    llm?.dispose();
    if (scratch != null && scratch.existsSync()) {
      await scratch.delete(recursive: true);
    }
  }
}

/// Native schedulers act on these codes: auth and credits block the job until
/// the key changes, retry defers it without spending an attempt.
PlatformException cloudPlatformException(OpenRouterFailure failure) {
  final code = switch (failure.kind) {
    OpenRouterFailureKind.auth => 'CLOUD_AUTH',
    OpenRouterFailureKind.credits => 'CLOUD_CREDITS',
    OpenRouterFailureKind.retry => 'CLOUD_RETRY',
    OpenRouterFailureKind.rejected => 'CLOUD_REJECTED',
  };
  return PlatformException(
    code: code,
    message: failure.status?.toString(),
    details: failure.retryAfter?.inSeconds,
  );
}

/// Uses the same no-speech policy as interactive voice-note processing.
void requireCompanionSpeech(String transcript) {
  if (transcript.trim().isEmpty ||
      VoiceNoteAiPipeline.isNoSpeechTranscript(transcript)) {
    throw PlatformException(code: 'NO_SPEECH');
  }
}

/// Free the native Whisper context before loading an analysis model. Closing a
/// Dart stream alone does not release the package's process-global model cache.
Future<void> releaseCompanionTranscriber(TranscriptionEngine engine) async {
  engine.dispose();
  if (engine is WhisperEngine || engine is CustomGgmlWhisperEngine) {
    await const Whisper(model: WhisperModel.base).dispose();
  }
}
