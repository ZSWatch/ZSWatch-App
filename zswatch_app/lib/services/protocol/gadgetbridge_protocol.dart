import 'dart:async';
import 'dart:convert';

import '../ble/gatt_operations.dart';
import 'message_types.dart';
import 'protocol_service.dart';

/// Gadgetbridge protocol implementation
///
/// Implements the Gadgetbridge/Espruino protocol for communicating
/// with ZSWatch over BLE using Nordic UART Service (NUS).
///
/// Message format:
/// - Outgoing: `GB({json})` or `setTime(...);E.setTimeZone(...);`
/// - Incoming: `{json}` or custom formats
class GadgetbridgeProtocol implements ProtocolService {
  final GattOperations _gattOps;

  final _incomingMessagesController =
      StreamController<GadgetbridgeMessage>.broadcast();
  final _rawIncomingDataController = StreamController<String>.broadcast();

  StreamSubscription<String>? _nusSubscription;
  String _messageBuffer = '';

  GadgetbridgeProtocol(this._gattOps);

  @override
  Stream<GadgetbridgeMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  @override
  Stream<String> get rawIncomingData => _rawIncomingDataController.stream;

  @override
  Future<void> initialize() async {
    await _gattOps.setupNus();
    _nusSubscription = _gattOps.nusDataStream.listen(_handleIncomingData);
  }

  @override
  Future<void> dispose() async {
    await _nusSubscription?.cancel();
    await _incomingMessagesController.close();
    await _rawIncomingDataController.close();
  }

  void _handleIncomingData(String data) {
    _rawIncomingDataController.add(data);

    // Buffer data and process complete messages
    _messageBuffer += data;

    // Try to parse complete JSON objects
    while (_messageBuffer.isNotEmpty) {
      final trimmed = _messageBuffer.trim();
      if (!trimmed.startsWith('{')) {
        // Not JSON, might be some other format - discard up to next {
        final jsonStart = _messageBuffer.indexOf('{');
        if (jsonStart == -1) {
          _messageBuffer = '';
          break;
        }
        _messageBuffer = _messageBuffer.substring(jsonStart);
        continue;
      }

      // Try to parse JSON
      try {
        // Find the end of the JSON object (matching braces)
        var braceCount = 0;
        var jsonEnd = -1;
        for (var i = 0; i < _messageBuffer.length; i++) {
          if (_messageBuffer[i] == '{') braceCount++;
          if (_messageBuffer[i] == '}') braceCount--;
          if (braceCount == 0) {
            jsonEnd = i + 1;
            break;
          }
        }

        if (jsonEnd == -1) {
          // Incomplete JSON, wait for more data
          break;
        }

        final jsonStr = _messageBuffer.substring(0, jsonEnd);
        _messageBuffer = _messageBuffer.substring(jsonEnd);

        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final message = _parseMessage(json, jsonStr);
        if (message != null) {
          _incomingMessagesController.add(message);
        }
      } catch (e) {
        // Parse error, skip this character and try again
        if (_messageBuffer.isNotEmpty) {
          _messageBuffer = _messageBuffer.substring(1);
        }
      }
    }
  }

