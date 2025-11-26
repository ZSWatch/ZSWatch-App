import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:mcumgr_flutter/models/firmware_upgrade_mode.dart';
import 'package:mcumgr_flutter/models/image_upload_alignment.dart';
import 'package:mcumgr_flutter/src/mcumgr_update_manager.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/models/dfu_state.dart';
import '../../data/models/firmware_image.dart' as app;

/// Service for performing DFU (Device Firmware Update) operations
///
/// Wraps the mcumgr_flutter package to provide firmware updates
/// via MCUmgr/SMP protocol over BLE.
class DfuService {
  DeviceUpdateManager? _updateManager;
  StreamSubscription<FirmwareUpgradeState>? _stateSubscription;
  StreamSubscription<ProgressUpdate>? _progressSubscription;
  Timer? _speedTimer;
  int _lastBytesTransferred = 0;
  DateTime? _lastSpeedUpdate;

  final _stateController = BehaviorSubject<DfuState>.seeded(DfuState.idle);
  final _logController = StreamController<String>.broadcast();

  /// Stream of DFU state updates
  Stream<DfuState> get stateStream => _stateController.stream;

  /// Current DFU state
  DfuState get currentState => _stateController.value;

  /// Stream of log messages
  Stream<String> get logStream => _logController.stream;

  /// Whether a DFU is currently in progress
  bool get isInProgress => currentState.status.isInProgress;

  /// Whether the DFU is in a critical phase
  bool get isCritical => currentState.status.isCritical;

  /// Start a firmware update
  ///
  /// [device] - The BLE device to update
  /// [firmwareImages] - List of firmware images to upload (can be multiple for combined updates)
  Future<void> startUpdate({
    required BluetoothDevice device,
    required List<app.FirmwareImage> firmwareImages,
  }) async {
    if (isInProgress) {
      throw StateError('DFU already in progress');
    }

    if (firmwareImages.isEmpty) {
      throw ArgumentError('At least one firmware image is required');
    }

    _log('Starting DFU with ${firmwareImages.length} image(s)');
    final startTime = DateTime.now();

    try {
      _updateState(DfuState.preparing(imageName: firmwareImages.first.name));

      // Clean up any existing update manager first
      if (_updateManager != null) {
        _log('Cleaning up existing update manager');
        try {
          await _updateManager!.kill();
        } catch (e) {
          _log('Error cleaning up existing manager: $e');
        }
        _updateManager = null;
      }

      // Initialize update manager with device ID
      try {
        _updateManager = await DeviceUpdateManager.getInstance(device.remoteId.str);
      } catch (e) {
        // If manager already exists, try to kill it and recreate
        _log('Manager may already exist, attempting cleanup: $e');
        try {
          final existingManager = await DeviceUpdateManager.getInstance(device.remoteId.str);
          await existingManager.kill();
        } catch (_) {}
        // Retry after small delay
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _updateManager = await DeviceUpdateManager.getInstance(device.remoteId.str);
      }
      _log('Update manager initialized for device ${device.remoteId.str}');

      // Calculate total size and prepare images
      int totalSize = 0;
      final List<Image> mcuImages = [];
      
      for (int i = 0; i < firmwareImages.length; i++) {
        final image = firmwareImages[i];
        final file = File(image.filePath);
        if (!await file.exists()) {
          throw DfuException(
            DfuErrorType.invalidFile,
            'File not found: ${image.filePath}',
          );
        }
        final Uint8List bytes = await file.readAsBytes();
        totalSize += bytes.length;
        
        final imageIndex = image.slot ?? i;
        _log('Preparing image: ${image.name} -> slot $imageIndex (${bytes.length} bytes)');
        mcuImages.add(Image(
          image: imageIndex,
          data: bytes,
        ));
      }

      _log('Total firmware size: ${_formatBytes(totalSize)}');

      // Start the upload
      _updateState(DfuState.uploading(
        totalBytes: totalSize,
        totalImages: firmwareImages.length,
        currentImageName: firmwareImages.first.name,
        startedAt: startTime,
      ));

      // Start speed calculation timer
      _startSpeedTimer();

      // Subscribe to state updates
      final stateStream = _updateManager!.setup();
      _stateSubscription = stateStream.listen(
        (FirmwareUpgradeState state) => _handleUpgradeState(state, startTime),
        onError: (Object error) {
          _log('DFU error: $error');
          _updateState(DfuState.failed(error.toString(), startedAt: startTime));
        },
        onDone: () {
          _log('DFU state stream completed');
        },
      );

      // Subscribe to progress updates
      _progressSubscription = _updateManager!.progressStream.listen(
        (ProgressUpdate progress) {
          final double overallProgress = progress.bytesSent / progress.imageSize;
          // Preserve speed value during progress updates
          _updateState(currentState.copyWith(
            progress: overallProgress.clamp(0.0, 1.0),
            bytesTransferred: progress.bytesSent,
            totalBytes: progress.imageSize,
            speedBytesPerSecond: currentState.speedBytesPerSecond, // Preserve speed
          ));
        },
      );

      // Configure upgrade mode - use confirmOnly to confirm images immediately after upload
      // This ensures the device boots the new firmware after reset
      const configuration = FirmwareUpgradeConfiguration(
        firmwareUpgradeMode: FirmwareUpgradeMode.confirmOnly,
        eraseAppSettings: false,
        pipelineDepth: 1,
        byteAlignment: ImageUploadAlignment.fourByte,
      );

      // Perform the actual upload
      if (mcuImages.length == 1) {
        // Single image update
        await _updateManager!.updateWithImageData(
          imageData: mcuImages.first.data,
          configuration: configuration,
        );
      } else {
        // Multi-image update
        await _updateManager!.update(mcuImages, configuration: configuration);
      }

      _log('DFU upload initiated');

    } on DfuException {
      rethrow;
    } catch (e) {
      _log('DFU failed: $e');
      _updateState(DfuState.failed(
        e.toString(),
        startedAt: startTime,
      ));
      rethrow;
    }
  }

