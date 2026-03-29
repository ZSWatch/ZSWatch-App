import 'package:drift/drift.dart';

/// Extracted actions from AI processing of voice memos.
///
/// Each row represents a single task, reminder, or calendar event
/// suggestion produced by the local LLM from a parent voice memo.
@DataClassName('ExtractedActionEntity')
class ExtractedActions extends Table {
  /// Auto-incrementing row identifier
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to the parent voice memo
  IntColumn get memoId => integer().named('memo_id')();

  /// Action type: 'task', 'calendar_event', 'reminder'
  TextColumn get actionType => text().named('action_type')();

  /// AI-generated title for the action
  TextColumn get title => text()();

  /// Optional notes / body text
  TextColumn get notes => text().nullable()();

  /// Suggested start time (for calendar events)
  DateTimeColumn get startTime => dateTime().nullable().named('start_time')();

  /// Suggested end time (for calendar events)
  DateTimeColumn get endTime => dateTime().nullable().named('end_time')();

  /// Suggested due date (for tasks / reminders)
  DateTimeColumn get dueDate => dateTime().nullable().named('due_date')();

  /// Optional location
  TextColumn get location => text().nullable()();

  /// Reminder offset in minutes before the event
  IntColumn get reminderMinutes =>
      integer().nullable().named('reminder_minutes')();

  /// Whether this action has been created in the OS (calendar / reminders)
  BoolColumn get created => boolean().withDefault(const Constant(false))();

  /// Whether the user dismissed this suggestion
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();

  /// Platform-specific ID after creation (e.g. calendar event ID)
  TextColumn get platformTargetId =>
      text().nullable().named('platform_target_id')();

  /// Duration in seconds (for timer actions)
  IntColumn get durationSeconds =>
      integer().nullable().named('duration_seconds')();

  /// When this action was created in the OS
  DateTimeColumn get createdAt => dateTime().nullable().named('created_at')();
}
