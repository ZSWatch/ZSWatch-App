import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/models/extracted_action.dart';
import '../../data/repositories/extracted_action_repository.dart';
import '../../data/repositories/voice_memo_repository.dart';
import 'llm_service.dart';

/// Debug info from the last AI processing run.
class AiProcessingDebugInfo {
  final String filename;
  final String modelName;
  final String? originalTranscription;
  final String? correctedTranscription;
  final String? rawLlmResponse;
  final String? parsedJson;
  final String? summary;
  final String? category;
  final int actionCount;
  final Duration? correctionTime;
  final double? correctionTokensPerSec;
  final Duration? classifyTime;
  final double? classifyTokensPerSec;
  final int? correctionTokens;
  final int? classifyTokens;
  final DateTime timestamp;

  /// Current processing phase: 'correcting', 'classifying', 'done', or null
  /// when viewing a completed result.
  final String? currentPhase;

  /// Partial LLM output that builds up token-by-token during generation.
  final String partialResponse;

  /// Current token count for the active generation phase.
  final int liveTokenCount;

  /// Whether processing has finished (final snapshot vs live update).
  final bool isComplete;

  const AiProcessingDebugInfo({
    required this.filename,
    required this.modelName,
    this.originalTranscription,
    this.correctedTranscription,
    this.rawLlmResponse,
    this.parsedJson,
    this.summary,
    this.category,
    this.actionCount = 0,
    this.correctionTime,
    this.correctionTokensPerSec,
    this.classifyTime,
    this.classifyTokensPerSec,
    this.correctionTokens,
    this.classifyTokens,
    required this.timestamp,
    this.currentPhase,
    this.partialResponse = '',
    this.liveTokenCount = 0,
    this.isComplete = true,
  });
}

/// Orchestrates AI processing of voice memo transcripts.
///
/// After a transcript is available, this pipeline:
/// 1. Sends the transcript to the LLM for summarization, categorization,
///    and action extraction (single pass)
/// 2. Persists results in the database
/// 3. Creates extracted action records for user review
class VoiceNoteAiPipeline {
  final LlmService _llmService;
  final VoiceMemoRepository _memoRepository;
  final ExtractedActionRepository _actionRepository;

  /// Stream of debug info from the most recent AI processing runs.
  final _debugInfoSubject = BehaviorSubject<AiProcessingDebugInfo?>.seeded(null);
  Stream<AiProcessingDebugInfo?> get debugInfoStream => _debugInfoSubject.stream;
  AiProcessingDebugInfo? get lastDebugInfo => _debugInfoSubject.value;

  /// Completed debug info stored per filename so the UI can retrieve results
  /// for a specific voice note rather than only the latest global run.
  final Map<String, AiProcessingDebugInfo> _debugInfoByFile = {};

  /// Get the most recent completed debug info for [filename], or null.
  AiProcessingDebugInfo? getDebugInfoForFile(String filename) =>
      _debugInfoByFile[filename];

  VoiceNoteAiPipeline({
    required LlmService llmService,
    required VoiceMemoRepository memoRepository,
    required ExtractedActionRepository actionRepository,
  })  : _llmService = llmService,
        _memoRepository = memoRepository,
        _actionRepository = actionRepository;

