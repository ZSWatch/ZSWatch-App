import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/database/app_database.dart';
import '../ai/llm_service.dart';
import '../tts/tts_service.dart';
import '../voice_memo/ogg_opus_writer.dart';
import '../voice_memo/transcription_engine.dart';
import '../voice_memo/zsw_opus_parser.dart';
import '../watch_service.dart';

/// Chat session phase visible to the watch.
enum ChatPhase {
  idle,
  receivingAudio,
  transcribing,
  thinking,
  generatingTts,
  uploadingReply,
  waitingPlayback,
  completed,
  error,
}

/// Observable state of the chat service.
class WatchChatState {
  final ChatPhase phase;
  final int? sessionId;
  final String? transcript;
  final String? answer;
  final String? error;

  const WatchChatState({
    this.phase = ChatPhase.idle,
    this.sessionId,
    this.transcript,
    this.answer,
    this.error,
  });

  WatchChatState copyWith({
    ChatPhase? phase,
    int? sessionId,
    String? transcript,
    String? answer,
    String? error,
  }) {
    return WatchChatState(
      phase: phase ?? this.phase,
      sessionId: sessionId ?? this.sessionId,
      transcript: transcript ?? this.transcript,
      answer: answer ?? this.answer,
      error: error ?? this.error,
    );
  }
}

/// Orchestrates the full voice chat pipeline:
///
/// 1. Watch saves question audio to filesystem, sends notification
/// 2. Phone downloads question WAV via MCUmgr FS
/// 3. Transcribe locally
/// 4. Run LLM to generate answer
/// 5. Synthesize TTS
/// 6. Upload reply WAV to watch via MCUmgr FS
/// 7. Signal watch to play
class WatchChatService {
  static const _watchReplyPath = '/user/chat/reply_current.wav';

  final WatchService _watchService;
  final TranscriptionEngine _transcriptionEngine;
  final LlmService _llmService;
  final TtsService _ttsService;
  final AppDatabase _database;

  /// Chat answer length preference: 'ultra_short', 'short', 'normal'
  String answerLength = 'short';

  /// Memory mode: 'single_turn', 'last_exchange', 'short_history'
  String memoryMode = 'single_turn';

  /// Max history entries to use for context
  int maxHistoryEntries = 5;

  final _stateController = BehaviorSubject<WatchChatState>.seeded(
    const WatchChatState(),
  );
  Stream<WatchChatState> get stateStream => _stateController.stream;
  WatchChatState get state => _stateController.value;

  int? _activeSessionId;
  String? _activeQuestionKey;
  bool _cancelled = false;
  Stopwatch? _latencyStopwatch;

  /// MCUmgr FS manager for file transfers
  FsManager? _fsManager;
  StreamSubscription<dynamic>? _transferSubscription;
  Completer<Uint8List?>? _downloadCompleter;
  Completer<bool>? _uploadCompleter;

  WatchChatService({
    required WatchService watchService,
    required TranscriptionEngine transcriptionEngine,
    required LlmService llmService,
    required TtsService ttsService,
    required AppDatabase database,
  }) : _watchService = watchService,
       _transcriptionEngine = transcriptionEngine,
       _llmService = llmService,
       _ttsService = ttsService,
       _database = database {
    debugPrint(
      '[WatchChatService] Created, subscribing to chat messages '
      '(watchService=${_watchService.hashCode})',
    );
    _watchService.onChatMessage = _handleChatMessage;
  }

  void _handleChatMessage(Map<String, dynamic> message) {
    final action = message['action'] as String?;
    debugPrint('[WatchChatService] Received chat action: $action');

    switch (action) {
      case 'question_ready':
        unawaited(_handleQuestionReady(message));
        break;
      case 'cancel':
        _handleCancel(message);
        break;
      case 'playback_done':
        _handlePlaybackDone(message);
        break;
      default:
        debugPrint('[WatchChatService] Unknown chat action: $action');
    }
  }

