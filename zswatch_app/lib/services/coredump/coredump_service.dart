import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:rxdart/rxdart.dart';

import '../watch_service.dart';

enum CoredumpDownloadPhase { idle, enablingSmp, downloading, completed, failed }

class CoredumpDownloadState {
  final CoredumpDownloadPhase phase;
  final double downloadProgress;
  final String? errorMessage;

  const CoredumpDownloadState({
    this.phase = CoredumpDownloadPhase.idle,
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  CoredumpDownloadState copyWith({
    CoredumpDownloadPhase? phase,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return CoredumpDownloadState(
      phase: phase ?? this.phase,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isRunning =>
      phase == CoredumpDownloadPhase.enablingSmp ||
      phase == CoredumpDownloadPhase.downloading;
}

/// Downloads /lvgl_lfs/coredump.txt from the watch so it can be exported.
class CoredumpService {
  static const String _coredumpPath = '/lvgl_lfs/coredump.txt';

  final WatchService? _watchService;
  final Future<Uint8List> Function()? _nativeDownload;

  FsManager? _fsManager;
  StreamSubscription<DownloadCallback>? _downloadSubscription;
  Completer<Uint8List?>? _downloadCompleter;

  final _state = BehaviorSubject<CoredumpDownloadState>.seeded(
    const CoredumpDownloadState(),
  );

  /// The coredump text from the last download.
  String? lastCoredumpTxt;

  CoredumpService(this._watchService) : _nativeDownload = null;

  CoredumpService.native(this._nativeDownload) : _watchService = null;

  Stream<CoredumpDownloadState> get stateStream => _state.stream;
  CoredumpDownloadState get currentState => _state.value;

  Future<String?> download() async {
    if (currentState.isRunning) return null;

    final smpGen = _watchService?.connectionGeneration;
    try {
      _state.add(
        const CoredumpDownloadState(phase: CoredumpDownloadPhase.enablingSmp),
      );
      if (_watchService != null) {
        await _watchService.enableSmp();
        // Give the watch time to enable SMP service
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      _state.add(
        const CoredumpDownloadState(phase: CoredumpDownloadPhase.downloading),
      );
      final coredumpBytes = await _downloadCoredump();
      if (coredumpBytes == null) {
        _state.add(
          const CoredumpDownloadState(
            phase: CoredumpDownloadPhase.failed,
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
        debugPrint('[CoredumpService] No #CD:BEGIN# marker found, keeping raw');
      }
      debugPrint(
        '[CoredumpService] Downloaded coredump: ${coredumpBytes.length} bytes, '
        'text portion: ${coredumpTxt.length} chars',
      );

      lastCoredumpTxt = coredumpTxt;
      _state.add(
        const CoredumpDownloadState(phase: CoredumpDownloadPhase.completed),
      );
      return coredumpTxt;
    } catch (e, st) {
      debugPrint('[CoredumpService] Download failed: $e\n$st');
      _state.add(
        CoredumpDownloadState(
          phase: CoredumpDownloadPhase.failed,
          errorMessage: e.toString(),
        ),
      );
      return null;
    } finally {
      try {
        if (_watchService != null && smpGen != null) {
          await _watchService.disableSmpIfConnectionUnchanged(smpGen);
        }
      } catch (_) {}
    }
  }

  Future<Uint8List?> _downloadCoredump() async {
    if (_nativeDownload != null) return _nativeDownload();
    final device = _watchService!.device;
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
    lastCoredumpTxt = null;
    _state.add(const CoredumpDownloadState());
  }

  void dispose() {
    _resetFsManager();
    _state.close();
  }
}
