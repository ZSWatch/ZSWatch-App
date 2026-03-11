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
    if (name != null && name.isNotEmpty && account != null && account.isNotEmpty) {
      return '$name — $account';
    }
    return name?.isNotEmpty == true
        ? name!
        : (account?.isNotEmpty == true ? account! : 'Calendar $id');
  }

  bool get looksLocal {
    final combined = [displayName, accountName, accountType, ownerAccount]
        .whereType<String>()
        .join(' ')
        .toLowerCase();
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
  final int? platformCalendarId;

  const ActionCreationDraft({
    required this.actionType,
    required this.title,
    this.notes,
    this.scheduledAt,
    this.endAt,
    this.location,
    this.reminderMinutes,
    this.platformCalendarId,
  });

  factory ActionCreationDraft.fromAction(ExtractedAction action) {
    final scheduledAt = action.startTime ?? action.dueDate;
    final defaultEndAt = action.actionType == ExtractedActionType.calendarEvent &&
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
      reminderMinutes: action.reminderMinutes ??
          (action.actionType == ExtractedActionType.reminder ? 0 : null),
      platformCalendarId: null,
    );
  }

  ActionCreationDraft copyWith({
    ExtractedActionType? actionType,
    String? title,
    String? notes,
    DateTime? scheduledAt,
    DateTime? endAt,
    String? location,
    int? reminderMinutes,
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
    final calendarSuffix = calendarDisplayName != null && calendarDisplayName!.isNotEmpty
        ? ' in ${calendarDisplayName!}'
        : '';

    switch (targetType) {
      case 'calendar_event':
        return 'Calendar event created$calendarSuffix';
      case 'reminder':
        return 'Reminder created$calendarSuffix';
      case 'calendar_reminder':
        return 'Calendar reminder created$calendarSuffix';
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
  static const MethodChannel _channel =
      MethodChannel('dev.zswatch.app/productivity');

  const ExtractedActionCreationService();

  Future<List<PlatformCalendar>> listWritableCalendars() async {
    if (!Platform.isAndroid) {
      return const [];
    }

    await _requestPermission(
      Permission.calendarFullAccess,
      'Calendar permission is required to load calendars.',
    );

    final result = await _channel.invokeListMethod<dynamic>('listWritableCalendars');
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

    final targetType = switch (action.actionType) {
      ExtractedActionType.calendarEvent => 'calendar_event',
      ExtractedActionType.task || ExtractedActionType.reminder =>
        'calendar_reminder',
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

    final permission = _permissionForActionType(actionType);
    final failureMessage = _failureMessageForActionType(actionType);

    await _requestPermission(permission, failureMessage);
  }

  Permission _permissionForActionType(ExtractedActionType actionType) {
    if (Platform.isAndroid) {
      return Permission.calendarFullAccess;
    }

    switch (actionType) {
      case ExtractedActionType.calendarEvent:
        return Permission.calendarFullAccess;
      case ExtractedActionType.task:
      case ExtractedActionType.reminder:
        return Permission.reminders;
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
      debugPrint('[ExtractedActionCreation] checkCalendarSyncHealth failed: ${e.message}');
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
        {
          'accountName': accountName,
          'accountType': accountType,
        },
      );
      // Kotlin returns a String describing which settings page was opened
      return result != null;
    } on PlatformException catch (e) {
      debugPrint('[ExtractedActionCreation] openCalendarSyncSettings failed: ${e.message}');
      return false;
    }
  }
}
