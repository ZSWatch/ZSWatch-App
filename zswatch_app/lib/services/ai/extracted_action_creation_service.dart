import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/extracted_action.dart';

class PlatformCalendar {
  final int id;
  final String? displayName;
  final String? accountName;
  final String? accountType;
  final String? ownerAccount;
  final bool isPrimary;

  const PlatformCalendar({
    required this.id,
    this.displayName,
    this.accountName,
    this.accountType,
    this.ownerAccount,
    required this.isPrimary,
  });

  factory PlatformCalendar.fromMap(Map<dynamic, dynamic> map) {
    return PlatformCalendar(
      id: (map['id'] as num).toInt(),
      displayName: map['displayName'] as String?,
      accountName: map['accountName'] as String?,
      accountType: map['accountType'] as String?,
      ownerAccount: map['ownerAccount'] as String?,
      isPrimary: map['isPrimary'] as bool? ?? false,
    );
  }

  String get label {
    final name = displayName?.trim();
    final account = accountName?.trim();
    if (name != null &&
        name.isNotEmpty &&
        account != null &&
        account.isNotEmpty) {
      return '$name — $account';
    }
    return name?.isNotEmpty == true
        ? name!
        : (account?.isNotEmpty == true ? account! : 'Calendar $id');
  }

  bool get looksLocal {
    final combined = [
      displayName,
      accountName,
      accountType,
      ownerAccount,
    ].whereType<String>().join(' ').toLowerCase();
    return combined.contains('local');
  }
}

class ActionCreationDraft {
  final ExtractedActionType actionType;
  final String title;
  final String? notes;
  final DateTime? scheduledAt;
  final DateTime? endAt;
  final String? location;
  final int? reminderMinutes;
  final int? durationSeconds;

  /// Requests that the system clock app skip its UI. The clock app decides
  /// how to handle this request; dispatch alone is not a creation receipt.
  final bool skipUi;
  final int? platformCalendarId;

  const ActionCreationDraft({
    required this.actionType,
    required this.title,
    this.notes,
    this.scheduledAt,
    this.endAt,
    this.location,
    this.reminderMinutes,
    this.durationSeconds,
    this.skipUi = true,
    this.platformCalendarId,
  });

  factory ActionCreationDraft.fromAction(ExtractedAction action) {
    final scheduledAt = action.startTime ?? action.dueDate;
    final defaultEndAt =
        action.actionType == ExtractedActionType.calendarEvent &&
            scheduledAt != null
        ? (action.endTime ?? scheduledAt.add(const Duration(minutes: 30)))
        : action.endTime;

    return ActionCreationDraft(
      actionType: action.actionType,
      title: action.title,
      notes: action.notes,
      scheduledAt: scheduledAt,
      endAt: defaultEndAt,
      location: action.location,
      reminderMinutes:
          action.reminderMinutes ??
          (action.actionType == ExtractedActionType.reminder ? 0 : null),
      durationSeconds: action.durationSeconds,
      platformCalendarId: null,
    );
  }

  /// Adapter for the shared processor's persisted draft; no legacy DB IDs needed.
  factory ActionCreationDraft.fromVoiceResult(Map<Object?, Object?> action) {
    final type = action['type'];
    if (![
      'task',
      'calendar_event',
      'reminder',
      'timer',
      'alarm',
    ].contains(type)) {
      throw const FormatException('Unsupported action type');
    }
    DateTime? date(Object? value) =>
        value == null ? null : DateTime.parse(value as String).toLocal();
    final scheduled = date(action['start_time'] ?? action['due_date']);
    final actionType = ExtractedAction.typeFromString(type as String);
    return ActionCreationDraft(
      actionType: actionType,
      title: action['title'] as String,
      notes: action['notes'] as String?,
      location: action['location'] as String?,
      scheduledAt: scheduled,
      endAt: actionType == ExtractedActionType.calendarEvent
          ? scheduled?.add(const Duration(minutes: 30))
          : null,
      durationSeconds: (action['duration_seconds'] as num?)?.toInt(),
      reminderMinutes: actionType == ExtractedActionType.reminder ? 0 : null,
      skipUi: false,
    );
  }

