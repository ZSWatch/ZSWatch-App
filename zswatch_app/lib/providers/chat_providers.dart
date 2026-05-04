import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_history_entry.dart';
import '../services/chat/watch_chat_service.dart';
import '../services/tts/tts_service.dart';
import 'ai_providers.dart';
import 'settings_providers.dart';
import 'voice_memo_providers.dart';
import 'watch_providers.dart';
import 'watch_service_provider.dart';

// ---------------------------------------------------------------------------
// TTS service
// ---------------------------------------------------------------------------

/// Singleton TTS service for platform text-to-speech.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Observable TTS status stream.
final ttsStatusProvider = StreamProvider<TtsStatus>((ref) {
  final service = ref.watch(ttsServiceProvider);
  return service.statusStream;
});

// ---------------------------------------------------------------------------
// Chat service
// ---------------------------------------------------------------------------

/// Singleton chat orchestration service.
final watchChatServiceProvider = Provider<WatchChatService>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  final transcriptionEngine = ref.watch(transcriptionEngineProvider);
  final llmService = ref.watch(llmServiceProvider);
  final ttsService = ref.watch(ttsServiceProvider);
  final database = ref.watch(databaseProvider);

  final service = WatchChatService(
    watchService: watchService,
    transcriptionEngine: transcriptionEngine,
    llmService: llmService,
    ttsService: ttsService,
    database: database,
  );

  // Wire settings reactively
  ref.listen<String>(chatAnswerLengthProvider, (_, next) {
    service.answerLength = next;
  });
  ref.listen<String>(chatMemoryModeProvider, (_, next) {
    service.memoryMode = next;
  });
  ref.listen<int>(chatMaxHistoryProvider, (_, next) {
    service.maxHistoryEntries = next;
  });

  // Apply current settings
  service.answerLength = ref.read(chatAnswerLengthProvider);
  service.memoryMode = ref.read(chatMemoryModeProvider);
  service.maxHistoryEntries = ref.read(chatMaxHistoryProvider);

  ref.onDispose(() => service.dispose());
  return service;
});

/// Observable chat state stream.
final watchChatStateProvider = StreamProvider<WatchChatState>((ref) {
  final service = ref.watch(watchChatServiceProvider);
  return service.stateStream;
});

// ---------------------------------------------------------------------------
// Chat history
// ---------------------------------------------------------------------------

/// Stream of all chat history entries (newest first).
final chatHistoryProvider = StreamProvider<List<ChatHistoryEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllChatHistory().map(
        (rows) => rows
            .map(
              (row) => ChatHistoryEntry(
                id: row.id,
                timestampUtc: DateTime.fromMillisecondsSinceEpoch(
                  row.timestampUtc * 1000,
                  isUtc: true,
                ),
                transcript: row.transcript,
                answer: row.answer,
                modelUsed: row.modelUsed,
                latencyMs: row.latencyMs,
                success: row.success,
                errorMessage: row.errorMessage,
              ),
            )
            .toList(),
      );
});
