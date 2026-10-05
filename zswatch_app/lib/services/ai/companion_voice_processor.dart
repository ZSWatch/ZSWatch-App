import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/companion_recording.dart';
import '../voice_memo/transcription_engine.dart';
import '../voice_memo/verified_companion_recording.dart';
import '../voice_memo/ogg_opus_writer.dart';
import 'llm_service.dart';
import 'voice_note_ai_pipeline.dart';

/// Shared Dart voice workflow. Platform adapters supply input and durable checkpoints.
/// Never owns BLE, schedules OS work, uploads audio or creates external actions.
Future<Map<String, Object?>> processCompanionVoiceRecording(
  Map<String, Object?> request, {
  required Future<void> Function(String transcript) saveTranscript,
}) async {
  final spec = Map<String, Object?>.from(request['spec'] as Map);
  if (request['version'] != 1 ||
      spec['provider'] != 'dart-voice-v1' ||
      spec['backend'] != 'local' ||
      spec['upload_authorized'] != false) {
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
  final engine = createTranscriptionEngine(sttType);
  final llm = LlmService()..selectModel(models[1]);
  Directory? scratch;
  try {
    final support = Directory(
      await (await getApplicationSupportDirectory()).resolveSymbolicLinks(),
    );
    final verified = await loadVerifiedCompanionRecording(recording, support);
    var transcript = request['transcript'] as String?;
    if (transcript == null) {
      if (!await engine.isAvailable()) {
        throw PlatformException(code: 'MODEL_MISSING');
      }
      scratch = await (await getTemporaryDirectory()).createTemp(
        'companion-voice-',
      );
      final audio = File(p.join(scratch.path, 'recording.ogg'));
      await audio.writeAsBytes(
        OggOpusWriter.convert(verified.parsed),
        flush: true,
      );
      transcript = (await engine.transcribe(audio.path)).trim();
      requireCompanionSpeech(transcript);
      // Complete this platform persistence callback before starting analysis.
      await saveTranscript(transcript);
    }
    requireCompanionSpeech(transcript);
    if (!await llm.isModelDownloaded()) {
      throw PlatformException(code: 'MODEL_MISSING');
    }
    final result = llm.isBrainDump(transcript)
        ? await llm.processTranscriptBrainDump(
            transcript,
            correctTranscription: models[2] == 'true',
          )
        : await llm.processTranscript(
            transcript,
            correctTranscription: models[2] == 'true',
          );
    // The existing router can also identify non-speech after transcription.
    if (result.summary.trim().isEmpty && result.actions.isEmpty) {
      throw PlatformException(code: 'NO_SPEECH');
    }
    return {
      'version': 1,
      'transcript': result.correctedTranscription ?? transcript,
      'summary': result.summary,
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
    engine.dispose();
    llm.dispose();
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
