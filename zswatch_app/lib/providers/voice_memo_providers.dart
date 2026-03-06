import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/voice_memo.dart';
import '../data/repositories/voice_memo_repository.dart';
import '../services/voice_memo/transcription_engine.dart';
import '../services/voice_memo/voice_memo_sync_service.dart';
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
    FutureProvider.family<TranscriptionModelLocalStatus, TranscriptionEngineType>(
        (ref, type) async {
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
  final status = await ref.watch(transcriptionModelStatusProvider(selected).future);
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

  // Wire up auto-transcription after sync completes
  final engine = ref.watch(transcriptionEngineProvider);
  service.onSyncCompleted = (downloadedCount) {
    debugPrint(
        '[VoiceMemoProviders] Sync completed ($downloadedCount new). '
        'Starting auto-transcription.');
    _autoTranscribe(repository, engine);
  };

  ref.onDispose(() => service.dispose());
  return service;
});

/// Auto-transcribe all untranscribed memos after sync
Future<void> _autoTranscribe(
  VoiceMemoRepository repository,
  TranscriptionEngine engine,
) async {
  try {
    final untranscribed = await repository.getUntranscribedMemos();
    if (untranscribed.isEmpty) return;

    debugPrint(
        '[VoiceMemoProviders] Auto-transcribing ${untranscribed.length} memos');

    for (final memo in untranscribed) {
      try {
        final audioPath = memo.convertedFilePath ?? memo.localFilePath;
        if (audioPath == null) continue;

        final text = await engine.transcribe(audioPath);
        await repository.updateTranscription(
          filename: memo.filename,
          transcription: text.isEmpty ? '[No speech detected]' : text,
        );
        debugPrint(
            '[VoiceMemoProviders] Auto-transcribed: ${memo.filename}');
      } catch (e) {
        debugPrint(
            '[VoiceMemoProviders] Failed to transcribe ${memo.filename}: $e');
      }
    }
  } catch (e) {
    debugPrint('[VoiceMemoProviders] Auto-transcription error: $e');
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

/// Notifier for voice memo actions (sync, delete, transcribe)
class VoiceMemoActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final VoiceMemoSyncService _syncService;
  final VoiceMemoRepository _repository;
  final TranscriptionEngine _transcriptionEngine;

  VoiceMemoActionsNotifier({
    required VoiceMemoSyncService syncService,
    required VoiceMemoRepository repository,
    required TranscriptionEngine transcriptionEngine,
  })  : _syncService = syncService,
        _repository = repository,
        _transcriptionEngine = transcriptionEngine,
        super(const AsyncData(null));

  /// Trigger a sync of voice memos from the watch
  Future<void> sync() async {
    state = const AsyncLoading();
    try {
      await _syncService.syncRecordings();
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] Sync error: $e');
      state = AsyncError(e, st);
    }
  }

  /// Delete a voice memo locally
  Future<void> delete(String filename) async {
    state = const AsyncLoading();
    try {
      await _repository.deleteMemo(filename);
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] Delete error: $e');
      state = AsyncError(e, st);
    }
  }

  /// Transcribe a single voice memo
  ///
  /// Uses the Ogg file (converted from .zsw_opus) as input.
  /// The FFmpeg converter registered at startup handles Ogg → WAV conversion
  /// for Whisper automatically.
  Future<void> transcribe(VoiceMemo memo) async {
    state = const AsyncLoading();
    try {
      await _transcribeMemo(memo);

      debugPrint('[VoiceMemoActions] Transcription saved for ${memo.filename}');
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] Transcription error: $e');
      state = AsyncError(e, st);
    }
  }

  /// Re-transcribe a memo using the currently selected transcription model.
  ///
  /// Existing transcription text is overwritten.
  Future<void> retranscribe(VoiceMemo memo) => transcribe(memo);

  /// Transcribe all synced but untranscribed memos
  Future<void> transcribeAll() async {
    state = const AsyncLoading();
    try {
      final untranscribed = await _repository.getUntranscribedMemos();
      debugPrint(
          '[VoiceMemoActions] Transcribing ${untranscribed.length} memos');

      for (final memo in untranscribed) {
        try {
          await transcribe(memo);
        } catch (e) {
          debugPrint(
              '[VoiceMemoActions] Failed to transcribe ${memo.filename}: $e');
          // Continue with next memo
        }
      }
      state = const AsyncData(null);
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] TranscribeAll error: $e');
      state = AsyncError(e, st);
    }
  }

  /// Re-transcribe all downloaded memos using the currently selected model.
  ///
  /// Returns the number of memos attempted.
  Future<int> retranscribeAll() async {
    state = const AsyncLoading();
    try {
      final memos = await _repository.getTranscribableMemos();
      debugPrint(
          '[VoiceMemoActions] Re-transcribing ${memos.length} memos');

      for (final memo in memos) {
        try {
          await _transcribeMemo(memo);
        } catch (e) {
          debugPrint(
              '[VoiceMemoActions] Failed to re-transcribe ${memo.filename}: $e');
        }
      }

      state = const AsyncData(null);
      return memos.length;
    } catch (e, st) {
      debugPrint('[VoiceMemoActions] RetranscribeAll error: $e');
      state = AsyncError(e, st);
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
    StateNotifierProvider<VoiceMemoActionsNotifier, AsyncValue<void>>((ref) {
  final syncService = ref.watch(voiceMemoSyncServiceProvider);
  final repository = ref.watch(voiceMemoRepositoryProvider);
  final transcriptionEngine = ref.watch(transcriptionEngineProvider);
  return VoiceMemoActionsNotifier(
    syncService: syncService,
    repository: repository,
    transcriptionEngine: transcriptionEngine,
  );
});
