import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_entry.freezed.dart';

/// Direction of the log entry (incoming from watch or outgoing to watch)
enum LogDirection { incoming, outgoing }

/// Log level parsed from log messages (`<dbg>`, `<inf>`, `<wrn>`, `<err>`)
enum LogLevel {
  debug, // <dbg>
  info, // <inf>
  warning, // <wrn>
  error, // <err>
  unknown, // No level tag found
}

/// Type of log entry to enable filtering
enum LogEntryType {
  /// Raw log message from watch (t:"log" or raw text)
  log,

  /// Notification-related messages (t:"notify", etc.)
  notification,

  /// Music-related messages (t:"music", t:"musicstate", t:"musicinfo")
  music,

  /// Activity/health messages (t:"act", t:"actfetch")
  activity,

  /// Device info/status messages (t:"ver", t:"status")
  status,

  /// GPS-related messages (t:"gps", t:"gps_power")
  gps,

  /// Weather messages (t:"weather")
  weather,

  /// Call-related messages (t:"call")
  call,

  /// Find device messages (t:"find", t:"findPhone")
  find,

  /// Navigation messages (t:"nav")
  navigation,

  /// HTTP relay messages (t:"http")
  http,

  /// Alarm messages (t:"alarm")
  alarm,

  /// Calendar sync messages (t:"force_calendar_sync")
  calendar,

  /// Alert/info/warn/error messages
  alert,

  /// Unknown or other message types
  other,
}

/// A single log entry representing BLE NUS data
@freezed
abstract class LogEntry with _$LogEntry {
  const LogEntry._();

  const factory LogEntry({
    /// Unique identifier for this entry
    required int id,

    /// Timestamp when the entry was received/sent
    required DateTime timestamp,

    /// The raw message content
    required String message,

    /// The parsed message type (from 't' field in JSON)
    String? messageType,

    /// Categorized type for filtering
    required LogEntryType type,

    /// Direction (incoming from watch or outgoing to watch)
    required LogDirection direction,

    /// Whether this is a JSON message (vs raw text/log)
    @Default(false) bool isJson,
  }) = _LogEntry;

  /// Create a log entry from incoming BLE data
  factory LogEntry.incoming({
    required int id,
    required String message,
    String? messageType,
    LogEntryType? type,
    bool isJson = false,
  }) {
    return LogEntry(
      id: id,
      timestamp: DateTime.now(),
      message: message,
      messageType: messageType,
      type: type ?? _inferType(messageType, message),
      direction: LogDirection.incoming,
      isJson: isJson,
    );
  }

  /// Create a log entry from outgoing BLE data
  factory LogEntry.outgoing({
    required int id,
    required String message,
    String? messageType,
    LogEntryType? type,
    bool isJson = false,
  }) {
    return LogEntry(
      id: id,
      timestamp: DateTime.now(),
      message: message,
      messageType: messageType,
      type: type ?? _inferType(messageType, message),
      direction: LogDirection.outgoing,
      isJson: isJson,
    );
  }

  /// Infer the log entry type from the message type or content
  static LogEntryType _inferType(String? messageType, String message) {
    if (messageType == null) {
      // Check if it looks like a raw log message
      if (!message.startsWith('{') && !message.startsWith('GB(')) {
        return LogEntryType.log;
      }
      return LogEntryType.other;
    }

    switch (messageType) {
      case 'log':
        return LogEntryType.log;
      case 'notify':
      case 'notify-':
      case 'notify~':
        return LogEntryType.notification;
      case 'music':
      case 'musicstate':
      case 'musicinfo':
        return LogEntryType.music;
      case 'act':
      case 'actfetch':
        return LogEntryType.activity;
      case 'ver':
      case 'status':
        return LogEntryType.status;
      case 'gps':
      case 'gps_power':
      case 'is_gps_active':
        return LogEntryType.gps;
      case 'weather':
        return LogEntryType.weather;
      case 'call':
        return LogEntryType.call;
      case 'find':
      case 'findPhone':
        return LogEntryType.find;
      case 'nav':
        return LogEntryType.navigation;
      case 'http':
        return LogEntryType.http;
      case 'alarm':
        return LogEntryType.alarm;
      case 'force_calendar_sync':
        return LogEntryType.calendar;
      case 'info':
      case 'warn':
      case 'error':
        return LogEntryType.alert;
      default:
        return LogEntryType.other;
    }
  }

  /// Log level parsed from message (`<dbg>`, `<inf>`, `<wrn>`, `<err>`)
  /// Computed on-demand from message content to avoid issues with hot reload
  LogLevel get level {
    if (message.contains('<dbg>')) return LogLevel.debug;
    if (message.contains('<inf>')) return LogLevel.info;
    if (message.contains('<wrn>')) return LogLevel.warning;
    if (message.contains('<err>')) return LogLevel.error;
    return LogLevel.unknown;
  }

  /// Get a display-friendly type name
  String get typeDisplayName {
    switch (type) {
      case LogEntryType.log:
        return 'LOG';
      case LogEntryType.notification:
        return 'NOTIF';
      case LogEntryType.music:
        return 'MUSIC';
      case LogEntryType.activity:
        return 'ACT';
      case LogEntryType.status:
        return 'STATUS';
      case LogEntryType.gps:
        return 'GPS';
      case LogEntryType.weather:
        return 'WEATHER';
      case LogEntryType.call:
        return 'CALL';
      case LogEntryType.find:
        return 'FIND';
      case LogEntryType.navigation:
        return 'NAV';
      case LogEntryType.http:
        return 'HTTP';
      case LogEntryType.alarm:
        return 'ALARM';
      case LogEntryType.calendar:
        return 'CALENDAR';
      case LogEntryType.alert:
        return 'ALERT';
      case LogEntryType.other:
        return 'OTHER';
    }
  }

  /// Format the timestamp for display
  String get formattedTimestamp {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// Get direction arrow for display
  String get directionArrow => direction == LogDirection.incoming ? '←' : '→';

  /// Get display name for log level
  String get levelDisplayName {
    switch (level) {
      case LogLevel.debug:
        return 'DBG';
      case LogLevel.info:
        return 'INF';
      case LogLevel.warning:
        return 'WRN';
      case LogLevel.error:
        return 'ERR';
      case LogLevel.unknown:
        return '';
    }
  }
}
