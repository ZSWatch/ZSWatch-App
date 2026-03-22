import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/models/coredump_analysis.dart';
import '../../data/models/crash_summary.dart';
import '../dfu/firmware_manager.dart';
import '../watch_service.dart';
import 'coredump_api_service.dart';

/// Phase of the coredump analysis pipeline.
enum CoredumpAnalysisPhase {
  idle,
  enablingSmp,
  downloading,
  uploading,
  analyzing,
  completed,
  failed,
}

/// Current state of a coredump analysis operation.
class CoredumpAnalysisState {
  final CoredumpAnalysisPhase phase;
  final double downloadProgress;
  final CoredumpAnalysis? result;
  final String? errorMessage;

  const CoredumpAnalysisState({
    this.phase = CoredumpAnalysisPhase.idle,
    this.downloadProgress = 0.0,
    this.result,
    this.errorMessage,
  });

  CoredumpAnalysisState copyWith({
    CoredumpAnalysisPhase? phase,
    double? downloadProgress,
    CoredumpAnalysis? result,
    String? errorMessage,
  }) {
    return CoredumpAnalysisState(
      phase: phase ?? this.phase,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isRunning =>
      phase != CoredumpAnalysisPhase.idle &&
      phase != CoredumpAnalysisPhase.completed &&
      phase != CoredumpAnalysisPhase.failed;
}

/// Orchestrates the full coredump analysis pipeline:
/// 1. Enable SMP on the watch
/// 2. Download /user/coredump.txt via MCUmgr FS
/// 3. Upload to backend for analysis
/// 4. Return backtrace/registers
class CoredumpService {
  static const String _coredumpPath = '/user/coredump.txt';

  final WatchService _watchService;
  final CoredumpApiService _apiService;
  final FirmwareManager _firmwareManager;

  FsManager? _fsManager;
  StreamSubscription<DownloadCallback>? _downloadSubscription;
  Completer<Uint8List?>? _downloadCompleter;

  final _state = BehaviorSubject<CoredumpAnalysisState>.seeded(
    const CoredumpAnalysisState(),
  );

  /// The raw coredump text from the last analysis (for export).
  String? lastCoredumpTxt;

  CoredumpService(this._watchService, this._apiService, this._firmwareManager);

  Stream<CoredumpAnalysisState> get stateStream => _state.stream;
  CoredumpAnalysisState get currentState => _state.value;

  /// Run the full analysis pipeline: download from watch → send to backend.
  /// Set [useLatestElf] to true for dev builds to skip hash/commit matching.
  Future<CoredumpAnalysis?> analyze(
    CrashSummary summary, {
    bool useLatestElf = false,
  }) async {
    if (currentState.isRunning) {
      debugPrint('[CoredumpService] Analysis already in progress');
      return null;
    }

    try {
      // Step 1: Enable SMP
      _state.add(
        const CoredumpAnalysisState(phase: CoredumpAnalysisPhase.enablingSmp),
      );
      await _watchService.enableSmp();
      // Give the watch time to enable SMP service
      await Future<void>.delayed(const Duration(seconds: 2));

      // Step 2: Download coredump.txt
      _state.add(
        const CoredumpAnalysisState(phase: CoredumpAnalysisPhase.downloading),
      );
      final coredumpBytes = await _downloadCoredump();
      if (coredumpBytes == null) {
        _state.add(
          const CoredumpAnalysisState(
            phase: CoredumpAnalysisPhase.failed,
            errorMessage: 'Failed to download coredump from watch',
          ),
        );
        return null;
      }

      // The file has a binary header (zsw_coredump_sumary_t struct) before the
      // text coredump data. Find the #CD:BEGIN# marker and strip everything before it.
      const marker = '#CD:BEGIN#';
      final markerBytes = marker.codeUnits;
      int markerIndex = -1;
      for (int i = 0; i <= coredumpBytes.length - markerBytes.length; i++) {
        bool found = true;
        for (int j = 0; j < markerBytes.length; j++) {
          if (coredumpBytes[i + j] != markerBytes[j]) {
            found = false;
            break;
          }
        }
        if (found) {
          markerIndex = i;
          break;
        }
      }

      final String coredumpTxt;
      if (markerIndex >= 0) {
        coredumpTxt = String.fromCharCodes(coredumpBytes, markerIndex);
        debugPrint(
          '[CoredumpService] Stripped $markerIndex byte binary header',
        );
      } else {
        coredumpTxt = String.fromCharCodes(coredumpBytes);
        debugPrint('[CoredumpService] No #CD:BEGIN# marker found, sending raw');
      }
      debugPrint(
        '[CoredumpService] Downloaded coredump: ${coredumpBytes.length} bytes, '
        'text portion: ${coredumpTxt.length} chars',
      );

      // Store for export
      lastCoredumpTxt = coredumpTxt;

      // Look up elf_hash from local cache (set when firmware was downloaded via app)
      final elfHash = await _firmwareManager.getCachedElfHash(
        summary.fwCommitSha,
      );
      if (elfHash != null) {
        debugPrint('[CoredumpService] Found cached elf_hash: $elfHash');
      }

      // Step 3: Send to backend
      _state.add(
        const CoredumpAnalysisState(phase: CoredumpAnalysisPhase.analyzing),
      );
      final result = await _apiService.analyze(
        coredumpTxt: coredumpTxt,
        summary: summary,
        elfHash: elfHash,
        useLatestElf: useLatestElf,
      );

      // Note: ELF upload is handled by CI or the upload_elf.py script.
      // The app only consumes the analysis endpoint.

      _state.add(
        CoredumpAnalysisState(
          phase: CoredumpAnalysisPhase.completed,
          result: result,
        ),
      );

      // Disable SMP after we're done
      try {
        await _watchService.disableSmp();
      } catch (_) {}

      return result;
    } catch (e, st) {
      debugPrint('[CoredumpService] Analysis failed: $e\n$st');
      _state.add(
        CoredumpAnalysisState(
          phase: CoredumpAnalysisPhase.failed,
          errorMessage: e.toString(),
        ),
      );
      // Try to disable SMP even on failure
      try {
        await _watchService.disableSmp();
      } catch (_) {}
      return null;
    }
  }

  Future<Uint8List?> _downloadCoredump() async {
    final device = _watchService.device;
    if (device == null) {
      debugPrint('[CoredumpService] No device connected');
      return null;
    }

    await _resetFsManager();
    _fsManager = FsManager(device.remoteId.str);

    _downloadCompleter = Completer<Uint8List?>();
    await _downloadSubscription?.cancel();
    _downloadSubscription = _fsManager!.downloadCallbacks.listen(
      (callback) {
        switch (callback) {
          case OnDownloadProgressChanged():
            final progress = callback.total > 0
                ? callback.current / callback.total
                : 0.0;
            _state.add(currentState.copyWith(downloadProgress: progress));
          case OnDownloadCompleted():
            _downloadCompleter?.complete(callback.data);
            _downloadCompleter = null;
          case OnDownloadFailed():
            debugPrint('[CoredumpService] Download failed: ${callback.cause}');
            _downloadCompleter?.complete(null);
            _downloadCompleter = null;
          case OnDownloadCancelled():
            debugPrint('[CoredumpService] Download cancelled');
            _downloadCompleter?.complete(null);
            _downloadCompleter = null;
        }
      },
      onError: (Object error) {
        debugPrint('[CoredumpService] Download callback error: $error');
        _downloadCompleter?.complete(null);
        _downloadCompleter = null;
      },
    );

    await _fsManager!.download(_coredumpPath);

    final data = await _downloadCompleter!.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        debugPrint('[CoredumpService] Download timed out');
        return null;
      },
    );

    await _resetFsManager();
    return data;
  }

  Future<void> _resetFsManager() async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;

    final manager = _fsManager;
    _fsManager = null;
    if (manager != null) {
      try {
        await manager.kill();
      } catch (e) {
        debugPrint('[CoredumpService] FsManager cleanup failed: $e');
      }
    }
  }

  void reset() {
    _state.add(const CoredumpAnalysisState());
  }

  void dispose() {
    _resetFsManager();
    _state.close();
  }
}