  Future<void> _handleQuestionReady(Map<String, dynamic> message) async {
    final sessionId = (message['session_id'] as num?)?.toInt() ?? 0;
    final remotePath = message['path'] as String?;
    final codec = message['codec'] as String? ?? 'opus_zsw';
    final sizeBytes = (message['size_bytes'] as num?)?.toInt() ?? 0;
    final sampleRate = (message['sample_rate'] as num?)?.toInt() ?? 16000;
    final durationMs = (message['duration_ms'] as num?)?.toInt() ?? 0;

    if (remotePath == null || remotePath.isEmpty) {
      debugPrint('[WatchChatService] No path in question_ready');
      _sendError(sessionId, 'No audio path');
      return;
    }

    final questionKey = '$sessionId:$remotePath';
    if (_activeQuestionKey == questionKey) {
      debugPrint(
        '[WatchChatService] Ignoring duplicate question_ready for $questionKey',
      );
      return;
    }

    _activeSessionId = sessionId;
    _activeQuestionKey = questionKey;
    _cancelled = false;
    _latencyStopwatch = Stopwatch()..start();

    debugPrint(
      '[WatchChatService] Question ready: session=$sessionId, '
      'path=$remotePath, size=$sizeBytes, duration=${durationMs}ms',
    );

    try {
      // Download question audio from watch via MCUmgr FS
      _updateState(ChatPhase.receivingAudio, sessionId);

      final audioData = await _downloadFileFromWatch(remotePath, sizeBytes);
      if (audioData == null) {
        _sendError(sessionId, 'Failed to download audio');
        return;
      }

      if (_cancelled) return;

      debugPrint(
        '[WatchChatService] Downloaded question: ${audioData.length} bytes '
        '(codec=$codec)',
      );

      final localAudioPath = await _prepareQuestionAudioForTranscription(
        sessionId: sessionId,
        codec: codec,
        audioData: audioData,
      );
      if (localAudioPath == null) {
        _sendError(sessionId, 'Unsupported question audio');
        return;
      }

      // Transcribe
      _updateState(ChatPhase.transcribing, sessionId);
      await _sendStateToWatch(sessionId, 2); // ZSW_CHAT_STATE_TRANSCRIBING

      final transcript = await _transcriptionEngine.transcribe(localAudioPath);
      if (transcript.trim().isEmpty) {
        _sendError(sessionId, 'Could not understand audio');
        return;
      }

      debugPrint('[WatchChatService] Transcript: $transcript');
      _updateState(ChatPhase.thinking, sessionId, transcript: transcript);

      // Send transcript preview to watch
      await _sendTranscriptToWatch(sessionId, transcript);
      await _sendStateToWatch(sessionId, 3); // ZSW_CHAT_STATE_THINKING

      if (_cancelled) return;

      // Build history context
      final history = await _buildHistory();

      // Generate LLM reply
      final result = await _llmService.generateChatReply(
        transcript,
        history: history,
        answerLength: answerLength,
      );

      final answer = result.text.trim();
      debugPrint('[WatchChatService] Answer: $answer');
      _updateState(
        ChatPhase.generatingTts,
        sessionId,
        transcript: transcript,
        answer: answer,
      );
      await _sendStateToWatch(sessionId, 4); // ZSW_CHAT_STATE_GENERATING_TTS

      if (_cancelled) return;

      // Synthesize TTS — detect language from transcript (what the user said)
      // so TTS matches the spoken language rather than guessing from the answer.
      final ttsLanguage = TtsService.detectLanguage(transcript);
      debugPrint('[WatchChatService] TTS language: $ttsLanguage');
      final ttsPath = await _ttsService.synthesizeToFile(
        answer,
        language: ttsLanguage,
      );
      if (ttsPath == null) {
        _sendError(sessionId, 'TTS synthesis failed');
        return;
      }

      if (_cancelled) return;

      // Upload reply to watch via MCUmgr FS
      _updateState(
        ChatPhase.uploadingReply,
        sessionId,
        transcript: transcript,
        answer: answer,
      );
      await _sendStateToWatch(sessionId, 5); // ZSW_CHAT_STATE_UPLOADING_REPLY

      final uploaded = await _uploadFileToWatch(ttsPath, _watchReplyPath);
      if (!uploaded) {
        _sendError(sessionId, 'Reply upload failed');
        return;
      }

      if (_cancelled) return;

      // Signal watch that reply is ready
      await _sendReplyReadyToWatch(
        sessionId,
        _watchReplyPath,
        'pcm_wav',
        sampleRate,
      );

      _updateState(
        ChatPhase.waitingPlayback,
        sessionId,
        transcript: transcript,
        answer: answer,
      );

      // Record latency
      final latencyMs = _latencyStopwatch?.elapsedMilliseconds;

      // Save to history
      await _database.insertChatHistoryEntry(
        ChatHistoryCompanion.insert(
          timestampUtc: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
          transcript: transcript,
          answer: Value(answer),
          modelUsed: Value((await _llmService.currentModelInfo()).displayName),
          latencyMs: Value(latencyMs),
        ),
      );

      // Clean up local temp files
      try {
        await File(localAudioPath).delete();
      } catch (_) {}
      try {
        if (ttsPath.isNotEmpty) await File(ttsPath).delete();
      } catch (_) {}
    } catch (e, stack) {
      debugPrint('[WatchChatService] Pipeline error: $e\n$stack');
      _sendError(sessionId, 'Processing failed');
    }
  }