  void validateForCreation({DateTime? now}) {
    if (title.trim().isEmpty) throw StateError('Enter a title.');
    if (actionType == ExtractedActionType.timer) {
      if (durationSeconds == null ||
          durationSeconds! <= 0 ||
          durationSeconds! > 2147483647) {
        throw StateError('Enter a positive timer duration.');
      }
      return;
    }
    if (scheduledAt == null) throw StateError('Choose a date and time.');
    if (actionType == ExtractedActionType.calendarEvent &&
        endAt != null &&
        !endAt!.isAfter(scheduledAt!)) {
      throw StateError('End time must be after start time.');
    }
    if (actionType == ExtractedActionType.alarm) {
      final current = now ?? DateTime.now();
      var next = DateTime(
        current.year,
        current.month,
        current.day,
        scheduledAt!.hour,
        scheduledAt!.minute,
      );
      if (!next.isAfter(current)) {
        next = DateTime(
          current.year,
          current.month,
          current.day + 1,
          scheduledAt!.hour,
          scheduledAt!.minute,
        );
      }
      if (scheduledAt!.year != next.year ||
          scheduledAt!.month != next.month ||
          scheduledAt!.day != next.day) {
        throw StateError(
          'Clock alarms support the next occurrence of this time. '
          'Use a calendar reminder for a later date.',
        );
      }
    }
  }

  ActionCreationDraft copyWith({
    ExtractedActionType? actionType,
    String? title,
    String? notes,
    DateTime? scheduledAt,
    DateTime? endAt,
    String? location,
    int? reminderMinutes,
    int? durationSeconds,
    bool? skipUi,
    int? platformCalendarId,
  }) {
    return ActionCreationDraft(
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      endAt: endAt ?? this.endAt,
      location: location ?? this.location,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      skipUi: skipUi ?? this.skipUi,
      platformCalendarId: platformCalendarId ?? this.platformCalendarId,
    );
  }

  Map<String, dynamic> toPlatformMap() {
    return {
      'actionType': ExtractedAction.typeToString(actionType),
      'title': title,
      'notes': notes,
      'scheduledAtMillis': scheduledAt?.millisecondsSinceEpoch,
      'endAtMillis': endAt?.millisecondsSinceEpoch,
      'location': location,
      'reminderMinutes': reminderMinutes,
      'durationSeconds': durationSeconds,
      'skipUi': skipUi,
      'calendarId': platformCalendarId,
    };
  }
}

class CreatedPlatformAction {
  final String? platformId;
  final String targetType;
  final String? calendarDisplayName;
  final String? calendarAccountName;

  /// True when the calendar sync adapter is disabled (isSyncable=0).
  /// The event was inserted locally but won't appear in Google Calendar
  /// until the user enables Calendar sync in Android Settings.
  final bool syncDisabled;

  const CreatedPlatformAction({
    required this.platformId,
    required this.targetType,
    this.calendarDisplayName,
    this.calendarAccountName,
    this.syncDisabled = false,
  });

  String get successMessage {
    final calendarSuffix =
        calendarDisplayName != null && calendarDisplayName!.isNotEmpty
        ? ' in ${calendarDisplayName!}'
        : '';

    switch (targetType) {
      case 'calendar_event':
        return 'Calendar event created$calendarSuffix';
      case 'reminder':
        return 'Reminder created$calendarSuffix';
      case 'calendar_reminder':
        return 'Calendar reminder created$calendarSuffix';
      case 'timer':
        return 'Timer sent to Clock';
      case 'alarm':
        return 'Alarm sent to Clock';
      default:
        return 'Action created$calendarSuffix';
    }
  }

