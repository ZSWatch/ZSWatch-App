import 'dart:async';

import 'message_types.dart';

/// Notification data to send to watch
class WatchNotification {
  final int id;
  final String source;
  final String? title;
  final String? body;
  final String? sender;
  final String? subject;
  final String? phoneNumber;
  final bool canReply;

  const WatchNotification({
    required this.id,
    required this.source,
    this.title,
    this.body,
    this.sender,
    this.subject,
    this.phoneNumber,
    this.canReply = false,
  });
}

/// Music information to send to watch
class WatchMusicInfo {
  final String? artist;
  final String? album;
  final String? track;
  final int? durationSeconds;
  final int? trackNumber;
  final int? trackCount;

  const WatchMusicInfo({
    this.artist,
    this.album,
    this.track,
    this.durationSeconds,
    this.trackNumber,
    this.trackCount,
  });
}

/// Music state to send to watch
class WatchMusicState {
  final MusicState state;
  final int? positionSeconds;
  final bool shuffle;
  final bool repeat;

  const WatchMusicState({
    required this.state,
    this.positionSeconds,
    this.shuffle = false,
    this.repeat = false,
  });
}

/// Weather data to send to watch
class WatchWeather {
  final int temperatureKelvin;
  final int? highKelvin;
  final int? lowKelvin;
  final int? humidityPercent;
  final int? rainProbability;
  final int? uvIndex;
  final WeatherCondition condition;
  final String? description;
  final double? windSpeedMps;
  final int? windDirectionDegrees;
  final String? location;

  const WatchWeather({
    required this.temperatureKelvin,
    this.highKelvin,
    this.lowKelvin,
    this.humidityPercent,
    this.rainProbability,
    this.uvIndex,
    required this.condition,
    this.description,
    this.windSpeedMps,
    this.windDirectionDegrees,
    this.location,
  });
}

/// Alarm data to send to watch
class WatchAlarm {
  final int hour;
  final int minute;
  final int repeatDaysMask;
  final bool enabled;

  const WatchAlarm({
    required this.hour,
    required this.minute,
    required this.repeatDaysMask,
    this.enabled = true,
  });
}

/// GPS data to send to watch
class WatchGpsData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speedKph;
  final double? courseDegrees;
  final int? timestampMs;
  final int? satellites;
  final double? hdop;
  final String? source;

  const WatchGpsData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speedKph,
    this.courseDegrees,
    this.timestampMs,
    this.satellites,
    this.hdop,
    this.source,
  });
}

/// Call information to send to watch
class WatchCall {
  final CallState state;
  final String? name;
  final String? number;

  const WatchCall({
    required this.state,
    this.name,
    this.number,
  });
}

/// Navigation instruction to send to watch
class WatchNavigation {
  final String instruction;
  final String distance;
  final String? action;
  final String? eta;

  const WatchNavigation({
    required this.instruction,
    required this.distance,
    this.action,
    this.eta,
  });
}

/// Abstract protocol service interface
///
/// Defines the contract for communicating with the watch using
/// either Gadgetbridge or Extended API protocols.
abstract class ProtocolService {
  /// Stream of incoming messages from the watch
  Stream<GadgetbridgeMessage> get incomingMessages;

  /// Stream of raw incoming data (for comm logging)
  Stream<String> get rawIncomingData;

  /// Initialize the protocol service (subscribe to BLE notifications)
  Future<void> initialize();

  /// Dispose resources
  Future<void> dispose();

  // ==================== Time ====================

  /// Sync time to watch
  Future<void> syncTime(DateTime time, {double? timezoneOffsetHours});

  // ==================== Notifications ====================

  /// Send a notification to the watch
  Future<void> sendNotification(WatchNotification notification);

  /// Update an existing notification
  Future<void> updateNotification(int id, String body);

  /// Remove a notification
  Future<void> removeNotification(int id);

  // ==================== Music ====================

  /// Send music state (play/pause)
  Future<void> sendMusicState(WatchMusicState state);

  /// Send music info (track, artist, album)
  Future<void> sendMusicInfo(WatchMusicInfo info);

  // ==================== Weather ====================

  /// Send weather data
  Future<void> sendWeather(WatchWeather weather);

  // ==================== Alarms ====================

  /// Set alarms on watch
  Future<void> setAlarms(List<WatchAlarm> alarms);

  // ==================== Device Control ====================

  /// Start/stop find device (vibrate watch)
  Future<void> findDevice(bool enabled);

  /// Vibrate watch with pattern
  Future<void> vibrate(int pattern);

  /// Request device info (triggers version message)
  Future<void> requestDeviceInfo();

  // ==================== Activity ====================

  /// Enable/disable realtime activity tracking
  Future<void> setActivityTracking({
    bool heartRate = false,
    bool steps = false,
    int? intervalSeconds,
  });

  /// Request activity data from watch
  Future<void> fetchActivityData({int? sinceTimestampMs});

  // ==================== GPS ====================

  /// Send GPS data to watch
  Future<void> sendGpsData(WatchGpsData data);

  /// Query GPS active status
  Future<void> queryGpsActive();

  // ==================== Calls ====================

  /// Send call information
  Future<void> sendCall(WatchCall call);

  // ==================== Navigation ====================

  /// Send navigation instruction
  Future<void> sendNavigation(WatchNavigation navigation);

  /// Stop navigation
  Future<void> stopNavigation();

  // ==================== HTTP ====================

  /// Send HTTP response (for watch HTTP requests)
  Future<void> sendHttpResponse(String requestId, String response);

  /// Send HTTP error (for watch HTTP requests)
  Future<void> sendHttpError(String requestId, String error);
}