  void _handleCancel(Map<String, dynamic> message) {
    final sessionId = (message['session_id'] as num?)?.toInt() ?? 0;
    debugPrint('[WatchChatService] Cancel received for session $sessionId');
    if (_activeSessionId != null && _activeSessionId != sessionId) {
      debugPrint('[WatchChatService] Ignoring stale cancel for $sessionId');
      return;
    }
    _cancelled = true;
    _activeSessionId = null;
    _activeQuestionKey = null;
    _llmService.cancelInference();
    _ttsService.stop();
    unawaited(_resetFsManager());
    _updateState(ChatPhase.idle, sessionId);
  }

  void _handlePlaybackDone(Map<String, dynamic> message) {
    final sessionId = (message['session_id'] as num?)?.toInt() ?? 0;
    debugPrint('[WatchChatService] Playback done for session $sessionId');
    if (_activeSessionId != null && _activeSessionId != sessionId) {
      debugPrint(
        '[WatchChatService] Ignoring stale playback_done for $sessionId',
      );
      return;
    }
    _activeSessionId = null;
    _activeQuestionKey = null;
    _latencyStopwatch?.stop();
    _updateState(ChatPhase.completed, sessionId);

    // Return to idle after a brief moment
    Future.delayed(const Duration(seconds: 1), () {
      if (state.phase == ChatPhase.completed) {
        _updateState(ChatPhase.idle, null);
      }
    });
  }

  void _updateState(
    ChatPhase phase,
    int? sessionId, {
    String? transcript,
    String? answer,
    String? error,
  }) {
    _stateController.add(
      state.copyWith(
        phase: phase,
        sessionId: sessionId,
        transcript: transcript ?? state.transcript,
        answer: answer ?? state.answer,
        error: error,
      ),
    );
  }

  /// Send a state update to the watch via NUS
  Future<void> _sendStateToWatch(int sessionId, int stateValue) async {
    await _watchService.sendChatCommand(
      'state',
      extraData: {'session_id': sessionId, 'state': stateValue},
    );
  }

  /// Send the recognized transcript back to the watch
  Future<void> _sendTranscriptToWatch(int sessionId, String transcript) async {
    await _watchService.sendChatCommand(
      'transcript',
      extraData: {'session_id': sessionId, 'text': transcript},
    );
  }