  /// Cancel the current DFU operation
  Future<void> cancel() async {
    if (!isInProgress) return;

    _log('Cancelling DFU...');

    try {
      await _updateManager?.cancel();
    } catch (e) {
      _log('Error during cancel: $e');
    }

    final startTime = currentState.startedAt;
    _updateState(DfuState.cancelled(startedAt: startTime));

    await _cleanup();
  }

  void _handleUpgradeState(FirmwareUpgradeState state, DateTime startTime) {
    _log('Upgrade state: $state');

    // Preserve current progress values during state transitions
    final preservedState = currentState;

    if (state == FirmwareUpgradeState.validate) {
      _updateState(preservedState.copyWith(status: DfuStatus.validating));
    } else if (state == FirmwareUpgradeState.upload) {
      _updateState(preservedState.copyWith(status: DfuStatus.uploading));
    } else if (state == FirmwareUpgradeState.test) {
      _updateState(preservedState.copyWith(status: DfuStatus.applying));
    } else if (state == FirmwareUpgradeState.reset) {
      _updateState(preservedState.copyWith(status: DfuStatus.rebooting));
    } else if (state == FirmwareUpgradeState.confirm) {
      _updateState(preservedState.copyWith(status: DfuStatus.applying));
    } else if (state == FirmwareUpgradeState.success) {
      _stopSpeedTimer();
      _log('DFU completed successfully!');
      _updateState(DfuState.completed(startedAt: startTime));
    }
  }

  void _startSpeedTimer() {
    _lastBytesTransferred = 0;
    _lastSpeedUpdate = DateTime.now();

    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastSpeedUpdate!).inMilliseconds / 1000;
      if (elapsed > 0 && currentState.status.isInProgress) {
        final bytesThisInterval = currentState.bytesTransferred - _lastBytesTransferred;
        final speed = (bytesThisInterval / elapsed).round();

        // Only update speed if we have actual progress, otherwise keep the last value
        if (bytesThisInterval > 0 || currentState.speedBytesPerSecond == 0) {
          _updateState(currentState.copyWith(speedBytesPerSecond: speed));
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

  void _updateState(DfuState state) {
    _stateController.add(state);
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    _logController.add('[$timestamp] $message');
  }

  Future<void> _cleanup() async {
    _stopSpeedTimer();
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _progressSubscription?.cancel();
    _progressSubscription = null;
    await _updateManager?.kill();
    _updateManager = null;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Reset to idle state
  void reset() {
    if (isInProgress) return;
    _updateState(DfuState.idle);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await cancel();
    await _cleanup();
    await _stateController.close();
    await _logController.close();
  }
}

/// Custom exception for DFU errors
class DfuException implements Exception {
  final DfuErrorType type;
  final String message;
  final Object? cause;

  DfuException(this.type, this.message, [this.cause]);

  @override
  String toString() => 'DfuException(${type.name}): $message';
}