  String? get syncWarningMessage {
    if (!syncDisabled) return null;
    return 'Calendar sync is disabled for this account. '
        'Events are saved locally but won\u2019t appear in Google Calendar '
        'until you enable Calendar sync in Android Settings.';
  }
}

/// Sync health diagnostics returned by [ExtractedActionCreationService.checkCalendarSyncHealth].
class CalendarSyncHealth {
  final bool hasCalendar;
  final bool syncWorking;
  final int isSyncable;
  final bool autoSync;
  final bool masterSync;
  final int? calendarId;
  final String? calendarDisplayName;
  final String? accountName;
  final String? accountType;
  final bool isLocal;

  const CalendarSyncHealth({
    required this.hasCalendar,
    required this.syncWorking,
    this.isSyncable = -1,
    this.autoSync = false,
    this.masterSync = false,
    this.calendarId,
    this.calendarDisplayName,
    this.accountName,
    this.accountType,
    this.isLocal = false,
  });

  factory CalendarSyncHealth.fromMap(Map<dynamic, dynamic> map) {
    return CalendarSyncHealth(
      hasCalendar: map['hasCalendar'] as bool? ?? false,
      syncWorking: map['syncWorking'] as bool? ?? false,
      isSyncable: (map['isSyncable'] as num?)?.toInt() ?? -1,
      autoSync: map['autoSync'] as bool? ?? false,
      masterSync: map['masterSync'] as bool? ?? false,
      calendarId: (map['calendarId'] as num?)?.toInt(),
      calendarDisplayName: map['calendarDisplayName'] as String?,
      accountName: map['accountName'] as String?,
      accountType: map['accountType'] as String?,
      isLocal: map['isLocal'] as bool? ?? false,
    );
  }
}

class ExtractedActionCreationService {
  static const MethodChannel _channel = MethodChannel(
    'dev.zswatch.app/productivity',
  );

  const ExtractedActionCreationService();

  Future<List<PlatformCalendar>> prepareCompanionAction(
    ActionCreationDraft draft,
  ) async {
    await _ensurePermissions(draft.actionType);
    if (draft.actionType == ExtractedActionType.timer ||
        draft.actionType == ExtractedActionType.alarm) {
      return [];
    }
    return listWritableCalendars();
  }

  Future<void> createCompanionDraft(
    String jobId,
    int index,
    ActionCreationDraft draft,
  ) async {
    draft.validateForCreation();
    await _ensurePermissions(draft.actionType);
    await _channel.invokeMethod<void>('companionAction', {
      'jobId': jobId,
      'index': index,
      'operation': 'create',
      'draft': draft.toPlatformMap(),
    });
  }

  Future<void> dismissCompanionAction(String jobId, int index) async {
    await _channel.invokeMethod<void>('companionAction', {
      'jobId': jobId,
      'index': index,
      'operation': 'dismiss',
    });
  }

  Future<void> recoverCompanionAction(
    String jobId,
    int index,
    Map<Object?, Object?> confirmedDraft,
  ) async {
    await _ensurePermissions(
      ExtractedAction.typeFromString(confirmedDraft['actionType'] as String),
    );
    await _channel.invokeMethod<void>('companionAction', {
      'jobId': jobId,
      'index': index,
      'operation': 'create',
      'draft': confirmedDraft,
    });
  }

  Future<void> undoCompanionAction(String jobId, int index) async {
    await _ensurePermissions(ExtractedActionType.calendarEvent);
    await _channel.invokeMethod<void>('companionAction', {
      'jobId': jobId,
      'index': index,
      'operation': 'undo',
    });
  }

  Future<void> openCompanionCalendarEntry(String id, DateTime? scheduledAt) =>
      _openCreatedCalendarEntryIfSupported(
        platformId: id,
        targetType: 'calendar_event',
        scheduledAtMillis: scheduledAt?.millisecondsSinceEpoch,
      );

