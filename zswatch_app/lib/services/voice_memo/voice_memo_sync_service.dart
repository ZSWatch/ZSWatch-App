import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/models/connection.dart';
import '../../data/models/voice_memo.dart';
import '../../data/repositories/voice_memo_repository.dart';
import '../watch_service.dart';
import 'ogg_opus_writer.dart';
import 'zsw_opus_parser.dart';

/// State of the voice memo sync process
enum VoiceMemoSyncPhase {
  idle,
  fetchingList,
  downloading,
  verifying,
  deleting,
  completed,
  failed,
}

/// Current sync state
class VoiceMemoSyncState {
  final VoiceMemoSyncPhase phase;
  final String? currentFilename;
  final int totalToSync;
  final int completedCount;
  final double downloadProgress; // 0.0 - 1.0
  final String? errorMessage;

  const VoiceMemoSyncState({
    this.phase = VoiceMemoSyncPhase.idle,
    this.currentFilename,
    this.totalToSync = 0,
    this.completedCount = 0,
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  VoiceMemoSyncState copyWith({
    VoiceMemoSyncPhase? phase,
    String? currentFilename,
    int? totalToSync,
    int? completedCount,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return VoiceMemoSyncState(
      phase: phase ?? this.phase,
      currentFilename: currentFilename ?? this.currentFilename,
      totalToSync: totalToSync ?? this.totalToSync,
      completedCount: completedCount ?? this.completedCount,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isSyncing =>
      phase != VoiceMemoSyncPhase.idle &&
      phase != VoiceMemoSyncPhase.completed &&
      phase != VoiceMemoSyncPhase.failed;
}

/// Recording metadata from watch list response
class WatchRecordingInfo {
  final String filename;
  final int durationMs;
  final int sizeBytes;
  final int timestamp;

  const WatchRecordingInfo({
    required this.filename,
    required this.durationMs,
    required this.sizeBytes,
    required this.timestamp,
  });

  factory WatchRecordingInfo.fromJson(Map<String, dynamic> json) {
    return WatchRecordingInfo(
      filename: json['filename'] as String,
      durationMs: json['duration_ms'] as int,
      sizeBytes: json['size_bytes'] as int,
      timestamp: json['timestamp'] as int,
    );
  }
}

/// Service for syncing voice memos from ZSWatch via MCUmgr FS
///
/// Uses a hybrid protocol:
/// - Extended API (JSON over NUS) for metadata (list, delete, new notification)
/// - MCUmgr FS for actual binary file download
///
/// Sync flow:
/// 1. Request recording list from watch
/// 2. For each new recording, download via MCUmgr FS
/// 3. Verify downloaded file (size check + header validation)
/// 4. Send delete command to watch after successful verification
class VoiceMemoSyncService {
  static const String _recordingDir = '/user/recordings';

  final WatchService _watchService;
  final VoiceMemoRepository _repository;

  /// Called after sync completes with the number of newly downloaded memos.
  /// Used to trigger auto-transcription from the provider layer.
  Future<void> Function(int downloadedCount)? onSyncCompleted;

  final _syncState = BehaviorSubject<VoiceMemoSyncState>.seeded(
    const VoiceMemoSyncState(),
  );

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Connection>? _connectionSubscription;
  StreamSubscription<DownloadCallback>? _downloadSubscription;
  FsManager? _fsManager;
  Completer<List<WatchRecordingInfo>>? _listCompleter;
  Completer<Uint8List?>? _downloadCompleter;
  bool _hasAutoSynced = false;

  VoiceMemoSyncService({
    required WatchService watchService,
    required VoiceMemoRepository repository,
  })  : _watchService = watchService,
        _repository = repository {
    _messageSubscription = _watchService.incomingMessages.listen(_handleMessage);
    _connectionSubscription = _watchService.connectionStream.listen(_handleConnectionChange);
  }

  void _handleConnectionChange(Connection connection) {
    if (connection.isConnected && !_hasAutoSynced) {
      _hasAutoSynced = true;
      // Delay slightly to allow BLE services to settle
      Future.delayed(const Duration(seconds: 3), () {
        _log('Auto-syncing voice memos on watch connect');
        syncRecordings();
      });
    } else if (connection.isDisconnected) {
      _hasAutoSynced = false;
      unawaited(_resetFsManager());
    }
  }

  /// Stream of sync state changes
  Stream<VoiceMemoSyncState> get syncState => _syncState.stream;

  /// Current sync state
  VoiceMemoSyncState get currentState => _syncState.value;

  /// Handle a new recording notification from the watch
  Future<void> handleNewRecording(Map<String, dynamic> message) async {
    final info = WatchRecordingInfo.fromJson(message);
    await _repository.upsertFromWatch(
      filename: info.filename,
      timestampUtc: info.timestamp,
      durationMs: info.durationMs,
      sizeBytes: info.sizeBytes,
    );
    _log('New recording notification: ${info.filename}');

    // Auto-download the new recording
    if (_watchService.isConnected && !currentState.isSyncing) {
      _log('Auto-downloading new recording: ${info.filename}');
      unawaited(syncRecordings());
    }
  }

  /// Handle recording list response from the watch
  Future<void> handleListResult(Map<String, dynamic> message) async {
    // Guard against duplicate BLE notifications — FBP can deliver the same
    // NUS RX packet twice. Grab and null the completer synchronously (before
    // the first await) so any second call finds null and exits immediately.
    if (_listCompleter == null) return;
    final completer = _listCompleter!;
    _listCompleter = null;

    final recordings = (message['recordings'] as List<dynamic>?)
            ?.map((r) => WatchRecordingInfo.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    _log('Received ${recordings.length} recordings from watch');

    // Update database with watch recordings
    try {
      for (final rec in recordings) {
        await _repository.upsertFromWatch(
          filename: rec.filename,
          timestampUtc: rec.timestamp,
          durationMs: rec.durationMs,
          sizeBytes: rec.sizeBytes,
        );
      }
    } catch (e) {
      _log('Error upserting recordings to DB: $e');
    }

    completer.complete(recordings);
  }

  /// Request recording list from the watch and sync new recordings
  Future<void> syncRecordings() async {
    if (currentState.isSyncing) {
      _log('Sync already in progress, skipping');
      return;
    }

    if (!_watchService.isConnected) {
      _log('Not connected, cannot sync');
      return;
    }

    try {
      _updateState(const VoiceMemoSyncState(
        phase: VoiceMemoSyncPhase.fetchingList,
      ));

      // Request recording list from watch
      await _watchService.sendVoiceMemoCommand('list');

      // Wait for list response (with timeout)
      _listCompleter = Completer<List<WatchRecordingInfo>>();
      final recordings = await _listCompleter!.future
          .timeout(const Duration(seconds: 10), onTimeout: () {
        _log('List request timed out');
        return <WatchRecordingInfo>[];
      });
      _log('Fetched ${recordings.length} recordings from list');

      // Find recordings not yet downloaded
      final undownloaded = await _repository.getUndownloadedMemos();
      if (undownloaded.isEmpty) {
        _log('All recordings already synced');
        _updateState(const VoiceMemoSyncState(
          phase: VoiceMemoSyncPhase.completed,
        ));
        _resetStateAfterDelay();
        return;
      }

      _updateState(VoiceMemoSyncState(
        phase: VoiceMemoSyncPhase.downloading,
        totalToSync: undownloaded.length,
        completedCount: 0,
      ));

      // Enable SMP server on the watch (required for MCUmgr file transfers)
      _log('Enabling SMP server for file download');
      await _watchService.enableSmp();
      // Give the watch time to register the SMP transport before rediscovering.
      await Future<void>.delayed(const Duration(seconds: 2));
      final smpReady = await _watchService.rediscoverServices();
      if (!smpReady) {
        throw Exception(
          'SMP service did not become available after enabling it on the watch',
        );
      }

      // Download each new recording
      int completed = 0;
      try {
        for (final memo in undownloaded) {
          _updateState(currentState.copyWith(
            currentFilename: memo.filename,
            downloadProgress: 0.0,
          ));

          final success = await _downloadRecording(memo);
          if (success) {
            completed++;
            _updateState(currentState.copyWith(
              completedCount: completed,
            ));
          }
        }
      } finally {
        // Always disable SMP server when done, even on error
        _log('Disabling SMP server');
        try {
          await _watchService.disableSmp();
        } catch (e) {
          _log('Failed to disable SMP: $e');
        }
        await _resetFsManager();
      }

      _updateState(VoiceMemoSyncState(
        phase: VoiceMemoSyncPhase.completed,
        totalToSync: undownloaded.length,
        completedCount: completed,
      ));

      // Notify listeners that new memos were downloaded (triggers auto-transcribe)
      if (completed > 0) {
        await onSyncCompleted?.call(completed);
      }
    } catch (e) {
      _log('Sync failed: $e');
      _updateState(VoiceMemoSyncState(
        phase: VoiceMemoSyncPhase.failed,
        errorMessage: e.toString(),
      ));
    }

    _resetStateAfterDelay();
  }

  /// Download a specific recording from the watch via MCUmgr FS
  Future<bool> _downloadRecording(VoiceMemo memo) async {
    try {
      // Initialize FsManager if needed
      final device = _watchService.device;
      if (device == null) {
        _log('No device connected');
        return false;
      }

      // Recreate FsManager for each transfer attempt to avoid stale native
      // transport handles after SMP disable/enable or reconnection cycles.
      await _resetFsManager();
      _fsManager = FsManager(device.remoteId.str);

      final remotePath = '$_recordingDir/${memo.filename}.zsw_opus';
      _log('Downloading: $remotePath');

      // Preflight check to distinguish path/FS errors from transfer errors.
      try {
        final remoteSize = await _fsManager!.status(remotePath);
        _log('Remote file status: $remoteSize bytes');
      } catch (e) {
        _log('Remote file status check failed: $e');
      }

      // Set up download completion listener
      _downloadCompleter = Completer<Uint8List?>();
      await _downloadSubscription?.cancel();
      _downloadSubscription = _fsManager!.downloadCallbacks.listen((callback) {
        switch (callback) {
          case OnDownloadProgressChanged():
            final progress = callback.total > 0
                ? callback.current / callback.total
                : 0.0;
            _updateState(currentState.copyWith(downloadProgress: progress));
          case OnDownloadCompleted():
            _downloadCompleter?.complete(callback.data);
            _downloadCompleter = null;
          case OnDownloadFailed():
            _log('Download failed: ${callback.cause}');
            _downloadCompleter?.complete(null);
            _downloadCompleter = null;
          case OnDownloadCancelled():
            _log('Download cancelled');
            _downloadCompleter?.complete(null);
            _downloadCompleter = null;
        }
      }, onError: (Object error) {
        _log('Download callback stream error: $error');
        _downloadCompleter?.complete(null);
        _downloadCompleter = null;
      });

      // Start download
      await _fsManager!.download(remotePath);

      // Wait for completion
      final data = await _downloadCompleter!.future
          .timeout(const Duration(minutes: 5), onTimeout: () {
        _log('Download timed out');
        return null;
      });

      if (data == null) {
        _log('Download returned no data');
        return false;
      }

      // Verify download
      _updateState(currentState.copyWith(
        phase: VoiceMemoSyncPhase.verifying,
      ));

      if (!ZswOpusParser.validateDownload(data,
          expectedSizeBytes: memo.sizeBytes)) {
        _log('Download verification failed for ${memo.filename}');
        return false;
      }

      // Save to local storage
      final localPath = await _saveToLocalStorage(memo.filename, data);

      // Convert to Ogg/Opus for standard playback
      String? convertedPath;
      try {
        convertedPath = await _convertToOgg(memo.filename, data);
        _log('Converted to Ogg: $convertedPath');
      } catch (e) {
        _log('Ogg conversion failed (non-fatal): $e');
      }

      // Update database
      await _repository.markDownloaded(
        filename: memo.filename,
        localFilePath: localPath,
      );

      if (convertedPath != null) {
        await _repository.updateConvertedPath(
          filename: memo.filename,
          convertedFilePath: convertedPath,
        );
      }

      // Delete from watch after successful verification
      _updateState(currentState.copyWith(
        phase: VoiceMemoSyncPhase.deleting,
      ));

      await _watchService.sendVoiceMemoCommand(
        'delete',
        extraData: {'filename': memo.filename},
      );
      await _repository.markDeletedOnWatch(memo.filename);

      _log('Successfully synced: ${memo.filename}');
      return true;
    } catch (e) {
      _log('Error downloading ${memo.filename}: $e');
      await _resetFsManager();
      return false;
    }
  }

  Future<void> _resetFsManager() async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;

    _downloadCompleter?.complete(null);
    _downloadCompleter = null;

    final manager = _fsManager;
    _fsManager = null;
    if (manager != null) {
      try {
        await manager.kill();
      } catch (e) {
        _log('FsManager cleanup failed: $e');
      }
    }
  }

  /// Save downloaded recording to app's local storage
  Future<String> _saveToLocalStorage(
      String filename, Uint8List data) async {
    final appDir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory(p.join(appDir.path, 'voice_memos'));
    if (!voiceDir.existsSync()) {
      voiceDir.createSync(recursive: true);
    }

    final file = File(p.join(voiceDir.path, '$filename.zsw_opus'));
    await file.writeAsBytes(data);
    return file.path;
  }

  /// Convert .zsw_opus to standard Ogg/Opus for playback
  Future<String> _convertToOgg(String filename, Uint8List zswOpusData) async {
    final parsed = ZswOpusParser.parse(zswOpusData);
    if (parsed == null || !parsed.isValid) {
      throw Exception('Failed to parse .zsw_opus data for conversion');
    }

    final oggData = OggOpusWriter.convert(parsed);

    final appDir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory(p.join(appDir.path, 'voice_memos'));
    if (!voiceDir.existsSync()) {
      voiceDir.createSync(recursive: true);
    }

    final file = File(p.join(voiceDir.path, '$filename.ogg'));
    await file.writeAsBytes(oggData);
    return file.path;
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['t'] as String?;
    if (type != 'voice_memo') return;

    final action = message['action'] as String?;
    switch (action) {
      case 'new':
        handleNewRecording(message);
      case 'list_result':
        handleListResult(message);
      case 'undo_last':
        unawaited(_handleUndoLast(message));
    }
  }

  void _updateState(VoiceMemoSyncState state) {
    _syncState.add(state);
  }

  void _resetStateAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!currentState.isSyncing) {
        _updateState(const VoiceMemoSyncState());
      }
    });
  }

  /// Send AI processing result back to the watch for toast confirmation.
  ///
  /// The watch displays the parsed title with an Undo button for 3 seconds.
  Future<void> sendResultToWatch(String filename, String title) async {
    if (!_watchService.isConnected) {
      _log('Cannot send result to watch — not connected');
      return;
    }
    try {
      await _watchService.sendVoiceMemoCommand(
        'result',
        extraData: {'text': title, 'filename': filename},
      );
      _log('Sent AI result to watch: $filename → "$title"');
    } catch (e) {
      _log('Failed to send result to watch: $e');
    }
  }

  /// Handle the undo_last command from the watch.
  ///
  /// Deletes AI-parsed results (summary, category, actions) but keeps the
  /// raw audio and transcription intact.
  Future<void> _handleUndoLast(Map<String, dynamic> message) async {
    final filename = message['filename'] as String?;
    if (filename == null || filename.isEmpty) {
      _log('undo_last: missing filename');
      return;
    }
    _log('Undo requested for: $filename');
    try {
      await _repository.clearAiResults(filename);
      _log('Cleared AI results for: $filename');
    } catch (e) {
      _log('Failed to undo AI results for $filename: $e');
    }
  }

  void _log(String message) {
    debugPrint('[VoiceMemoSync] $message');
  }

  /// Clean up resources
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    unawaited(_resetFsManager());
    _listCompleter?.complete([]);
    _syncState.close();
  }
}