  GadgetbridgeMessage? _parseMessage(
    Map<String, dynamic> json,
    String rawMessage,
  ) {
    final type = json['t'] as String?;
    if (type == null) return null;

    switch (type) {
      case 'ver':
        return VersionMessage(
          rawMessage: rawMessage,
          firmwareVersion: json['fw'] as String? ?? 'unknown',
          hardwareVersion: json['hw'] as String?,
          commitSha: json['sha'] as String?,
          isDebug: json['dbg'] == 1,
        );

      case 'coredump':
        return CoredumpMessage(
          rawMessage: rawMessage,
          available: json['available'] == true,
          file: json['file'] as String? ?? '',
          line: json['line'] as int? ?? 0,
          time: json['time'] as String? ?? '',
        );

      case 'status':
        return StatusMessage(
          rawMessage: rawMessage,
          batteryLevel: json['bat'] as int? ?? 0,
          voltage: (json['volt'] as num?)?.toDouble(),
          isCharging: json['chg'] == 1,
        );

      case 'music':
        final action = _parseMusicControlAction(json['n'] as String?);
        if (action != null) {
          return MusicControlMessage(rawMessage: rawMessage, action: action);
        }
        return null;

      case 'findPhone':
        return FindPhoneMessage(
          rawMessage: rawMessage,
          findEnabled: json['n'] == true,
        );

      case 'call':
        final callState = _parseCallState(json['n'] as String?);
        if (callState != null) {
          return CallControlMessage(
            rawMessage: rawMessage,
            callState: callState,
          );
        }
        return null;

      case 'notify':
        return NotificationActionMessage(
          rawMessage: rawMessage,
          notificationId: json['id'] as int? ?? 0,
          action:
              _parseNotificationAction(json['n'] as String?) ??
              NotificationAction.dismiss,
          replyMessage: json['msg'] as String?,
          phoneNumber: json['tel'] as String?,
        );

      case 'act':
        return ActivityDataMessage(
          rawMessage: rawMessage,
          timestamp: json['ts'] as int?,
          heartRate: json['hrm'] as int?,
          steps: json['stp'] as int?,
          movement: json['mov'] as int?,
          activityType: _parseActivityType(json['act'] as String?),
          isRealtime: json['rt'] == true,
        );

      case 'gps_power':
        return GpsPowerMessage(
          rawMessage: rawMessage,
          enabled: json['status'] == true,
        );

      case 'force_calendar_sync':
        final ids =
            (json['ids'] as List<dynamic>?)?.map((e) => e as int).toList() ??
            [];
        return CalendarSyncMessage(rawMessage: rawMessage, existingIds: ids);

      case 'http':
        return HttpRequestMessage(
          rawMessage: rawMessage,
          url: json['url'] as String? ?? '',
          requestId: json['id'] as String? ?? '',
          xpath: json['xpath'] as String?,
          insecure: json['insecure'] == true,
        );

      case 'info':
        return AlertMessage(
          rawMessage: rawMessage,
          level: LogLevel.info,
          message: json['msg'] as String? ?? '',
        );

      case 'warn':
        return AlertMessage(
          rawMessage: rawMessage,
          level: LogLevel.warning,
          message: json['msg'] as String? ?? '',
        );

      case 'error':
        return AlertMessage(
          rawMessage: rawMessage,
          level: LogLevel.error,
          message: json['msg'] as String? ?? '',
        );

      default:
        return null;
    }
  }

  MusicControlAction? _parseMusicControlAction(String? action) {
    switch (action) {
      case 'play':
        return MusicControlAction.play;
      case 'pause':
        return MusicControlAction.pause;
      case 'next':
        return MusicControlAction.next;
      case 'previous':
        return MusicControlAction.previous;
      case 'volumeup':
        return MusicControlAction.volumeUp;
      case 'volumedown':
        return MusicControlAction.volumeDown;
      default:
        return null;
    }
  }

  CallState? _parseCallState(String? state) {
    switch (state?.toUpperCase()) {
      case 'ACCEPT':
        return CallState.accept;
      case 'END':
        return CallState.end;
      case 'INCOMING':
        return CallState.incoming;
      case 'OUTGOING':
        return CallState.outgoing;
      case 'REJECT':
        return CallState.reject;
      case 'START':
        return CallState.start;
      case 'IGNORE':
        return CallState.ignore;
      default:
        return null;
    }
  }

  NotificationAction? _parseNotificationAction(String? action) {
    switch (action) {
      case 'DISMISS':
        return NotificationAction.dismiss;
      case 'DISMISS_ALL':
        return NotificationAction.dismissAll;
      case 'OPEN':
        return NotificationAction.open;
      case 'MUTE':
        return NotificationAction.mute;
      case 'REPLY':
        return NotificationAction.reply;
      default:
        return null;
    }
  }

