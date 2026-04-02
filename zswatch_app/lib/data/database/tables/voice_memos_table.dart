import 'package:drift/drift.dart';

/// Voice memos table - recordings synced from ZSWatch
///
/// Stores metadata about voice recordings captured on the watch,
/// their sync status, local file paths after download, and
/// transcription results.
@DataClassName('VoiceMemoEntity')
class VoiceMemos extends Table {
  /// Auto-incrementing row identifier
  IntColumn get id => integer().autoIncrement()();

  /// Original filename on the watch (e.g., "20260304_143022")
  TextColumn get filename => text()();

  /// Recording timestamp as Unix epoch seconds (UTC)
  IntColumn get timestampUtc => integer().named('timestamp_utc')();

  /// Recording duration in milliseconds
  IntColumn get durationMs => integer().named('duration_ms')();

  /// File size in bytes (Opus-encoded .zsw_opus)
  IntColumn get sizeBytes => integer().named('size_bytes')();

  /// Local file path after download (null = not yet downloaded)
  TextColumn get localFilePath => text().nullable().named('local_file_path')();

  /// Transcription text (null = not yet transcribed)
  TextColumn get transcription => text().nullable()();

  /// Whether the file has been synced (downloaded) from the watch
  BoolColumn get syncedFromWatch =>
      boolean().withDefault(const Constant(false)).named('synced_from_watch')();

  /// Whether the file has been deleted on the watch after sync
  BoolColumn get deletedOnWatch =>
      boolean().withDefault(const Constant(false)).named('deleted_on_watch')();

  /// When the file was downloaded to the phone
  DateTimeColumn get downloadedAt =>
      dateTime().nullable().named('downloaded_at')();

  /// When the transcription was completed
  DateTimeColumn get transcribedAt =>
      dateTime().nullable().named('transcribed_at')();

  /// Path to converted audio file (WAV/Ogg) for playback/transcription
  TextColumn get convertedFilePath =>
      text().nullable().named('converted_file_path')();

  // ==================== AI-Enhanced Fields ====================

  /// AI-generated summary of the voice note
  TextColumn get summary => text().nullable()();

  /// AI-assigned category: 'idea', 'task', 'reminder', 'meeting', 'note'
  TextColumn get category => text().nullable()();

  /// Current AI processing status: 'pending', 'summarizing', 'categorizing',
  /// 'extractingActions', 'ready', 'failed'
  TextColumn get processingStatus =>
      text().nullable().named('processing_status')();

  /// Which AI model was used for processing
  TextColumn get aiModel => text().nullable().named('ai_model')();

  /// When AI processing completed
  DateTimeColumn get aiProcessedAt =>
      dateTime().nullable().named('ai_processed_at')();

  /// Whether a task has been created from this memo's suggestions
  BoolColumn get taskCreated =>
      boolean().withDefault(const Constant(false)).named('task_created')();

  /// Whether a calendar event has been created from this memo's suggestions
  BoolColumn get calendarEventCreated => boolean()
      .withDefault(const Constant(false))
      .named('calendar_event_created')();

  /// Review state for extracted actions: 'pending', 'reviewed', 'dismissed'
  TextColumn get actionReviewState =>
      text().nullable().named('action_review_state')();

  /// Whether this memo has been archived by the user
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}
