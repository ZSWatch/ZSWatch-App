import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/extracted_action.dart';
import '../data/models/voice_memo.dart';
import '../data/repositories/voice_memo_repository.dart';
import '../services/ai/extracted_action_creation_service.dart';
import '../services/ai/voice_note_ai_pipeline.dart';
import '../services/voice_memo/transcription_engine.dart';
import '../services/voice_memo/voice_memo_sync_service.dart';
import 'ai_providers.dart';
import 'settings_providers.dart';
import 'watch_providers.dart';
import 'watch_service_provider.dart';

// ==================== Repository Provider ====================

/// Provider for the voice memo repository singleton
final voiceMemoRepositoryProvider = Provider<VoiceMemoRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return VoiceMemoRepository(db);
});

// ==================== Transcription Engine Provider ====================

/// Provider for the transcription engine singleton.
/// Recreated automatically when the user changes the engine type in settings.
final transcriptionEngineProvider = Provider<TranscriptionEngine>((ref) {
  final engineType = ref.watch(transcriptionEngineTypeProvider);
  final engine = createTranscriptionEngine(engineType);
  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Stream of transcription engine state
final transcriptionEngineStateProvider =
    StreamProvider<TranscriptionEngineState>((ref) {
      final engine = ref.watch(transcriptionEngineProvider);
      return engine.stateStream;
    });

class TranscriptionModelLocalStatus {
  final bool downloaded;
  final int? localSizeBytes;
  final String localPath;

  const TranscriptionModelLocalStatus({
    required this.downloaded,
    required this.localSizeBytes,
    required this.localPath,
  });
}

final transcriptionModelStatusProvider =
    FutureProvider.family<
      TranscriptionModelLocalStatus,
      TranscriptionEngineType
    >((ref, type) async {
      final engine = createTranscriptionEngine(type);
      try {
        final localPath = await engine.modelFilePath();
        final file = File(localPath);
        final downloaded = file.existsSync();

        return TranscriptionModelLocalStatus(
          downloaded: downloaded,
          localSizeBytes: downloaded ? file.lengthSync() : null,
          localPath: localPath,
        );
      } finally {
        engine.dispose();
      }
    });

final transcriptionConfiguredProvider = FutureProvider<bool>((ref) async {
  final selected = ref.watch(transcriptionEngineTypeProvider);
  final status = await ref.watch(
    transcriptionModelStatusProvider(selected).future,
  );
  return status.downloaded;
});

// ==================== Sync Service Provider ====================

/// Provider for the voice memo sync service singleton
final voiceMemoSyncServiceProvider = Provider<VoiceMemoSyncService>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  final repository = ref.watch(voiceMemoRepositoryProvider);

  final service = VoiceMemoSyncService(
    watchService: watchService,
    repository: repository,
  );

  // Wire up auto-transcription (and optionally AI processing) after sync.
  // Settings and pipeline are read lazily at call time so changes after
  // provider creation are always picked up.
  service.onSyncCompleted = (downloadedCount) async {
    debugPrint(
      '[VoiceMemoProviders] Sync completed ($downloadedCount new). '
      'Starting auto-transcription.',
    );
    final engine = ref.read(transcriptionEngineProvider);
    final aiEnabled = ref.read(localAiEnabledProvider);
    final autoProcess = ref.read(autoProcessVoiceNotesProvider);
    VoiceNoteAiPipeline? pipeline;
    if (aiEnabled && autoProcess) {
      pipeline = ref.read(voiceNoteAiPipelineProvider);
      // Wire round-trip confirmation: send result back to watch after AI processing
      final autoCreate = ref.read(autoCreateActionsProvider);
      pipeline!.onProcessingComplete = (filename, title, actionType, datetime) {
        service.sendResultToWatch(
          filename,
          title,
          actionType: actionType,
          datetime: datetime,
          onConfirmed: autoCreate
              ? (confirmedFilename) => _autoCreateActionsForMemo(
                  ref: ref,
                  filename: confirmedFilename,
                )
              : null,
        );
      };
    }
    await _autoTranscribeAndProcess(
      repository: repository,
      engine: engine,
      pipeline: pipeline,
      // Report per-memo progress so the UI shows "Transcribing..." state
      onTranscribingMemo: (filename) {
        ref
            .read(autoTranscribeStateProvider.notifier)
            .state = VoiceMemoActionState.loading(
          actionType: VoiceMemoActionType.transcribe,
          activeFilename: filename,
        );
      },
      onDone: () {
        ref.read(autoTranscribeStateProvider.notifier).state =
            const VoiceMemoActionState.idle();
      },
    );
  };

  ref.onDispose(() => service.dispose());
  return service;
});