  ActivityType? _parseActivityType(String? type) {
    switch (type) {
      case 'UNKNOWN':
        return ActivityType.unknown;
      case 'NOT_WORN':
        return ActivityType.notWorn;
      case 'DEEP_SLEEP':
        return ActivityType.deepSleep;
      case 'LIGHT_SLEEP':
        return ActivityType.lightSleep;
      case 'REM_SLEEP':
        return ActivityType.remSleep;
      case 'ACTIVITY':
        return ActivityType.activity;
      case 'RUNNING':
        return ActivityType.running;
      case 'WALKING':
        return ActivityType.walking;
      case 'SWIMMING':
        return ActivityType.swimming;
      case 'CYCLING':
        return ActivityType.cycling;
      case 'EXERCISE':
        return ActivityType.exercise;
      default:
        return null;
    }
  }

  Future<void> _sendGb(Map<String, dynamic> data) async {
    final json = jsonEncode(data);
    await _gattOps.sendNusData('GB($json)');
  }

  Future<void> _sendRaw(String data) async {
    await _gattOps.sendNusData(data);
  }

  @override
  Future<void> syncTime(DateTime time, {double? timezoneOffsetHours}) async {
    final timestamp = time.millisecondsSinceEpoch ~/ 1000;
    final tz = timezoneOffsetHours ?? time.timeZoneOffset.inMinutes / 60.0;
    await _sendRaw('setTime($timestamp);E.setTimeZone($tz);');
  }

  @override
  Future<void> sendNotification(WatchNotification notification) async {
    final data = <String, dynamic>{
      't': 'notify',
      'id': notification.id,
      'src': notification.source,
    };
    if (notification.title != null) data['title'] = notification.title;
    if (notification.body != null) data['body'] = notification.body;
    if (notification.sender != null) data['sender'] = notification.sender;
    if (notification.subject != null) data['subject'] = notification.subject;
    if (notification.phoneNumber != null)
      data['tel'] = notification.phoneNumber;
    if (notification.canReply) data['reply'] = true;

    await _sendGb(data);
  }

  @override
  Future<void> updateNotification(int id, String body) async {
    await _sendGb({'t': 'notify~', 'id': id, 'body': body});
  }

  @override
  Future<void> removeNotification(int id) async {
    await _sendGb({'t': 'notify-', 'id': id});
  }

  @override
  Future<void> sendMusicState(WatchMusicState state) async {
    final data = <String, dynamic>{
      't': 'musicstate',
      'state': state.state == MusicState.play ? 'play' : 'pause',
    };
    if (state.positionSeconds != null) data['position'] = state.positionSeconds;
    if (state.shuffle) data['shuffle'] = 1;
    if (state.repeat) data['repeat'] = 1;

    await _sendGb(data);
  }

  @override
  Future<void> sendMusicInfo(WatchMusicInfo info) async {
    final data = <String, dynamic>{'t': 'musicinfo'};
    if (info.artist != null) data['artist'] = info.artist;
    if (info.album != null) data['album'] = info.album;
    if (info.track != null) data['track'] = info.track;
    if (info.durationSeconds != null) data['dur'] = info.durationSeconds;
    if (info.trackCount != null) data['c'] = info.trackCount;
    if (info.trackNumber != null) data['n'] = info.trackNumber;

    await _sendGb(data);
  }