  /// Send error to the watch
  void _sendError(int sessionId, String message) {
    _activeQuestionKey = null;
    _updateState(ChatPhase.error, sessionId, error: message);
    unawaited(
      _watchService.sendChatCommand(
        'error',
        extraData: {'session_id': sessionId, 'message': message},
      ),
    );

    // Save failed entry to history
    unawaited(
      _database.insertChatHistoryEntry(
        ChatHistoryCompanion.insert(
          timestampUtc: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
          transcript: state.transcript ?? '(unknown)',
          success: const Value(false),
          errorMessage: Value(message),
        ),
      ),
    );
  }

  /// Signal that the reply file is ready for playback
  Future<void> _sendReplyReadyToWatch(
    int sessionId,
    String path,
    String codec,
    int sampleRate,
  ) async {
    await _watchService.sendChatCommand(
      'reply_ready',
      extraData: {
        'session_id': sessionId,
        'path': path,
        'codec': codec,
        'sample_rate': sampleRate,
      },
    );
  }

  Future<String?> _prepareQuestionAudioForTranscription({
    required int sessionId,
    required String codec,
    required Uint8List audioData,
  }) async {
    final tempDir = await getTemporaryDirectory();

    if (codec == 'opus_zsw') {
      final parsed = ZswOpusParser.parse(audioData);
      if (parsed == null || !parsed.isValid) {
        debugPrint('[WatchChatService] Invalid .zsw_opus question payload');
        return null;
      }

      final oggData = OggOpusWriter.convert(parsed);
      final localOggPath = '${tempDir.path}/chat_question_$sessionId.ogg';
      await File(localOggPath).writeAsBytes(oggData);
      debugPrint(
        '[WatchChatService] Prepared Ogg question: $localOggPath '
        '(${oggData.length} bytes)',
      );
      return localOggPath;
    }

    if (codec == 'pcm_wav' || codec == 'wav') {
      final localWavPath = '${tempDir.path}/chat_question_$sessionId.wav';
      await File(localWavPath).writeAsBytes(audioData);
      debugPrint('[WatchChatService] Prepared WAV question: $localWavPath');
      return localWavPath;
    }

    debugPrint('[WatchChatService] Unsupported question codec: $codec');
    return null;
  }

  /// Download a file from the watch via MCUmgr FS.
  ///
  /// Follows the same pattern as VoiceMemoSyncService: enable SMP,
  /// create FsManager, download, cleanup.
  Future<Uint8List?> _downloadFileFromWatch(
    String remotePath,
    int expectedSize,
  ) async {
    final smpGen = _watchService.connectionGeneration;
    await _watchService.enableSmp();

    // Give watch time to register SMP service
    await Future<void>.delayed(const Duration(seconds: 2));
    await _watchService.rediscoverServices();

    try {
      final device = _watchService.device;
      if (device == null) {
        debugPrint('[WatchChatService] No device connected for download');
        return null;
      }

      await _resetFsManager();
      _fsManager = FsManager(device.remoteId.str);

      _downloadCompleter = Completer<Uint8List?>();
      await _transferSubscription?.cancel();
      _transferSubscription = _fsManager!.downloadCallbacks.listen(
        (callback) {
          switch (callback) {
            case OnDownloadProgressChanged():
              debugPrint(
                '[WatchChatService] Download: '
                '${callback.current}/${callback.total}',
              );
            case OnDownloadCompleted():
              _downloadCompleter?.complete(callback.data);
              _downloadCompleter = null;
            case OnDownloadFailed():
              debugPrint(
                '[WatchChatService] Download failed: ${callback.cause}',
              );
              _downloadCompleter?.complete(null);
              _downloadCompleter = null;
            case OnDownloadCancelled():
              debugPrint('[WatchChatService] Download cancelled');
              _downloadCompleter?.complete(null);
              _downloadCompleter = null;
          }
        },
        onError: (Object error) {
          debugPrint('[WatchChatService] Download error: $error');
          _downloadCompleter?.complete(null);
          _downloadCompleter = null;
        },
      );

      await _fsManager!.download(remotePath);

      final data = await _downloadCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          debugPrint('[WatchChatService] Download timed out');
          return null;
        },
      );

