import 'package:flutter/foundation.dart';

/// Direction of the log entry (incoming from watch or outgoing to watch)
enum LogDirection {
  incoming,
  outgoing,
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
@immutable
class LogEntry {
  /// Unique identifier for this entry
  final int id;

  /// Timestamp when the entry was received/sent
  final DateTime timestamp;

  /// The raw message content
  final String message;

  /// The parsed message type (from 't' field in JSON)
  final String? messageType;

  /// Categorized type for filtering
  final LogEntryType type;

  /// Direction (incoming from watch or outgoing to watch)
  final LogDirection direction;

  /// Whether this is a JSON message (vs raw text/log)
  final bool isJson;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.message,
    this.messageType,
    required this.type,
    required this.direction,
    this.isJson = false,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timestamp == other.timestamp &&
          message == other.message;

  @override
  int get hashCode => Object.hash(id, timestamp, message);

  @override
  String toString() =>
      'LogEntry(id: $id, type: $type, direction: $direction, message: $message)';
}