  @override
  Future<void> sendWeather(WatchWeather weather) async {
    final data = <String, dynamic>{
      't': 'weather',
      'temp': weather.temperatureKelvin,
      'code': weather.condition.code,
    };
    if (weather.highKelvin != null) data['hi'] = weather.highKelvin;
    if (weather.lowKelvin != null) data['lo'] = weather.lowKelvin;
    if (weather.humidityPercent != null) data['hum'] = weather.humidityPercent;
    if (weather.rainProbability != null) data['rain'] = weather.rainProbability;
    if (weather.uvIndex != null) data['uv'] = weather.uvIndex;
    if (weather.description != null) data['txt'] = weather.description;
    if (weather.windSpeedMps != null) data['wind'] = weather.windSpeedMps;
    if (weather.windDirectionDegrees != null) {
      data['wdir'] = weather.windDirectionDegrees;
    }
    if (weather.location != null) data['loc'] = weather.location;

    await _sendGb(data);
  }

  @override
  Future<void> setAlarms(List<WatchAlarm> alarms) async {
    final alarmList = alarms
        .map(
          (a) => {
            'h': a.hour,
            'm': a.minute,
            'rep': a.repeatDaysMask,
            'on': a.enabled ? 1 : 0,
          },
        )
        .toList();

    await _sendGb({'t': 'alarm', 'd': alarmList});
  }

  @override
  Future<void> findDevice(bool enabled) async {
    await _sendGb({'t': 'find', 'n': enabled});
  }

  @override
  Future<void> vibrate(int pattern) async {
    await _sendGb({'t': 'vibrate', 'n': pattern});
  }

  @override
  Future<void> requestDeviceInfo() async {
    // The watch automatically sends version info on connect,
    // but we can request it explicitly by sending an empty message
    // that triggers a response (implementation may vary)
    await _sendGb({'t': 'ver'});
  }

  @override
  Future<void> setActivityTracking({
    bool heartRate = false,
    bool steps = false,
    int? intervalSeconds,
  }) async {
    final data = <String, dynamic>{'t': 'act', 'hrm': heartRate, 'stp': steps};
    if (intervalSeconds != null) data['int'] = intervalSeconds;

    await _sendGb(data);
  }

  @override
  Future<void> fetchActivityData({int? sinceTimestampMs}) async {
    await _sendGb({'t': 'actfetch', 'ts': sinceTimestampMs ?? 0});
  }

  @override
  Future<void> sendGpsData(WatchGpsData data) async {
    final gpsData = <String, dynamic>{
      't': 'gps',
      'lat': data.latitude,
      'lon': data.longitude,
      'externalSource': true,
    };
    if (data.altitude != null) gpsData['alt'] = data.altitude;
    if (data.speedKph != null) gpsData['speed'] = data.speedKph;
    if (data.courseDegrees != null) gpsData['course'] = data.courseDegrees;
    if (data.timestampMs != null) gpsData['time'] = data.timestampMs;
    if (data.satellites != null) gpsData['satellites'] = data.satellites;
    if (data.hdop != null) gpsData['hdop'] = data.hdop;
    if (data.source != null) gpsData['gpsSource'] = data.source;

    await _sendGb(gpsData);
  }

  @override
  Future<void> queryGpsActive() async {
    await _sendGb({'t': 'is_gps_active'});
  }

  @override
  Future<void> sendCall(WatchCall call) async {
    final data = <String, dynamic>{'t': 'call', 'cmd': call.state.name};
    if (call.name != null) data['name'] = call.name;
    if (call.number != null) data['number'] = call.number;

    await _sendGb(data);
  }

  @override
  Future<void> sendNavigation(WatchNavigation navigation) async {
    await _sendGb({
      't': 'nav',
      'instr': navigation.instruction,
      'distance': navigation.distance,
      if (navigation.action != null) 'action': navigation.action,
      if (navigation.eta != null) 'eta': navigation.eta,
    });
  }

  @override
  Future<void> stopNavigation() async {
    await _sendGb({'t': 'nav'});
  }

  @override
  Future<void> sendHttpResponse(String requestId, String response) async {
    await _sendGb({'t': 'http', 'id': requestId, 'resp': response});
  }

  @override
  Future<void> sendHttpError(String requestId, String error) async {
    await _sendGb({'t': 'http', 'id': requestId, 'err': error});
  }
}
