import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/extracted_action.dart';
import '../data/repositories/extracted_action_repository.dart';
import '../data/repositories/voice_memo_repository.dart';
import '../services/ai/ai_debug_info.dart';
import '../services/ai/extracted_action_creation_service.dart';
import '../services/ai/llm_service.dart';
import '../services/ai/voice_note_ai_pipeline.dart';
import 'settings_providers.dart';
import 'voice_memo_providers.dart';
import 'watch_providers.dart';

// ---------------------------------------------------------------------------
// Core service providers
// ---------------------------------------------------------------------------

/// Singleton LLM service backed by fllama.
final llmServiceProvider = Provider<LlmService>((ref) {
  final service = LlmService();

  // Update model gracefully without completely destroying the LlmService
  ref.listen<String>(selectedAiModelIdProvider, (previous, next) {
    service.selectModel(next);
  });

  service.selectModel(ref.read(selectedAiModelIdProvider));

  ref.onDispose(() => service.dispose());
  return service;
});

final llmAvailableModelsProvider = FutureProvider<List<LlmModelInfo>>((
  ref,
) async {
  final service = ref.watch(llmServiceProvider);
  return service.availableModels();
});

final selectedLlmModelInfoProvider = FutureProvider<LlmModelInfo>((ref) async {
  final service = ref.watch(llmServiceProvider);
  return service.currentModelInfo();
});

/// Observable service state (status + download progress).
final llmServiceStateProvider = StreamProvider<LlmServiceState>((ref) {
  final service = ref.watch(llmServiceProvider);
  return service.stateStream;
});

/// Whether the GGUF model file exists on disk.
final llmModelDownloadedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(llmServiceProvider);
  return service.isModelDownloaded();
});

/// Size of the local model file in bytes (null if not downloaded).
final llmModelSizeProvider = FutureProvider<int?>((ref) async {
  final service = ref.watch(llmServiceProvider);
  return service.modelFileSize();
});

/// Memory fit check for the currently selected model on this device.
final llmModelFitProvider = FutureProvider<ModelFitResult>((ref) async {
  final service = ref.watch(llmServiceProvider);
  final model = await ref.watch(selectedLlmModelInfoProvider.future);
  return service.checkModelFit(model);
});

// ---------------------------------------------------------------------------
// Extracted-action repository
// ---------------------------------------------------------------------------

final extractedActionRepositoryProvider = Provider<ExtractedActionRepository>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return ExtractedActionRepository(db);
});

final extractedActionCreationServiceProvider =
    Provider<ExtractedActionCreationService>((ref) {
      return const ExtractedActionCreationService();
    });

final writableCalendarsProvider = FutureProvider<List<PlatformCalendar>>((
  ref,
) async {
  final service = ref.watch(extractedActionCreationServiceProvider);
  return service.listWritableCalendars();
});

class ExtractedActionOperations {
  final ExtractedActionRepository _actionRepository;
  final ExtractedActionCreationService _creationService;

  const ExtractedActionOperations({
    required ExtractedActionRepository actionRepository,
    required ExtractedActionCreationService creationService,
  }) : _actionRepository = actionRepository,
       _creationService = creationService;

  Future<String> createAction({
    required ExtractedAction action,
    required ActionCreationDraft draft,
  }) async {
    final created = await _creationService.createDraft(draft);
    await _actionRepository.markCreated(
      actionId: action.id,
      platformTargetId: created.platformId,
    );
    final warning = created.syncWarningMessage;
    if (warning != null) {
      return '${created.successMessage} (⚠ $warning)';
    }
    return created.successMessage;
  }

  Future<void> dismissAction(int actionId) {
    return _actionRepository.dismiss(actionId);
  }

  Future<void> deleteAction(int actionId) {
    return _actionRepository.deleteAction(actionId);
  }
}