  Future<List<PlatformCalendar>> listWritableCalendars() async {
    if (!Platform.isAndroid) {
      return const [];
    }

    // Only check permission status — don't request it here.
    // The user grants calendar permission via the explicit "Grant" button
    // in the AI settings screen.
    final status = await Permission.calendarFullAccess.status;
    if (!status.isGranted) {
      return const [];
    }

    final result = await _channel.invokeListMethod<dynamic>(
      'listWritableCalendars',
    );
    if (result == null) {
      return const [];
    }

    return result
        .whereType<Map<dynamic, dynamic>>()
        .map(PlatformCalendar.fromMap)
        .toList(growable: false);
  }

  Future<CreatedPlatformAction> createDraft(ActionCreationDraft draft) async {
    await _ensurePermissions(draft.actionType);

    debugPrint(
      '[ExtractedActionCreation] Creating ${ExtractedAction.typeToString(draft.actionType)} '
      'title="${draft.title}" scheduledAt=${draft.scheduledAt?.toIso8601String()}',
    );

    final result = await _invokeCreateAction(draft);

    if (result == null) {
      throw StateError('Native action creation returned no result.');
    }

    debugPrint('[ExtractedActionCreation] Native result: $result');

    // Don't auto-open Google Calendar after creation — locally-inserted events
    // may not appear until Google Calendar syncs. The user can tap "Open" later.

    final syncDisabled = result['syncDisabled'] as bool? ?? false;
    if (syncDisabled) {
      debugPrint(
        '[ExtractedActionCreation] WARNING: Calendar sync is disabled! '
        'Event saved locally but won\u2019t sync to Google.',
      );
    }

    return CreatedPlatformAction(
      platformId: result['platformId'] as String?,
      targetType: (result['targetType'] as String?) ?? 'action',
      calendarDisplayName: result['calendarDisplayName'] as String?,
      calendarAccountName: result['calendarAccountName'] as String?,
      syncDisabled: syncDisabled,
    );
  }

  Future<void> openCreatedAction(ExtractedAction action) async {
    if (!Platform.isAndroid || action.platformTargetId == null) {
      return;
    }

    // Timer/alarm are created via system intents — there's no calendar entry
    // to open afterwards, so skip them.
    if (action.actionType == ExtractedActionType.timer ||
        action.actionType == ExtractedActionType.alarm) {
      return;
    }

    final targetType = switch (action.actionType) {
      ExtractedActionType.calendarEvent => 'calendar_event',
      ExtractedActionType.task ||
      ExtractedActionType.reminder => 'calendar_reminder',
      ExtractedActionType.timer || ExtractedActionType.alarm => 'alarm',
    };

    await _openCreatedCalendarEntryIfSupported(
      platformId: action.platformTargetId,
      targetType: targetType,
      scheduledAtMillis:
          (action.startTime ?? action.dueDate)?.millisecondsSinceEpoch,
    );
  }

