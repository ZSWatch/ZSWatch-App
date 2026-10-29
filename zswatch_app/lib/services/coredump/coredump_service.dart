import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:rxdart/rxdart.dart';

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
  final Future<Uint8List> Function() _nativeDownload;

  final _state = BehaviorSubject<CoredumpDownloadState>.seeded(
    const CoredumpDownloadState(),
  );

  /// The coredump text from the last download.
  String? lastCoredumpTxt;

  CoredumpService.native(this._nativeDownload);

  Stream<CoredumpDownloadState> get stateStream => _state.stream;
  CoredumpDownloadState get currentState => _state.value;

  Future<String?> download() async {
    if (currentState.isRunning) return null;

    try {
      _state.add(
        const CoredumpDownloadState(phase: CoredumpDownloadPhase.enablingSmp),
      );

      _state.add(
        const CoredumpDownloadState(phase: CoredumpDownloadPhase.downloading),
      );
      final coredumpBytes = await _nativeDownload();

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
    }
  }

  void reset() {
    lastCoredumpTxt = null;
    _state.add(const CoredumpDownloadState());
  }

  void dispose() {
    _state.close();
  }
}
