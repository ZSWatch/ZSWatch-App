import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/models/filesystem_image.dart';
import 'smp_not_available_exception.dart';

/// Service for uploading filesystem images to the watch via MCUmgr
///
/// Uses the FsManager from mcumgr_flutter to upload files to the watch's
/// filesystem via the MCUmgr filesystem commands.
class FilesystemUploadService {
  FsManager? _fsManager;
  StreamSubscription<UploadCallback>? _uploadSubscription;
  Timer? _speedTimer;
  int _lastBytesTransferred = 0;
  DateTime? _lastSpeedUpdate;
  final List<int> _speedSamples = [];
  static const int _speedWindowSize = 5;

  final _stateController = BehaviorSubject<FilesystemUploadState>.seeded(
    const FilesystemUploadState(),
  );
  final _logController = StreamController<String>.broadcast();

  /// Stream of upload state updates
  Stream<FilesystemUploadState> get stateStream => _stateController.stream;

  /// Current upload state
  FilesystemUploadState get currentState => _stateController.value;

  /// Stream of log messages
  Stream<String> get logStream => _logController.stream;

  /// Whether an upload is currently in progress
  bool get isInProgress => currentState.status.isInProgress;

  /// Start uploading a filesystem image
  ///
  /// [deviceId] - The BLE device remote ID (MAC address or UUID)
  /// [image] - The filesystem image to upload
  Future<void> startUpload({
    required String deviceId,
    required FilesystemImage image,
  }) async {
    if (isInProgress) {
      throw StateError('Upload already in progress');
    }

    _log('Starting filesystem upload: ${image.name} -> ${image.targetPath}');
    final startTime = DateTime.now();

    try {
      // Verify file exists
      final file = File(image.filePath);
      if (!await file.exists()) {
        throw FilesystemUploadException('File not found: ${image.filePath}');
      }

      // Read file data
      final Uint8List data = await file.readAsBytes();
      _log('Read ${data.length} bytes from ${image.name}');

      _updateState(
        FilesystemUploadState.uploading(
          totalBytes: data.length,
          imageName: image.name,
          startedAt: startTime,
        ),
      );

      // Get FsManager instance
      try {
        _fsManager = FsManager(deviceId);
      } catch (e) {
        throw SmpNotAvailableException(e);
      }
      _log('FsManager initialized for device $deviceId');

      // Subscribe to upload callbacks
      _uploadSubscription = _fsManager!.uploadCallbacks.listen(
        (callback) => _handleUploadCallback(callback, startTime),
        onError: (Object error) {
          _log('Upload error: $error');
          _updateState(
            FilesystemUploadState.failed(
              error.toString(),
              startedAt: startTime,
            ),
          );
        },
      );

      // Start speed calculation timer
      _startSpeedTimer();

      // Start the upload
      _log('Starting upload to ${image.targetPath}...');
      await _fsManager!.upload(image.targetPath, data);

      _log('Upload initiated');
    } on FilesystemUploadException {
      rethrow;
    } catch (e) {
      _log('Upload failed: $e');
      _updateState(
        FilesystemUploadState.failed(e.toString(), startedAt: startTime),
      );
      rethrow;
    }
  }

  void _handleUploadCallback(UploadCallback callback, DateTime startTime) {
    switch (callback) {
      case OnUploadProgressChanged():
        final progress = callback.total > 0
            ? callback.current / callback.total
            : 0.0;
        _updateState(
          currentState.copyWith(
            progress: progress.clamp(0.0, 1.0),
            bytesTransferred: callback.current,
            totalBytes: callback.total,
          ),
        );
        break;
      case OnUploadCompleted():
        _stopSpeedTimer();
        _log('Upload completed successfully!');
        _updateState(FilesystemUploadState.completed(startedAt: startTime));
        // Cleanup FsManager to release BLE transport for subsequent operations
        _cleanup();
        break;
      case OnUploadFailed():
        _stopSpeedTimer();
        _log('Upload failed: ${callback.cause}');
        _updateState(
          FilesystemUploadState.failed(
            callback.cause ?? 'Unknown error',
            startedAt: startTime,
          ),
        );
        _cleanup();
        break;
      case OnUploadCancelled():
        _stopSpeedTimer();
        _log('Upload cancelled');
        _updateState(FilesystemUploadState.cancelled(startedAt: startTime));
        _cleanup();
        break;
    }
  }

  /// Cancel the current upload
  Future<void> cancel() async {
    if (!isInProgress) return;

    _log('Cancelling upload...');

    try {
      await _fsManager?.cancelTransfer();
    } catch (e) {
      _log('Error during cancel: $e');
    }

    final startTime = currentState.startedAt;
    _updateState(FilesystemUploadState.cancelled(startedAt: startTime));

    await _cleanup();
  }

  /// Pause the current upload
  Future<void> pause() async {
    if (!isInProgress) return;

    _log('Pausing upload...');
    try {
      await _fsManager?.pauseTransfer();
    } catch (e) {
      _log('Error pausing: $e');
    }
  }

  /// Resume a paused upload
  Future<void> resume() async {
    _log('Resuming upload...');
    try {
      await _fsManager?.continueTransfer();
    } catch (e) {
      _log('Error resuming: $e');
    }
  }

  void _startSpeedTimer() {
    _lastBytesTransferred = 0;
    _lastSpeedUpdate = DateTime.now();
    _speedSamples.clear();

    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastSpeedUpdate!).inMilliseconds / 1000;
      if (elapsed > 0 && currentState.status.isInProgress) {
        final bytesThisInterval =
            currentState.bytesTransferred - _lastBytesTransferred;
        final speed = (bytesThisInterval / elapsed).round();

        if (bytesThisInterval > 0 || currentState.speedBytesPerSecond == 0) {
          _speedSamples.add(speed);
          if (_speedSamples.length > _speedWindowSize) {
            _speedSamples.removeAt(0);
          }
          final avg =
              _speedSamples.reduce((a, b) => a + b) ~/ _speedSamples.length;
          _updateState(
            currentState.copyWith(
              speedBytesPerSecond: avg,
              speedHistory: [...currentState.speedHistory, avg],
            ),
          );
        }

        _lastBytesTransferred = currentState.bytesTransferred;
        _lastSpeedUpdate = now;
      }
    });
  }

  void _stopSpeedTimer() {
    _speedTimer?.cancel();
    _speedTimer = null;
  }

  void _updateState(FilesystemUploadState state) {
    _stateController.add(state);
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    _logController.add('[FS] [$timestamp] $message');
  }

  Future<void> _cleanup() async {
    _stopSpeedTimer();
    await _uploadSubscription?.cancel();
    _uploadSubscription = null;
    await _fsManager?.kill();
    _fsManager = null;
  }

  /// Reset to idle state
  void reset() {
    if (isInProgress) return;
    _updateState(const FilesystemUploadState());
  }

  /// Dispose resources
  Future<void> dispose() async {
    await cancel();
    await _cleanup();
    await _stateController.close();
    await _logController.close();
  }
}

/// Exception for filesystem upload errors
class FilesystemUploadException implements Exception {
  final String message;
  final Object? cause;

  FilesystemUploadException(this.message, [this.cause]);

  @override
  String toString() => 'FilesystemUploadException: $message';
}
