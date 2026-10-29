import 'package:freezed_annotation/freezed_annotation.dart';

part 'dfu_state.freezed.dart';

/// DFU (Device Firmware Update) process states
enum DfuStatus {
  /// No update in progress
  idle,

  /// Preparing firmware file (extracting, validating)
  preparing,

  /// Uploading firmware to device
  uploading,

  /// Firmware uploaded, waiting for device to validate
  validating,

  /// Device is applying the update
  applying,

  /// Waiting for device to reboot
  rebooting,

  /// Waiting to reconnect to device after reboot
  reconnecting,

  /// Update completed successfully
  completed,

  /// Update failed with error
  failed,

  /// Update was cancelled by user
  cancelled,
}

/// Extension methods for DfuStatus
extension DfuStatusExtension on DfuStatus {
  /// Whether the DFU is actively in progress
  bool get isInProgress =>
      this == DfuStatus.preparing ||
      this == DfuStatus.uploading ||
      this == DfuStatus.validating ||
      this == DfuStatus.applying ||
      this == DfuStatus.rebooting ||
      this == DfuStatus.reconnecting;

  /// Whether the DFU is in a critical phase (should not be interrupted)
  bool get isCritical =>
      this == DfuStatus.uploading ||
      this == DfuStatus.validating ||
      this == DfuStatus.applying;

  /// Whether the DFU has finished (success or failure)
  bool get isFinished =>
      this == DfuStatus.completed ||
      this == DfuStatus.failed ||
      this == DfuStatus.cancelled;

  /// Whether the status represents success
  bool get isSuccess => this == DfuStatus.completed;

  /// Whether the status represents failure
  bool get isFailure => this == DfuStatus.failed;

  /// Whether the DFU can be cancelled at this point
  bool get canCancel => this == DfuStatus.uploading;

  /// Human-readable status text
  String get statusText {
    switch (this) {
      case DfuStatus.idle:
        return 'Ready';
      case DfuStatus.preparing:
        return 'Preparing...';
      case DfuStatus.uploading:
        return 'Uploading...';
      case DfuStatus.validating:
        return 'Validating...';
      case DfuStatus.applying:
        return 'Applying update...';
      case DfuStatus.rebooting:
        return 'Rebooting watch...';
      case DfuStatus.reconnecting:
        return 'Reconnecting...';
      case DfuStatus.completed:
        return 'Update complete!';
      case DfuStatus.failed:
        return 'Update failed';
      case DfuStatus.cancelled:
        return 'Update cancelled';
    }
  }

  /// Icon name for the status
  String get iconName {
    switch (this) {
      case DfuStatus.idle:
        return 'system_update';
      case DfuStatus.preparing:
        return 'hourglass_top';
      case DfuStatus.uploading:
        return 'upload';
      case DfuStatus.validating:
        return 'verified';
      case DfuStatus.applying:
        return 'memory';
      case DfuStatus.rebooting:
        return 'restart_alt';
      case DfuStatus.reconnecting:
        return 'bluetooth_searching';
      case DfuStatus.completed:
        return 'check_circle';
      case DfuStatus.failed:
        return 'error';
      case DfuStatus.cancelled:
        return 'cancel';
    }
  }
}

/// Represents the current state of a DFU operation
@freezed
abstract class DfuState with _$DfuState {
  const DfuState._();

  const factory DfuState({
    /// Current status of the DFU process
    @Default(DfuStatus.idle) DfuStatus status,

    /// Overall progress (0.0 to 1.0)
    @Default(0.0) double progress,

    /// Bytes transferred so far
    @Default(0) int bytesTransferred,

    /// Total bytes to transfer
    @Default(0) int totalBytes,

    /// Current upload speed in bytes per second
    @Default(0) int speedBytesPerSecond,

    /// Speed history for chart (bytes per second samples)
    @Default([]) List<int> speedHistory,

    /// Current image being uploaded (for multi-image updates)
    @Default(0) int currentImage,

    /// Total number of images to upload
    @Default(1) int totalImages,

    /// Name of the current image being processed
    String? currentImageName,

    /// Error message if status is failed
    String? errorMessage,

    /// When the DFU started
    DateTime? startedAt,

    /// When the DFU completed/failed
    DateTime? completedAt,
  }) = _DfuState;

  /// Initial idle state
  static const idle = DfuState();

  /// Progress as percentage (0-100)
  int get progressPercent => (progress * 100).round();

  /// Human-readable bytes transferred
  String get formattedBytesTransferred => _formatBytes(bytesTransferred);

  /// Human-readable total bytes
  String get formattedTotalBytes => _formatBytes(totalBytes);

  /// Human-readable speed
  String get formattedSpeed {
    if (speedBytesPerSecond == 0) {
      if (status == DfuStatus.uploading && totalBytes > 0) {
        return speedHistory.isEmpty ? 'calculating...' : '0 B/s';
      }
      return '--';
    }
    return '${_formatBytes(speedBytesPerSecond)}/s';
  }

  /// Estimated time remaining in seconds
  int? get estimatedSecondsRemaining {
    if (speedBytesPerSecond <= 0 || bytesTransferred >= totalBytes) return null;
    final remaining = totalBytes - bytesTransferred;
    return (remaining / speedBytesPerSecond).ceil();
  }

  /// Human-readable time remaining
  String get formattedTimeRemaining {
    if (status == DfuStatus.uploading &&
        totalBytes > 0 &&
        bytesTransferred >= totalBytes) {
      return '0 sec';
    }
    final seconds = estimatedSecondsRemaining;
    if (seconds == null) {
      if (status == DfuStatus.uploading &&
          totalBytes > 0 &&
          speedBytesPerSecond == 0) {
        return speedHistory.isEmpty ? 'calculating...' : 'Waiting for data';
      }
      return '--';
    }
    if (seconds < 60) return '$seconds sec';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Duration since start
  Duration? get elapsedTime {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  /// Human-readable elapsed time
  String get formattedElapsedTime {
    final elapsed = elapsedTime;
    if (elapsed == null) return '--';
    final seconds = elapsed.inSeconds;
    if (seconds < 60) return '$seconds sec';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
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
}