      return data;
    } finally {
      await _resetFsManager();
      try {
        await _watchService.disableSmpIfConnectionUnchanged(smpGen);
      } catch (e) {
        debugPrint('[WatchChatService] Failed to disable SMP: $e');
      }
    }
  }

  /// Upload a local file to the watch via MCUmgr FS.
  ///
  /// Uses the same FsManager upload pattern as FilesystemUploadService.
  Future<bool> _uploadFileToWatch(String localPath, String remotePath) async {
    final smpGen = _watchService.connectionGeneration;
    await _watchService.enableSmp();

    // Give watch time to register SMP service
    await Future<void>.delayed(const Duration(seconds: 2));
    await _watchService.rediscoverServices();

    try {
      final device = _watchService.device;
      if (device == null) {
        debugPrint('[WatchChatService] No device connected for upload');
        return false;
      }

      final file = File(localPath);
      if (!file.existsSync()) {
        debugPrint('[WatchChatService] Local file not found: $localPath');
        return false;
      }

      final data = await file.readAsBytes();
      debugPrint(
        '[WatchChatService] Uploading reply: ${data.length} bytes '
        'to $remotePath',
      );

      await _resetFsManager();
      _fsManager = FsManager(device.remoteId.str);

      _uploadCompleter = Completer<bool>();
      await _transferSubscription?.cancel();
      _transferSubscription = _fsManager!.uploadCallbacks.listen(
        (callback) {
          switch (callback) {
            case OnUploadProgressChanged():
              debugPrint(
                '[WatchChatService] Upload: '
                '${callback.current}/${callback.total}',
              );
            case OnUploadCompleted():
              _uploadCompleter?.complete(true);
              _uploadCompleter = null;
            case OnUploadFailed():
              debugPrint('[WatchChatService] Upload failed: ${callback.cause}');
              _uploadCompleter?.complete(false);
              _uploadCompleter = null;
            case OnUploadCancelled():
              debugPrint('[WatchChatService] Upload cancelled');
              _uploadCompleter?.complete(false);
              _uploadCompleter = null;
          }
        },
        onError: (Object error) {
          debugPrint('[WatchChatService] Upload error: $error');
          _uploadCompleter?.complete(false);
          _uploadCompleter = null;
        },
      );

      await _fsManager!.upload(remotePath, data);

      final success = await _uploadCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          debugPrint('[WatchChatService] Upload timed out');
          return false;
        },
      );

      return success;
    } finally {
      await _resetFsManager();
      try {
        await _watchService.disableSmpIfConnectionUnchanged(smpGen);
      } catch (e) {
        debugPrint('[WatchChatService] Failed to disable SMP: $e');
      }
    }
  }

  /// Clean up FsManager and transfer subscriptions.
  Future<void> _resetFsManager() async {
    await _transferSubscription?.cancel();
    _transferSubscription = null;
    _downloadCompleter?.complete(null);
    _downloadCompleter = null;
    _uploadCompleter?.complete(false);
    _uploadCompleter = null;
    final manager = _fsManager;
    _fsManager = null;
    if (manager != null) {
      try {
        await manager.kill();
      } catch (e) {
        debugPrint('[WatchChatService] FsManager cleanup failed: $e');
      }
    }
  }

  /// Build conversation history for context based on memory mode setting.
  Future<List<({String question, String answer})>?> _buildHistory() async {
    if (memoryMode == 'single_turn') return null;

    final limit = memoryMode == 'last_exchange' ? 1 : maxHistoryEntries;
    final entries = await _database.getRecentChatHistory(limit);

    return entries
        .where((e) => e.success && e.answer != null)
        .map((e) => (question: e.transcript, answer: e.answer!))
        .toList()
        .reversed
        .toList();
  }

  void dispose() {
    if (_watchService.onChatMessage == _handleChatMessage) {
      _watchService.onChatMessage = null;
    }
    unawaited(_resetFsManager());
    _stateController.close();
  }
}