/// State for background auto-transcription triggered after sync.
/// The UI watches this alongside [voiceMemoActionsProvider] so buttons
/// reflect in-progress state even when transcription was auto-started.
final autoTranscribeStateProvider = StateProvider<VoiceMemoActionState>(
  (ref) => const VoiceMemoActionState.idle(),
);

/// Auto-transcribe all untranscribed memos after sync, then optionally
/// run the AI pipeline on newly transcribed memos.
Future<void> _autoTranscribeAndProcess({
  required VoiceMemoRepository repository,
  required TranscriptionEngine engine,
  required VoiceNoteAiPipeline? pipeline,
  void Function(String filename)? onTranscribingMemo,
  void Function()? onDone,
}) async {
  try {
    final untranscribed = await repository.getUntranscribedMemos();
    if (untranscribed.isEmpty) {
      // Even if nothing new to transcribe, there may be unprocessed memos
      if (pipeline != null) {
        await pipeline.processAllUnprocessed();
      }
      onDone?.call();
      return;
    }

    debugPrint(
      '[VoiceMemoProviders] Auto-transcribing ${untranscribed.length} memos',
    );

    for (final memo in untranscribed) {
      try {
        final audioPath = memo.convertedFilePath ?? memo.localFilePath;
        if (audioPath == null) continue;

        onTranscribingMemo?.call(memo.filename);
        final text = await engine.transcribe(audioPath);
        await repository.updateTranscription(
          filename: memo.filename,
          transcription: text.isEmpty ? '[No speech detected]' : text,
        );
        debugPrint('[VoiceMemoProviders] Auto-transcribed: ${memo.filename}');
      } catch (e) {
        debugPrint(
          '[VoiceMemoProviders] Failed to transcribe ${memo.filename}: $e',
        );
      }
    }

    // After transcription, wait briefly to allow the whisper memory to be reclaimed
    // and system to stabilize before starting LLM inference. This reduces memory
    // pressure when the two models might both be in RAM simultaneously.
    if (pipeline != null) {
      debugPrint('[VoiceMemoProviders] Waiting 500ms before AI processing');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      debugPrint('[VoiceMemoProviders] Starting auto AI processing');
      await pipeline.processAllUnprocessed();
    }
  } catch (e) {
    debugPrint('[VoiceMemoProviders] Auto-transcription/processing error: $e');
  } finally {
    onDone?.call();
  }
}

/// Auto-create all pending extracted actions for a memo after the watch
/// confirmation timeout expires without an undo.
Future<void> _autoCreateActionsForMemo({
  required Ref ref,
  required String filename,
}) async {
  try {
    final repository = ref.read(voiceMemoRepositoryProvider);
    final memo = await repository.getMemoByFilename(filename);
    if (memo == null) {
      debugPrint(
        '[VoiceMemoProviders] Auto-create: memo not found for $filename',
      );
      return;
    }

    final actionRepo = ref.read(extractedActionRepositoryProvider);
    final actions = await actionRepo.getActionsForMemo(memo.id);
    final pending = actions.where((a) => !a.created && !a.dismissed).toList();

    if (pending.isEmpty) {
      debugPrint(
        '[VoiceMemoProviders] Auto-create: no pending actions for $filename',
      );
      return;
    }

    final ops = ref.read(extractedActionOperationsProvider);
    final selectedCalendarId = ref.read(selectedProductivityCalendarIdProvider);

    for (final action in pending) {
      // Tasks and reminders require a scheduled time on Android — skip
      // auto-creation if there's no date, the user can create manually.
      final requiresDate =
          action.actionType == ExtractedActionType.task ||
          action.actionType == ExtractedActionType.reminder;
      if (requiresDate && action.startTime == null && action.dueDate == null) {
        debugPrint(
          '[VoiceMemoProviders] Skipping auto-create for action ${action.id} '
          '(${action.actionType}) — no scheduled time',
        );
        continue;
      }
      try {
        final draft = ActionCreationDraft.fromAction(action).copyWith(
          platformCalendarId: Platform.isAndroid ? selectedCalendarId : null,
        );
        final message = await ops.createAction(action: action, draft: draft);
        debugPrint('[VoiceMemoProviders] Auto-created action: $message');
      } catch (e) {
        debugPrint(
          '[VoiceMemoProviders] Failed to auto-create action ${action.id}: $e',
        );
      }
    }
  } catch (e) {
    debugPrint('[VoiceMemoProviders] Auto-create actions error: $e');
  }
}

