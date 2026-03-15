import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/models/extracted_action.dart';
import '../../data/repositories/extracted_action_repository.dart';
import '../../data/repositories/voice_memo_repository.dart';
import 'ai_debug_info.dart';
import 'llm_service.dart';

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

  /// Whether to run the LLM correction step before classification.
  bool correctTranscription;

  /// Called after successful AI processing with (filename, summary).
  /// Used to send the result toast back to the watch.
  void Function(String filename, String title)? onProcessingComplete;

  /// Stream of debug info from the most recent AI processing runs.
  final _debugInfoSubject = BehaviorSubject<AiDebugInfo?>.seeded(null);
  Stream<AiDebugInfo?> get debugInfoStream => _debugInfoSubject.stream;
  AiDebugInfo? get lastDebugInfo => _debugInfoSubject.value;

  /// Completed debug info stored per filename so the UI can retrieve results
  /// for a specific voice note rather than only the latest global run.
  final Map<String, AiDebugInfo> _debugInfoByFile = {};

  /// Get the most recent completed debug info for [filename], or null.
  AiDebugInfo? getDebugInfoForFile(String filename) =>
      _debugInfoByFile[filename];

  VoiceNoteAiPipeline({
    required LlmService llmService,
    required VoiceMemoRepository memoRepository,
    required ExtractedActionRepository actionRepository,
    this.correctTranscription = false,
  }) : _llmService = llmService,
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
      debugPrint(
        '[VoiceNoteAiPipeline] Skipping empty transcript for $filename',
      );
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
      _debugInfoSubject.add(
        AiDebugInfo(
          filename: filename,
          modelName: _llmService.modelName,
          transcriptionResult: transcript,
          phase: 'loading',
          partialOutput: '',
          tokens: 0,
          timestamp: DateTime.now(),
        ),
      );

      // Route to brain dump prompt for long transcripts (Feature 6)
      final useBrainDump = _llmService.isBrainDump(transcript);
      debugPrint(
        '[VoiceNoteAiPipeline] Brain dump routing: '
        '${useBrainDump ? "YES" : "NO"} for $filename',
      );

      // Stopwatch to compute live elapsed time & tokens-per-second
      final sw = Stopwatch()..start();

      // Helper that emits a live progress update with timing metrics.
      void emitLive(String phase, String partial, int tokens) {
        final elapsedMs = sw.elapsedMilliseconds;
        final tps = elapsedMs > 0 ? tokens / (elapsedMs / 1000.0) : 0.0;
        final mem = _llmService.lastInferenceMemoryInfo;
        _debugInfoSubject.add(
          AiDebugInfo(
            filename: filename,
            modelName: _llmService.modelName,
            transcriptionResult: transcript,
            phase: phase,
            partialOutput: partial,
            tokens: tokens,
            elapsed: sw.elapsed,
            tokensPerSecond: tps,
            timestamp: DateTime.now(),
            deviceMemoryMB: mem?.deviceMB,
            availableMemoryMB: mem?.availableMB,
            modelSizeMB: mem?.modelMB,
            memoryHeadroomMB: mem?.headroomMB,
            requestedContextSize: mem?.requestedContextSize,
            inferenceContextSize: mem?.contextSize,
            inferenceMaxTokensCap: mem?.maxTokensCap,
          ),
        );
      }

      // Run the LLM processing with live progress updates
      final result = useBrainDump
          ? await _llmService.processTranscriptBrainDump(
              transcript,
              correctTranscription: correctTranscription,
              onProgress: (phase, partial, tokens) {
                emitLive(phase, partial, tokens);
              },
            )
          : await _llmService.processTranscript(
              transcript,
              correctTranscription: correctTranscription,
              onProgress: (phase, partial, tokens) {
                emitLive(phase, partial, tokens);
              },
            );
      sw.stop();

      debugPrint(
        '[VoiceNoteAiPipeline] Processed $filename: '
        'summary="${result.summary}", category=${result.category}, '
        '${result.actions.length} actions',
      );

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

      // Replace any previous extracted actions for this memo before inserting
      // the latest set, so re-processing never duplicates suggestions.
      await _actionRepository.deleteActionsForMemo(memoId);

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

      // Notify watch with round-trip confirmation toast
      onProcessingComplete?.call(filename, result.summary);

      // Publish final debug info and store per-file
      final mem = _llmService.lastInferenceMemoryInfo;
      final finalDebug = AiDebugInfo(
        filename: filename,
        modelName: _llmService.modelName,
        rawPrompt: result.classifyMetrics?.rawPrompt,
        promptStrategy: result.classifyMetrics?.promptStrategy,
        attempts: result.classifyMetrics?.attempts ?? 1,
        retryEnabled: result.classifyMetrics?.retryEnabled ?? false,
        transcriptionResult: result.originalTranscription,
        correctedTranscription: result.correctedTranscription,
        rawOutput: result.classifyMetrics?.rawResponse,
        parsedJson: result.classifyMetrics?.parsedJson,
        extractedIntent: result.extractedIntent,
        extractedTitle: result.extractedTitle,
        datetimeExpressionOriginal: result.datetimeExpressionOriginal,
        datetimeExpressionEnglish: result.datetimeExpressionEnglish,
        resolvedDateTime: result.resolvedDateTime,
        resolverMethod: result.resolverMethod,
        extractedActions: result.actionChronoDetails,
        summary: result.summary,
        category: result.category,
        actionCount: result.actions.length,
        correctionElapsed: result.correctionMetrics?.wallTime ?? Duration.zero,
        correctionTokensPerSecond: result.correctionMetrics?.tokensPerSecond,
        elapsed: result.classifyMetrics?.wallTime ?? Duration.zero,
        tokensPerSecond: result.classifyMetrics?.tokensPerSecond,
        correctionTokens: result.correctionMetrics?.completionTokens ?? 0,
        tokens: result.classifyMetrics?.completionTokens ?? 0,
        phase: 'done',
        timestamp: DateTime.now(),
        deviceMemoryMB: mem?.deviceMB,
        availableMemoryMB: mem?.availableMB,
        modelSizeMB: mem?.modelMB,
        memoryHeadroomMB: mem?.headroomMB,
        requestedContextSize: mem?.requestedContextSize,
        inferenceContextSize: mem?.contextSize,
        inferenceMaxTokensCap: mem?.maxTokensCap,
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
