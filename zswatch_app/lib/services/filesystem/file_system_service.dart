import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';

import '../../data/models/fs_file_entry.dart';

class FileSystemService {
  static const String logDir = '/user/logs/';
  static const String logFilePrefix = 'log';
  static const int logFilesLimit = 8;
  static const String recordingsDir = '/user/recordings/';

  Future<List<FsFileEntry>> probeFiles(
    String dir,
    String prefix,
    int maxFiles,
    String deviceId,
  ) async {
    final fsManager = FsManager(deviceId);
    final entries = <FsFileEntry>[];

    try {
      for (var i = 0; i < maxFiles; i++) {
        final name = '$prefix${i.toString().padLeft(4, '0')}';
        final path = '$dir$name';
        try {
          final sizeBytes = await fsManager.status(path);
          entries.add(
            FsFileEntry(path: path, name: name, sizeBytes: sizeBytes),
          );
          _log('Found file: $path ($sizeBytes bytes)');
        } catch (_) {
          // File not found — skip
        }
      }
    } finally {
      try {
        await fsManager.kill();
      } catch (e) {
        _log('FsManager cleanup failed: $e');
      }
    }

    return entries;
  }

  Future<Uint8List> downloadFile(
    String path,
    String deviceId,
    void Function(double progress) onProgress,
  ) async {
    final fsManager = FsManager(deviceId);
    StreamSubscription<DownloadCallback>? subscription;
    Completer<Uint8List>? completer;

    try {
      completer = Completer<Uint8List>();
      // Capture the future before any callback can null the completer to
      // avoid a null-dereference if the callback fires before the await below.
      final future = completer.future;

      subscription = fsManager.downloadCallbacks.listen(
        (callback) {
          switch (callback) {
            case OnDownloadProgressChanged():
              final progress = callback.total > 0
                  ? callback.current / callback.total
                  : 0.0;
              onProgress(progress);
            case OnDownloadCompleted():
              completer?.complete(callback.data);
              completer = null;
            case OnDownloadFailed():
              _log('Download failed: ${callback.cause}');
              completer?.completeError(
                Exception('Download failed: ${callback.cause}'),
              );
              completer = null;
            case OnDownloadCancelled():
              _log('Download cancelled');
              completer?.completeError(Exception('Download cancelled'));
              completer = null;
          }
        },
        onError: (Object error) {
          _log('Download callback stream error: $error');
          completer?.completeError(error);
          completer = null;
        },
      );

      await fsManager.download(path);

      final data = await future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Download timed out');
        },
      );

      return data;
    } finally {
      await subscription?.cancel();
      try {
        await fsManager.kill();
      } catch (e) {
        _log('FsManager cleanup failed: $e');
      }
    }
  }

  void _log(String message) {
    debugPrint('[FileSystem] $message');
  }
}
