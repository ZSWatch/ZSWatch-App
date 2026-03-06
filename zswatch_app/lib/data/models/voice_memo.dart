import 'package:equatable/equatable.dart';

/// Sync state of a voice memo
enum VoiceMemoSyncStatus {
  /// Only exists on the watch, not yet downloaded
  onWatchOnly,

  /// Currently being downloaded from the watch
  downloading,

  /// Downloaded to phone, verified, watch copy may still exist
  synced,

  /// Download failed — will retry on next sync
  downloadFailed,

  /// Transcription completed
  transcribed,
}

/// Domain model for a voice memo recording
class VoiceMemo extends Equatable {
  final int id;
  final String filename;
  final DateTime timestampUtc;
  final int durationMs;
  final int sizeBytes;
  final String? localFilePath;
  final String? transcription;
  final bool syncedFromWatch;
  final bool deletedOnWatch;
  final DateTime? downloadedAt;
  final DateTime? transcribedAt;
  final String? convertedFilePath;

  const VoiceMemo({
    required this.id,
    required this.filename,
    required this.timestampUtc,
    required this.durationMs,
    required this.sizeBytes,
    this.localFilePath,
    this.transcription,
    this.syncedFromWatch = false,
    this.deletedOnWatch = false,
    this.downloadedAt,
    this.transcribedAt,
    this.convertedFilePath,
  });

  /// Computed sync status based on field values
  VoiceMemoSyncStatus get syncStatus {
    if (transcription != null) return VoiceMemoSyncStatus.transcribed;
    if (syncedFromWatch && localFilePath != null) {
      return VoiceMemoSyncStatus.synced;
    }
    return VoiceMemoSyncStatus.onWatchOnly;
  }

  /// Duration formatted as MM:SS
  String get formattedDuration {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// File size formatted as human-readable string
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Relative time display (e.g., "2 min ago", "Yesterday")
  String get relativeTime {
    final now = DateTime.now().toUtc();
    final diff = now.difference(timestampUtc);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${timestampUtc.month}/${timestampUtc.day}/${timestampUtc.year}';
  }

  VoiceMemo copyWith({
    int? id,
    String? filename,
    DateTime? timestampUtc,
    int? durationMs,
    int? sizeBytes,
    String? localFilePath,
    String? transcription,
    bool? syncedFromWatch,
    bool? deletedOnWatch,
    DateTime? downloadedAt,
    DateTime? transcribedAt,
    String? convertedFilePath,
  }) {
    return VoiceMemo(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      timestampUtc: timestampUtc ?? this.timestampUtc,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localFilePath: localFilePath ?? this.localFilePath,
      transcription: transcription ?? this.transcription,
      syncedFromWatch: syncedFromWatch ?? this.syncedFromWatch,
      deletedOnWatch: deletedOnWatch ?? this.deletedOnWatch,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      transcribedAt: transcribedAt ?? this.transcribedAt,
      convertedFilePath: convertedFilePath ?? this.convertedFilePath,
    );
  }

  @override
  List<Object?> get props => [
        id,
        filename,
        timestampUtc,
        durationMs,
        sizeBytes,
        localFilePath,
        transcription,
        syncedFromWatch,
        deletedOnWatch,
        downloadedAt,
        transcribedAt,
        convertedFilePath,
      ];
}
