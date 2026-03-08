import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/extracted_action.dart';
import '../data/repositories/extracted_action_repository.dart';
import '../data/repositories/voice_memo_repository.dart';
import '../services/ai/ai_startup_test.dart';
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
  final selectedModelId = ref.watch(selectedAiModelIdProvider);
  final service = LlmService();
  service.selectModel(selectedModelId);
  ref.onDispose(() => service.dispose());
  return service;
});

final llmAvailableModelsProvider = FutureProvider<List<LlmModelInfo>>((ref) async {
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

// ---------------------------------------------------------------------------
// Extracted-action repository
// ---------------------------------------------------------------------------

final _extractedActionRepositoryProvider =
    Provider<ExtractedActionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ExtractedActionRepository(db);
});

// ---------------------------------------------------------------------------
// AI pipeline
// ---------------------------------------------------------------------------

/// The voice-note AI pipeline wired with the LLM service + repositories.
final voiceNoteAiPipelineProvider = Provider<VoiceNoteAiPipeline>((ref) {
  final llm = ref.watch(llmServiceProvider);
  final memoRepo = ref.watch(voiceMemoRepositoryProvider);
  final actionRepo = ref.watch(_extractedActionRepositoryProvider);
  return VoiceNoteAiPipeline(
    llmService: llm,
    memoRepository: memoRepo,
    actionRepository: actionRepo,
  );
});

/// Stream of debug info from the most recent AI processing run.
final aiProcessingDebugInfoProvider =
    StreamProvider<AiProcessingDebugInfo?>((ref) {
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
  })  : _pipeline = pipeline,
        _memoRepo = memoRepo,
        super(const AsyncData(null));

  /// Process a single voice memo identified by [filename].
  Future<void> processVoiceMemo(String filename) async {
    state = const AsyncLoading();
    try {
      final memo = await _memoRepo.getMemoByFilename(filename);
      if (memo == null) throw Exception('Memo not found: $filename');

      await _pipeline.processMemo(
        memoId: memo.id,
        filename: memo.filename,
        transcript: memo.transcription ?? '',
      );
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
  final repo = ref.watch(_extractedActionRepositoryProvider);
  return repo.watchActionsForMemo(memoId);
});

// ---------------------------------------------------------------------------
// Startup test (re-export for app.dart)
// ---------------------------------------------------------------------------

/// Convenience re-export so app.dart can import just ai_providers.dart.
Future<void> runAiStartupTest(WidgetRef ref) async {
  final llm = ref.read(llmServiceProvider);
  final downloaded = await llm.isModelDownloaded();
  if (!downloaded) {
    debugPrint(
      '[AiStartupTest] Model not downloaded, skipping self-test. '
      'Download via Settings → AI Processing.',
    );
    return;
  }
  await aiStartupSelfTest(llm);
}