final extractedActionOperationsProvider = Provider<ExtractedActionOperations>((
  ref,
) {
  return ExtractedActionOperations(
    actionRepository: ref.watch(extractedActionRepositoryProvider),
    creationService: ref.watch(extractedActionCreationServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// AI pipeline
// ---------------------------------------------------------------------------

/// The voice-note AI pipeline wired with the LLM service + repositories.
final voiceNoteAiPipelineProvider = Provider<VoiceNoteAiPipeline>((ref) {
  final llm = ref.watch(llmServiceProvider);
  final memoRepo = ref.watch(voiceMemoRepositoryProvider);
  final actionRepo = ref.watch(extractedActionRepositoryProvider);
  final correctionEnabled = ref.watch(aiCorrectionEnabledProvider);
  return VoiceNoteAiPipeline(
    llmService: llm,
    memoRepository: memoRepo,
    actionRepository: actionRepo,
    correctTranscription: correctionEnabled,
  );
});

/// Stream of debug info from the most recent AI processing run.
final aiProcessingDebugInfoProvider = StreamProvider<AiDebugInfo?>((ref) {
  final pipeline = ref.watch(voiceNoteAiPipelineProvider);
  return pipeline.debugInfoStream;
});

// ---------------------------------------------------------------------------
// AI actions notifier (used by settings + voice memos screens)
// ---------------------------------------------------------------------------

class _AiActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final VoiceNoteAiPipeline _pipeline;
  final VoiceMemoRepository _memoRepo;

  _AiActionsNotifier({
    required VoiceNoteAiPipeline pipeline,
    required VoiceMemoRepository memoRepo,
  }) : _pipeline = pipeline,
       _memoRepo = memoRepo,
       super(const AsyncData(null));

  /// Process a single voice memo identified by [filename].
  Future<void> processVoiceMemo(String filename) async {
    state = const AsyncLoading();
    try {
      final memo = await _memoRepo.getMemoByFilename(filename);
      if (memo == null) throw Exception('Memo not found: $filename');

      final transcript = memo.transcription?.trim();
      if (transcript == null || transcript.isEmpty) {
        throw StateError('Transcribe the voice note before AI processing.');
      }

      final success = await _pipeline.processMemo(
        memoId: memo.id,
        filename: memo.filename,
        transcript: transcript,
      );

      if (!success) {
        throw StateError('AI processing did not complete for $filename.');
      }

      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('[AiActions] processVoiceMemo error: $e');
      state = AsyncError(e, st);
    }
  }

  /// Process all transcribed-but-unprocessed memos.
  Future<void> processAllUnprocessed() async {
    state = const AsyncLoading();
    try {
      final count = await _pipeline.processAllUnprocessed();
      debugPrint('[AiActions] Processed $count memos');
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('[AiActions] processAllUnprocessed error: $e');
      state = AsyncError(e, st);
    }
  }
}

final aiActionsProvider =
    StateNotifierProvider<_AiActionsNotifier, AsyncValue<void>>((ref) {
      final pipeline = ref.watch(voiceNoteAiPipelineProvider);
      final memoRepo = ref.watch(voiceMemoRepositoryProvider);
      return _AiActionsNotifier(pipeline: pipeline, memoRepo: memoRepo);
    });

// ---------------------------------------------------------------------------
// Extracted actions per memo (for the detail screen)
// ---------------------------------------------------------------------------

final extractedActionsForMemoProvider =
    StreamProvider.family<List<ExtractedAction>, int>((ref, memoId) {
      final repo = ref.watch(extractedActionRepositoryProvider);
      return repo.watchActionsForMemo(memoId);
    });

/// Watch all alarm and timer extracted actions (for iOS Alarms & Timers page)
final alarmTimerActionsProvider = StreamProvider<List<ExtractedAction>>((ref) {
  final repo = ref.watch(extractedActionRepositoryProvider);
  return repo.watchAlarmTimerActions();
});

/// Map of memoId → set of action type strings (for list filtering)
final memoActionTypesMapProvider = StreamProvider<Map<int, Set<String>>>((ref) {
  final repo = ref.watch(extractedActionRepositoryProvider);
  return repo.watchMemoActionTypesMap();
});