// ==================== Voice Memo List Provider ====================

/// Stream of all voice memos (reactive, newest first)
final voiceMemoListProvider = StreamProvider<List<VoiceMemo>>((ref) {
  final repository = ref.watch(voiceMemoRepositoryProvider);
  return repository.watchAllMemos();
});

/// Stream a single voice memo by database id.
final voiceMemoByIdProvider = StreamProvider.family<VoiceMemo?, int>((ref, id) {
  final repository = ref.watch(voiceMemoRepositoryProvider);
  return repository.watchAllMemos().map((memos) {
    for (final memo in memos) {
      if (memo.id == id) {
        return memo;
      }
    }
    return null;
  });
});

// ==================== Sync State Provider ====================

/// Stream of sync state updates
final voiceMemoSyncStateProvider = StreamProvider<VoiceMemoSyncState>((ref) {
  final service = ref.watch(voiceMemoSyncServiceProvider);
  return service.syncState;
});

// ==================== Voice Memo Actions ====================

enum VoiceMemoActionType { sync, delete, transcribe }

class VoiceMemoActionState {
  final bool isLoading;
  final VoiceMemoActionType? actionType;
  final String? activeFilename;
  final Object? error;

  const VoiceMemoActionState({
    required this.isLoading,
    this.actionType,
    this.activeFilename,
    this.error,
  });

  const VoiceMemoActionState.idle()
    : isLoading = false,
      actionType = null,
      activeFilename = null,
      error = null;

  const VoiceMemoActionState.loading({
    required this.actionType,
    this.activeFilename,
  }) : isLoading = true,
       error = null;

  const VoiceMemoActionState.error({
    required this.actionType,
    this.activeFilename,
    required this.error,
  }) : isLoading = false;

  bool isTranscribingMemo(String filename) {
    return isLoading &&
        actionType == VoiceMemoActionType.transcribe &&
        activeFilename == filename;
  }
}

/// Notifier for voice memo actions (sync, delete, transcribe)
class VoiceMemoActionsNotifier extends StateNotifier<VoiceMemoActionState> {
  final VoiceMemoSyncService _syncService;
  final VoiceMemoRepository _repository;
  final TranscriptionEngine _transcriptionEngine;

  VoiceMemoActionsNotifier({
    required VoiceMemoSyncService syncService,
    required VoiceMemoRepository repository,
    required TranscriptionEngine transcriptionEngine,
  }) : _syncService = syncService,
       _repository = repository,
       _transcriptionEngine = transcriptionEngine,
       super(const VoiceMemoActionState.idle());