  /// Process a single voice memo's transcript with the local LLM.
  ///
  /// Updates the processing status incrementally and persists results.
  /// Returns true if processing succeeded.
  Future<bool> processMemo({
    required int memoId,
    required String filename,
    required String transcript,
  }) async {
    if (transcript.trim().isEmpty) {
      debugPrint('[VoiceNoteAiPipeline] Skipping empty transcript for $filename');
      return false;
    }

    try {
      // Update status: summarizing (covers the single-pass processing)
      await _memoRepository.updateProcessingStatus(
        filename: filename,
        status: 'summarizing',
      );

      // Publish initial loading state so the debug sheet shows something
      // immediately (before the model finishes loading / first token arrives).
      _debugInfoSubject.add(AiProcessingDebugInfo(
        filename: filename,
        modelName: _llmService.modelName,
        originalTranscription: transcript,
        currentPhase: 'loading',
        partialResponse: '',
        liveTokenCount: 0,
        isComplete: false,
        timestamp: DateTime.now(),
      ));

      // Run the LLM processing with live progress updates
      final result = await _llmService.processTranscript(
        transcript,
        onProgress: (phase, partial, tokens) {
          _debugInfoSubject.add(AiProcessingDebugInfo(
            filename: filename,
            modelName: _llmService.modelName,
            originalTranscription: transcript,
            currentPhase: phase,
            partialResponse: partial,
            liveTokenCount: tokens,
            isComplete: false,
            timestamp: DateTime.now(),
          ));
        },
      );

      debugPrint(
          '[VoiceNoteAiPipeline] Processed $filename: '
          'summary="${result.summary}", category=${result.category}, '
          '${result.actions.length} actions');

      // If the LLM corrected the transcription, update the transcript as well
      if (result.correctedTranscription != null &&
          result.correctedTranscription!.isNotEmpty) {
        await _memoRepository.updateTranscription(
          filename: filename,
          transcription: result.correctedTranscription!,
        );
      }

      // Persist AI results on the memo
      await _memoRepository.updateAiResults(
        filename: filename,
        summary: result.summary,
        category: result.category,
        aiModel: _llmService.modelName,
      );

      // Persist extracted actions
      for (final action in result.actions) {
        final actionType = _mapActionType(action.type);
        await _actionRepository.insertAction(
          memoId: memoId,
          actionType: actionType,
          title: action.title,
          notes: action.notes,
          dueDate: _tryParseDate(action.dueDate),
          startTime: _tryParseDate(action.startTime),
          location: action.location,
        );
      }

      // Publish final debug info and store per-file
      final finalDebug = AiProcessingDebugInfo(
        filename: filename,
        modelName: _llmService.modelName,
        originalTranscription: result.originalTranscription,
        correctedTranscription: result.correctedTranscription,
        rawLlmResponse: result.classifyMetrics?.rawResponse,
        parsedJson: result.classifyMetrics?.parsedJson,
        summary: result.summary,
        category: result.category,
        actionCount: result.actions.length,
        correctionTime: result.correctionMetrics?.wallTime,
        correctionTokensPerSec: result.correctionMetrics?.tokensPerSecond,
        classifyTime: result.classifyMetrics?.wallTime,
        classifyTokensPerSec: result.classifyMetrics?.tokensPerSecond,
        correctionTokens: result.correctionMetrics?.completionTokens,
        classifyTokens: result.classifyMetrics?.completionTokens,
        currentPhase: 'done',
        isComplete: true,
        timestamp: DateTime.now(),
      );
      _debugInfoByFile[filename] = finalDebug;
      _debugInfoSubject.add(finalDebug);

      return true;
    } catch (e) {
      debugPrint('[VoiceNoteAiPipeline] Failed to process $filename: $e');
      await _memoRepository.updateProcessingStatus(
        filename: filename,
        status: 'failed',
      );
      return false;
    }
  }

  /// Process all transcribed but unprocessed memos
  Future<int> processAllUnprocessed() async {
    final unprocessed = await _memoRepository.getUnprocessedMemos();
    if (unprocessed.isEmpty) {
      debugPrint('[VoiceNoteAiPipeline] No unprocessed memos');
      return 0;
    }

    debugPrint('[VoiceNoteAiPipeline] Processing ${unprocessed.length} memos');
    int processed = 0;

    for (final memo in unprocessed) {
      if (memo.transcription == null || memo.transcription!.trim().isEmpty) {
        continue;
      }

      final success = await processMemo(
        memoId: memo.id,
        filename: memo.filename,
        transcript: memo.transcription!,
      );

      if (success) processed++;
    }

    return processed;
  }

  ExtractedActionType _mapActionType(String type) {
    switch (type.toLowerCase()) {
      case 'task':
        return ExtractedActionType.task;
      case 'calendar_event':
        return ExtractedActionType.calendarEvent;
      case 'reminder':
        return ExtractedActionType.reminder;
      default:
        return ExtractedActionType.task;
    }
  }

  DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      // Natural language dates like "tomorrow" need more sophisticated parsing.
      // For v1, we just return null and let the user edit.
      return null;
    }
  }
}
