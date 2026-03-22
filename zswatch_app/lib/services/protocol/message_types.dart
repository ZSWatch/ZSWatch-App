/// Message types for ZSWatch communication protocols
///
/// Defines enums and classes for Gadgetbridge and Extended API messages.
library;

/// Direction of BLE communication
enum CommDirection { incoming, outgoing }

/// Protocol type for BLE messages
enum ProtocolType { gadgetbridge, extended, mcumgr, unknown }

/// Gadgetbridge message types (Phone → Watch)
enum GadgetbridgeOutgoingType {
  setTime,
  notify,
  notifyUpdate,
  notifyRemove,
  alarm,
  findDevice,
  vibrate,
  weather,
  musicState,
  musicInfo,
  call,
  activityControl,
  activityFetch,
  gps,
  calendar,
  calendarRemove,
  navigation,
  navigationStop,
  httpResponse,
}

/// Gadgetbridge message types (Watch → Phone)
enum GadgetbridgeIncomingType {
  version,
  status,
  musicControl,
  findPhone,
  callControl,
  notificationAction,
  activityData,
  activityTracksList,
  activityTrackData,
  calendarSync,
  gpsPower,
  httpRequest,
  intent,
  fileWrite,
  coredump,
  info,
  warning,
  error,
}

/// Extended API message types
enum ExtendedApiType {
  healthSync,
  logStream,
  log,
  shell,
  shellResponse,
  voiceMemoList,
  voiceMemoFetch,
  voiceMemoData,
}

/// Music player state
enum MusicState { play, pause, stop }

/// Music control actions (from watch)
enum MusicControlAction { play, pause, next, previous, volumeUp, volumeDown }

/// Call state
enum CallState { accept, incoming, outgoing, reject, start, end, ignore }

/// Notification action (from watch)
enum NotificationAction { dismiss, dismissAll, open, mute, reply }

/// Log level for streaming logs
enum LogLevel { debug, info, warning, error }

/// Activity type from watch
enum ActivityType {
  unknown,
  notWorn,
  deepSleep,
  lightSleep,
  remSleep,
  activity,
  running,
  walking,
  swimming,
  cycling,
  exercise,
}

/// Weather condition codes (Gadgetbridge)
enum WeatherCondition {
  clear(0),
  cloudy(1),
  rain(2),
  snow(3),
  fog(4),
  thunderstorm(5),
  partlyCloudy(6);

  final int code;
  const WeatherCondition(this.code);
}

/// Parsed Gadgetbridge message base class
abstract class GadgetbridgeMessage {
  final String rawMessage;
  final DateTime receivedAt;

  GadgetbridgeMessage({required this.rawMessage, DateTime? receivedAt})
    : receivedAt = receivedAt ?? DateTime.now();
}

/// Version message from watch (includes fw_info fields: sha, dbg)
class VersionMessage extends GadgetbridgeMessage {
  final String firmwareVersion;
  final String? hardwareVersion;
  final String? commitSha;
  final bool isDebug;

  VersionMessage({
    required super.rawMessage,
    required this.firmwareVersion,
    this.hardwareVersion,
    this.commitSha,
    this.isDebug = false,
  });
}

/// Coredump availability message from watch
class CoredumpMessage extends GadgetbridgeMessage {
  final bool available;
  final String file;
  final int line;
  final String time;

  CoredumpMessage({
    required super.rawMessage,
    required this.available,
    required this.file,
    required this.line,
    required this.time,
  });
}

/// Status message from watch
class StatusMessage extends GadgetbridgeMessage {
  final int batteryLevel;
  final double? voltage;
  final bool isCharging;

  StatusMessage({
    required super.rawMessage,
    required this.batteryLevel,
    this.voltage,
    this.isCharging = false,
  });
}

/// Music control message from watch
class MusicControlMessage extends GadgetbridgeMessage {
  final MusicControlAction action;

  MusicControlMessage({required super.rawMessage, required this.action});
}

/// Activity data message from watch
class ActivityDataMessage extends GadgetbridgeMessage {
  final int? timestamp;
  final int? heartRate;
  final int? steps;
  final int? movement;
  final ActivityType? activityType;
  final bool isRealtime;

  ActivityDataMessage({
    required super.rawMessage,
    this.timestamp,
    this.heartRate,
    this.steps,
    this.movement,
    this.activityType,
    this.isRealtime = false,
  });
}

/// Find phone message from watch
class FindPhoneMessage extends GadgetbridgeMessage {
  final bool findEnabled;

  FindPhoneMessage({required super.rawMessage, required this.findEnabled});
}

/// Notification action message from watch
class NotificationActionMessage extends GadgetbridgeMessage {
  final int notificationId;
  final NotificationAction action;
  final String? replyMessage;
  final String? phoneNumber;

  NotificationActionMessage({
    required super.rawMessage,
    required this.notificationId,
    required this.action,
    this.replyMessage,
    this.phoneNumber,
  });
}

/// Call control message from watch
class CallControlMessage extends GadgetbridgeMessage {
  final CallState callState;

  CallControlMessage({required super.rawMessage, required this.callState});
}

/// Info/Warning/Error message from watch
class AlertMessage extends GadgetbridgeMessage {
  final LogLevel level;
  final String message;

  AlertMessage({
    required super.rawMessage,
    required this.level,
    required this.message,
  });
}

/// HTTP request message from watch
class HttpRequestMessage extends GadgetbridgeMessage {
  final String url;
  final String requestId;
  final String? xpath;
  final bool insecure;

  HttpRequestMessage({
    required super.rawMessage,
    required this.url,
    required this.requestId,
    this.xpath,
    this.insecure = false,
  });
}

/// GPS power request message from watch
class GpsPowerMessage extends GadgetbridgeMessage {
  final bool enabled;

  GpsPowerMessage({required super.rawMessage, required this.enabled});
}

/// Calendar sync request message from watch
class CalendarSyncMessage extends GadgetbridgeMessage {
  final List<int> existingIds;

  CalendarSyncMessage({required super.rawMessage, required this.existingIds});
}
