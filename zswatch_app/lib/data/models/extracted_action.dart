import 'package:freezed_annotation/freezed_annotation.dart';

part 'extracted_action.freezed.dart';

/// Type of extracted action from AI processing
enum ExtractedActionType { task, calendarEvent, reminder, timer, alarm }

/// Domain model for an AI-extracted action from a voice memo
@freezed
abstract class ExtractedAction with _$ExtractedAction {
  const ExtractedAction._();

  const factory ExtractedAction({
    required int id,
    required int memoId,
    required ExtractedActionType actionType,
    required String title,
    String? notes,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? dueDate,
    String? location,
    int? reminderMinutes,
    int? durationSeconds,
    @Default(false) bool created,
    @Default(false) bool dismissed,
    String? platformTargetId,
    DateTime? createdAt,
  }) = _ExtractedAction;

  /// Convert action type string from DB to enum
  static ExtractedActionType typeFromString(String value) {
    switch (value) {
      case 'task':
        return ExtractedActionType.task;
      case 'calendar_event':
        return ExtractedActionType.calendarEvent;
      case 'reminder':
        return ExtractedActionType.reminder;
      case 'timer':
        return ExtractedActionType.timer;
      case 'alarm':
        return ExtractedActionType.alarm;
      default:
        return ExtractedActionType.task;
    }
  }

  /// Convert enum to DB string
  static String typeToString(ExtractedActionType type) {
    switch (type) {
      case ExtractedActionType.task:
        return 'task';
      case ExtractedActionType.calendarEvent:
        return 'calendar_event';
      case ExtractedActionType.reminder:
        return 'reminder';
      case ExtractedActionType.timer:
        return 'timer';
      case ExtractedActionType.alarm:
        return 'alarm';
    }
  }
}