  Future<Map<String, dynamic>?> _invokeCreateAction(
    ActionCreationDraft draft,
  ) async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>(
        'createAction',
        draft.toPlatformMap(),
      );
    } on PlatformException catch (error) {
      debugPrint(
        '[ExtractedActionCreation] Native createAction failed '
        'code=${error.code} message=${error.message} details=${error.details}',
      );
      rethrow;
    }
  }

  Future<void> _openCreatedCalendarEntryIfSupported({
    required String? platformId,
    required String targetType,
    required int? scheduledAtMillis,
  }) async {
    if (platformId == null) {
      return;
    }

    if (targetType != 'calendar_event' && targetType != 'calendar_reminder') {
      return;
    }

    try {
      await _channel.invokeMethod<void>('openCalendarEntry', {
        'eventId': platformId,
        'scheduledAtMillis': scheduledAtMillis,
      });
    } on PlatformException catch (error) {
      debugPrint(
        '[ExtractedActionCreation] Failed to open created calendar entry '
        'code=${error.code} message=${error.message}',
      );
    }
  }

  Future<void> _ensurePermissions(ExtractedActionType actionType) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      throw UnsupportedError(
        'Action creation is only supported on Android and iOS.',
      );
    }

    // Timer/alarm use system intents (Android) or URL schemes (iOS) —
    // no calendar or notification permission needed on either platform.
    if (actionType == ExtractedActionType.timer ||
        actionType == ExtractedActionType.alarm) {
      return;
    }

    final permission = _permissionForActionType(actionType);
    final failureMessage = _failureMessageForActionType(actionType);

    await _requestPermission(permission, failureMessage);
  }

  Permission _permissionForActionType(ExtractedActionType actionType) {
    switch (actionType) {
      case ExtractedActionType.timer:
      case ExtractedActionType.alarm:
        // Timer/alarm use system intents — no calendar permissions needed.
        return Permission.notification;
      case ExtractedActionType.calendarEvent:
        return Permission.calendarFullAccess;
      case ExtractedActionType.task:
      case ExtractedActionType.reminder:
        return Platform.isAndroid
            ? Permission.calendarFullAccess
            : Permission.reminders;
    }
  }

  String _failureMessageForActionType(ExtractedActionType actionType) {
    if (Platform.isAndroid) {
      return actionType == ExtractedActionType.calendarEvent
          ? 'Calendar permission is required to create events.'
          : 'Calendar permission is required to create reminders on Android.';
    }

    return switch (actionType) {
      ExtractedActionType.calendarEvent =>
        'Calendar access is required to create events.',
      ExtractedActionType.task || ExtractedActionType.reminder =>
        'Reminders access is required to create reminders.',
      ExtractedActionType.timer || ExtractedActionType.alarm =>
        'Notification permission is required for timers and alarms.',
    };
  }

  Future<void> _requestPermission(
    Permission permission,
    String failureMessage,
  ) async {
    var status = await permission.status;
    debugPrint(
      '[ExtractedActionCreation] Permission $permission status before request: $status',
    );

    if (!status.isGranted) {
      status = await permission.request();
      debugPrint(
        '[ExtractedActionCreation] Permission $permission status after request: $status',
      );
    }

    if (!status.isGranted) {
      throw StateError(failureMessage);
    }
  }

  /// Check whether the CalendarProvider sync adapter is working for a specific
  /// calendar (or the best available one).
  ///
  /// Returns [CalendarSyncHealth] with diagnostics. Use [syncWorking] to
  /// decide whether to show a warning banner.
  Future<CalendarSyncHealth> checkCalendarSyncHealth({int? calendarId}) async {
    if (!Platform.isAndroid) {
      return const CalendarSyncHealth(hasCalendar: true, syncWorking: true);
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'checkCalendarSyncHealth',
        {'calendarId': calendarId},
      );
      if (result == null) {
        return const CalendarSyncHealth(hasCalendar: false, syncWorking: false);
      }
      return CalendarSyncHealth.fromMap(result);
    } on PlatformException catch (e) {
      debugPrint(
        '[ExtractedActionCreation] checkCalendarSyncHealth failed: ${e.message}',
      );
      return const CalendarSyncHealth(hasCalendar: false, syncWorking: false);
    }
  }

  /// Open Android Settings → Sync Settings so the user can enable Calendar sync
  /// for their Google account. This is a one-time action that fixes the
  /// "isSyncable=0" issue permanently.
  Future<bool> openCalendarSyncSettings({
    String? accountName,
    String? accountType,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<Object>(
        'openCalendarSyncSettings',
        {'accountName': accountName, 'accountType': accountType},
      );
      // Kotlin returns a String describing which settings page was opened
      return result != null;
    } on PlatformException catch (e) {
      debugPrint(
        '[ExtractedActionCreation] openCalendarSyncSettings failed: ${e.message}',
      );
      return false;
    }
  }
}