  /// Trigger a sync of voice memos from the watch
  Future<void> sync() async {
    state = const VoiceMemoActionState.loading(
      actionType: VoiceMemoActionType.sync,
    );
    try {
      await _syncService.syncRecordings();
      state = const VoiceMemoActionState.idle();
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] Sync error: $e');
      debugPrint('$st');
      state = VoiceMemoActionState.error(
        actionType: VoiceMemoActionType.sync,
        error: e,
      );
    }
  }

  /// Delete a voice memo locally
  Future<void> delete(String filename) async {
    state = VoiceMemoActionState.loading(
      actionType: VoiceMemoActionType.delete,
      activeFilename: filename,
    );
    try {
      await _repository.deleteMemo(filename);
      state = const VoiceMemoActionState.idle();
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] Delete error: $e');
      debugPrint('$st');
      state = VoiceMemoActionState.error(
        actionType: VoiceMemoActionType.delete,
        activeFilename: filename,
        error: e,
      );
    }
  }

  /// Transcribe a single voice memo
  ///
  /// Uses the Ogg file (converted from .zsw_opus) as input.
  /// The FFmpeg converter registered at startup handles Ogg → WAV conversion
  /// for Whisper automatically.
  Future<void> transcribe(VoiceMemo memo) async {
    state = VoiceMemoActionState.loading(
      actionType: VoiceMemoActionType.transcribe,
      activeFilename: memo.filename,
    );
    try {
      await _transcribeMemo(memo);

      debugPrint('[VoiceMemoActions] Transcription saved for ${memo.filename}');
      state = const VoiceMemoActionState.idle();
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] Transcription error: $e');
      debugPrint('$st');
      state = VoiceMemoActionState.error(
        actionType: VoiceMemoActionType.transcribe,
        activeFilename: memo.filename,
        error: e,
      );
    }
  }

  /// Re-transcribe a memo using the currently selected transcription model.
  ///
  /// Existing transcription text is overwritten.
  Future<void> retranscribe(VoiceMemo memo) => transcribe(memo);

  /// Transcribe all synced but untranscribed memos
  Future<void> transcribeAll() async {
    state = const VoiceMemoActionState.loading(
      actionType: VoiceMemoActionType.transcribe,
    );
    try {
      final untranscribed = await _repository.getUntranscribedMemos();
      debugPrint(
        '[VoiceMemoActions] Transcribing ${untranscribed.length} memos',
      );

      for (final memo in untranscribed) {
        try {
          await transcribe(memo);
        } catch (e) {
          debugPrint(
            '[VoiceMemoActions] Failed to transcribe ${memo.filename}: $e',
          );
          // Continue with next memo
        }
      }
      state = const VoiceMemoActionState.idle();
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] TranscribeAll error: $e');
      debugPrint('$st');
      state = VoiceMemoActionState.error(
        actionType: VoiceMemoActionType.transcribe,
        error: e,
      );
    }
  }

  /// Re-transcribe all downloaded memos using the currently selected model.
  ///
  /// Returns the number of memos attempted.
  Future<int> retranscribeAll() async {
    state = const VoiceMemoActionState.loading(
      actionType: VoiceMemoActionType.transcribe,
    );
    try {
      final memos = await _repository.getTranscribableMemos();
      debugPrint('[VoiceMemoActions] Re-transcribing ${memos.length} memos');

      for (final memo in memos) {
        try {
          await _transcribeMemo(memo);
        } catch (e) {
          debugPrint(
            '[VoiceMemoActions] Failed to re-transcribe ${memo.filename}: $e',
          );
        }
      }

      state = const VoiceMemoActionState.idle();
      return memos.length;
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] RetranscribeAll error: $e');
      debugPrint('$st');
      state = VoiceMemoActionState.error(
        actionType: VoiceMemoActionType.transcribe,
        error: e,
      );
      rethrow;
    }
  }

  Future<void> _transcribeMemo(VoiceMemo memo) async {
    final audioPath = memo.convertedFilePath ?? memo.localFilePath;
    if (audioPath == null) {
      throw Exception('No audio file available for transcription');
    }

    debugPrint('[VoiceMemoActions] Transcribing: ${memo.filename}');
    final text = await _transcriptionEngine.transcribe(audioPath);

    await _repository.updateTranscription(
      filename: memo.filename,
      transcription: text.isEmpty ? '[No speech detected]' : text,
    );
  }
}

/// Provider for voice memo actions
final voiceMemoActionsProvider =
    StateNotifierProvider<VoiceMemoActionsNotifier, VoiceMemoActionState>((
      ref,
    ) {
      final syncService = ref.watch(voiceMemoSyncServiceProvider);
      final repository = ref.watch(voiceMemoRepositoryProvider);
      final transcriptionEngine = ref.watch(transcriptionEngineProvider);
      return VoiceMemoActionsNotifier(
        syncService: syncService,
        repository: repository,
        transcriptionEngine: transcriptionEngine,
      );
    });
