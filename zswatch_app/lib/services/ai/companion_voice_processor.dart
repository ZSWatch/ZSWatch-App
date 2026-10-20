import 'dart:io';
import 'package:flutter/services.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/companion_recording.dart';
import '../voice_memo/transcription_engine.dart';
import '../voice_memo/verified_companion_recording.dart';
import '../voice_memo/ogg_opus_writer.dart';
import 'llm_service.dart';
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
}) async {
  final control = cancellation ?? CompanionVoiceCancellation();
  control.check();
  final spec = Map<String, Object?>.from(request['spec'] as Map);
  if (request['version'] != 1 ||
      spec['provider'] != 'dart-voice-v1' ||
      spec['backend'] != 'local' ||
      spec['upload_authorized'] != false ||
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
  final models = (spec['model']! as String).split('|');
  if (models.length != 3 || !['true', 'false'].contains(models[2])) {
    throw const FormatException('Invalid processing configuration');
  }
  final sttType = TranscriptionEngineType.values.byName(models[0]);
  TranscriptionEngine? engine;
  LlmService? llm;
  control.bind(() async {
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
    if (transcript == null) {
      final transcriber = createTranscriptionEngine(sttType);
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
      await _releaseTranscriber(transcriber);
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
    final analyzer =
        (analyzerFactory?.call() ??
              LlmService(isCancelled: () => control.isCancelled))
          ..selectModel(models[1])
          ..referenceTime = recording.timestampUtc.toLocal();
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
            rejectNoSpeechRoute: false,
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
  } finally {
    control.unbind();
    if (engine != null) await _releaseTranscriber(engine);
    llm?.dispose();
    if (scratch != null && scratch.existsSync()) {
      await scratch.delete(recursive: true);
    }
  }
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
Future<void> _releaseTranscriber(TranscriptionEngine engine) async {
  engine.dispose();
  if (engine is WhisperEngine || engine is CustomGgmlWhisperEngine) {
    await const Whisper(model: WhisperModel.base).dispose();
  }
}
