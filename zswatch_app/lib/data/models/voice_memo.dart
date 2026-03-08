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

/// AI processing status for a voice memo
enum VoiceNoteProcessingStatus {
  /// Not yet processed by AI
  pending,

  /// AI is summarizing the transcript
  summarizing,

  /// AI is categorizing the note
  categorizing,

  /// AI is extracting actions
  extractingActions,

  /// AI processing completed successfully
  ready,

  /// AI processing failed
  failed,
}

/// Category assigned by AI to a voice note
enum VoiceNoteCategory {
  idea,
  task,
  reminder,
  meeting,
  note,
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

  // AI-enhanced fields
  final String? summary;
  final String? category;
  final String? processingStatus;
  final String? aiModel;
  final DateTime? aiProcessedAt;
  final bool taskCreated;
  final bool calendarEventCreated;
  final String? actionReviewState;

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
    this.summary,
    this.category,
    this.processingStatus,
    this.aiModel,
    this.aiProcessedAt,
    this.taskCreated = false,
    this.calendarEventCreated = false,
    this.actionReviewState,
  });

  /// Computed sync status based on field values
  VoiceMemoSyncStatus get syncStatus {
    if (transcription != null) return VoiceMemoSyncStatus.transcribed;
    if (syncedFromWatch && localFilePath != null) {
      return VoiceMemoSyncStatus.synced;
    }
    return VoiceMemoSyncStatus.onWatchOnly;
  }

  /// Parsed AI processing status
  VoiceNoteProcessingStatus get aiProcessingStatus {
    if (processingStatus == null) return VoiceNoteProcessingStatus.pending;
    switch (processingStatus) {
      case 'summarizing':
        return VoiceNoteProcessingStatus.summarizing;
      case 'categorizing':
        return VoiceNoteProcessingStatus.categorizing;
      case 'extractingActions':
        return VoiceNoteProcessingStatus.extractingActions;
      case 'ready':
        return VoiceNoteProcessingStatus.ready;
      case 'failed':
        return VoiceNoteProcessingStatus.failed;
      default:
        return VoiceNoteProcessingStatus.pending;
    }
  }

  /// Convenience alias used by UI code
  VoiceNoteCategory? get aiCategory => categoryEnum;

  /// Parsed category enum
  VoiceNoteCategory? get categoryEnum {
    if (category == null) return null;
    switch (category) {
      case 'idea':
        return VoiceNoteCategory.idea;
      case 'task':
        return VoiceNoteCategory.task;
      case 'reminder':
        return VoiceNoteCategory.reminder;
      case 'meeting':
        return VoiceNoteCategory.meeting;
      case 'note':
        return VoiceNoteCategory.note;
      default:
        return VoiceNoteCategory.note;
    }
  }

  /// Whether AI has processed this memo
  bool get isAiProcessed => summary != null && processingStatus == 'ready';

  /// Whether AI is currently processing this memo
  bool get isAiProcessing {
    final s = processingStatus;
    return s == 'summarizing' ||
        s == 'categorizing' ||
        s == 'extractingActions';
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
    String? summary,
    String? category,
    String? processingStatus,
    String? aiModel,
    DateTime? aiProcessedAt,
    bool? taskCreated,
    bool? calendarEventCreated,
    String? actionReviewState,
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
      summary: summary ?? this.summary,
      category: category ?? this.category,
      processingStatus: processingStatus ?? this.processingStatus,
      aiModel: aiModel ?? this.aiModel,
      aiProcessedAt: aiProcessedAt ?? this.aiProcessedAt,
      taskCreated: taskCreated ?? this.taskCreated,
      calendarEventCreated: calendarEventCreated ?? this.calendarEventCreated,
      actionReviewState: actionReviewState ?? this.actionReviewState,
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
        summary,
        category,
        processingStatus,
        aiModel,
        aiProcessedAt,
        taskCreated,
        calendarEventCreated,
        actionReviewState,
      ];
}
