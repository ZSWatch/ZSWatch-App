import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../core/constants/filesystem_constants.dart';

/// Status of a filesystem upload operation
enum FilesystemUploadStatus {
  /// Not started
  idle,
  /// Upload is in progress
  uploading,
  /// Upload completed successfully
  completed,
  /// Upload failed
  failed,
  /// Upload was cancelled
  cancelled,
}

/// Extension methods for FilesystemUploadStatus
extension FilesystemUploadStatusExtension on FilesystemUploadStatus {
  bool get isInProgress => this == FilesystemUploadStatus.uploading;
  bool get isTerminal => this == FilesystemUploadStatus.completed ||
      this == FilesystemUploadStatus.failed ||
      this == FilesystemUploadStatus.cancelled;
  
  String get statusText {
    switch (this) {
      case FilesystemUploadStatus.idle:
        return 'Ready';
      case FilesystemUploadStatus.uploading:
        return 'Uploading...';
      case FilesystemUploadStatus.completed:
        return 'Completed';
      case FilesystemUploadStatus.failed:
        return 'Failed';
      case FilesystemUploadStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Represents a filesystem image that can be uploaded to the watch
/// 
/// This is typically the lvgl_resources_raw.bin file found alongside
/// dfu_application.zip in release archives.
class FilesystemImage extends Equatable {
  /// Display name for the image
  final String name;

  /// Local file path to the image
  final String filePath;

  /// Target path on the device where the file will be uploaded
  final String targetPath;

  /// File size in bytes
  final int size;

  /// Optional source URL (if downloaded from GitHub)
  final String? sourceUrl;

  /// Version string (if known)
  final String? version;

  const FilesystemImage({
    required this.name,
    required this.filePath,
    required this.targetPath,
    required this.size,
    this.sourceUrl,
    this.version,
  });

  /// Create from a local file with default target path
  factory FilesystemImage.fromFile({
    required String filePath,
    int? size,
    String? version,
    String? sourceUrl,
  }) {
    final file = File(filePath);
    final fileName = file.uri.pathSegments.last;
    
    return FilesystemImage(
      name: fileName,
      filePath: filePath,
      targetPath: FilesystemConstants.targetPath,
      size: size ?? 0,
      sourceUrl: sourceUrl,
      version: version,
    );
  }

  /// Human-readable file size
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Check if the file exists
  Future<bool> exists() async {
    return File(filePath).exists();
  }

  /// Read the file contents
  Future<List<int>> readBytes() async {
    return File(filePath).readAsBytes();
  }

  @override
  List<Object?> get props => [name, filePath, targetPath, size, sourceUrl, version];

  @override
  String toString() => 'FilesystemImage(name: $name, size: $formattedSize, target: $targetPath)';
}

/// State for filesystem upload operations
class FilesystemUploadState extends Equatable {
  /// Current status
  final FilesystemUploadStatus status;

  /// Progress (0.0 to 1.0)
  final double progress;

  /// Bytes transferred
  final int bytesTransferred;

  /// Total bytes to transfer
  final int totalBytes;

  /// Upload speed in bytes per second
  final int speedBytesPerSecond;

  /// When the upload started
  final DateTime? startedAt;

  /// Error message (if failed)
  final String? errorMessage;

  /// Current image being uploaded
  final String? imageName;

  const FilesystemUploadState({
    this.status = FilesystemUploadStatus.idle,
    this.progress = 0.0,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.speedBytesPerSecond = 0,
    this.startedAt,
    this.errorMessage,
    this.imageName,
  });

  /// Idle state
  static const idle = FilesystemUploadState();

  /// Create uploading state
  factory FilesystemUploadState.uploading({
    required int totalBytes,
    String? imageName,
    DateTime? startedAt,
  }) {
    return FilesystemUploadState(
      status: FilesystemUploadStatus.uploading,
      totalBytes: totalBytes,
      imageName: imageName,
      startedAt: startedAt ?? DateTime.now(),
    );
  }

  /// Create completed state
  factory FilesystemUploadState.completed({DateTime? startedAt}) {
    return FilesystemUploadState(
      status: FilesystemUploadStatus.completed,
      progress: 1.0,
      startedAt: startedAt,
    );
  }

  /// Create failed state
  factory FilesystemUploadState.failed(String message, {DateTime? startedAt}) {
    return FilesystemUploadState(
      status: FilesystemUploadStatus.failed,
      errorMessage: message,
      startedAt: startedAt,
    );
  }

  /// Create cancelled state
  factory FilesystemUploadState.cancelled({DateTime? startedAt}) {
    return FilesystemUploadState(
      status: FilesystemUploadStatus.cancelled,
      startedAt: startedAt,
    );
  }

  /// Progress percentage (0-100)
  int get progressPercent => (progress * 100).round();

  /// Human-readable bytes transferred
  String get formattedBytesTransferred => _formatBytes(bytesTransferred);

  /// Human-readable total bytes
  String get formattedTotalBytes => _formatBytes(totalBytes);

  /// Human-readable upload speed
  String get formattedSpeed {
    if (speedBytesPerSecond < 1024) {
      return '$speedBytesPerSecond B/s';
    } else if (speedBytesPerSecond < 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }

  /// Estimated time remaining
  String get formattedTimeRemaining {
    if (speedBytesPerSecond <= 0 || bytesTransferred >= totalBytes) {
      return '--:--';
    }
    
    final remaining = totalBytes - bytesTransferred;
    final seconds = remaining ~/ speedBytesPerSecond;
    
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    } else {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return '$h:${m.toString().padLeft(2, '0')}:00';
    }
  }

  /// Elapsed time since start
  Duration? get elapsed {
    if (startedAt == null) return null;
    return DateTime.now().difference(startedAt!);
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

  FilesystemUploadState copyWith({
    FilesystemUploadStatus? status,
    double? progress,
    int? bytesTransferred,
    int? totalBytes,
    int? speedBytesPerSecond,
    DateTime? startedAt,
    String? errorMessage,
    String? imageName,
  }) {
    return FilesystemUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      startedAt: startedAt ?? this.startedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      imageName: imageName ?? this.imageName,
    );
  }

  @override
  List<Object?> get props => [
        status,
        progress,
        bytesTransferred,
        totalBytes,
        speedBytesPerSecond,
        startedAt,
        errorMessage,
        imageName,
      ];
}

