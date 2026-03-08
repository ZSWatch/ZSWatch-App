import 'package:equatable/equatable.dart';

/// Type of extracted action from AI processing
enum ExtractedActionType {
  task,
  calendarEvent,
  reminder,
}

/// Domain model for an AI-extracted action from a voice memo
class ExtractedAction extends Equatable {
  final int id;
  final int memoId;
  final ExtractedActionType actionType;
  final String title;
  final String? notes;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? dueDate;
  final String? location;
  final int? reminderMinutes;
  final bool created;
  final bool dismissed;
  final String? platformTargetId;
  final DateTime? createdAt;

  const ExtractedAction({
    required this.id,
    required this.memoId,
    required this.actionType,
    required this.title,
    this.notes,
    this.startTime,
    this.endTime,
    this.dueDate,
    this.location,
    this.reminderMinutes,
    this.created = false,
    this.dismissed = false,
    this.platformTargetId,
    this.createdAt,
  });

  ExtractedAction copyWith({
    int? id,
    int? memoId,
    ExtractedActionType? actionType,
    String? title,
    String? notes,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? dueDate,
    String? location,
    int? reminderMinutes,
    bool? created,
    bool? dismissed,
    String? platformTargetId,
    DateTime? createdAt,
  }) {
    return ExtractedAction(
      id: id ?? this.id,
      memoId: memoId ?? this.memoId,
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      dueDate: dueDate ?? this.dueDate,
      location: location ?? this.location,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      created: created ?? this.created,
      dismissed: dismissed ?? this.dismissed,
      platformTargetId: platformTargetId ?? this.platformTargetId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert action type string from DB to enum
  static ExtractedActionType typeFromString(String value) {
    switch (value) {
      case 'task':
        return ExtractedActionType.task;
      case 'calendar_event':
        return ExtractedActionType.calendarEvent;
      case 'reminder':
        return ExtractedActionType.reminder;
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
    }
  }

  @override
  List<Object?> get props => [
        id,
        memoId,
        actionType,
        title,
        notes,
        startTime,
        endTime,
        dueDate,
        location,
        reminderMinutes,
        created,
        dismissed,
        platformTargetId,
        createdAt,
      ];
}
