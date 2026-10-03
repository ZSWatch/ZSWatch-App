import 'package:flutter/services.dart';

import '../../data/models/connection.dart';
import '../../data/models/connection_phase.dart';
import '../../data/models/connection_state.dart';
import '../../data/models/watch.dart';
import '../../data/models/companion_notification_status.dart';
import '../../data/models/companion_http_status.dart';

/// V1 snapshot survives UI attachment changes; events are diagnostic replay.
class CompanionPrototypeSnapshot {
  final Map<String, Object?> fields;

  CompanionPrototypeSnapshot._(this.fields);

  factory CompanionPrototypeSnapshot.decode(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['owner'] != 'android_service_native' ||
        value['runtime_active'] is! bool ||
        value['protocol_ready'] is! bool ||
        value['phase'] is! String ||
        value['event_cursor'] is! int ||
        value['generation'] is! int ||
        value['events'] is! List ||
        value['recordings'] is! Map) {
      throw const FormatException('Unsupported companion snapshot');
    }
    return CompanionPrototypeSnapshot._(Map<String, Object?>.from(value));
  }

  String get phase => fields['phase']! as String;
  bool get runtimeActive => fields['runtime_active']! as bool;
  bool get protocolReady => fields['protocol_ready']! as bool;
  int get cursor => fields['event_cursor']! as int;
  int get generation => fields['generation']! as int;
  Map<String, Object?> get recordings =>
      Map<String, Object?>.from(fields['recordings']! as Map);

  /// Existing UI domain models, derived solely from the service snapshot.
  /// Cached Ready cannot make an absent service appear connected.
  ConnectionPhase get connectionPhase {
    if (!runtimeActive) return const ConnectionPhase.disconnected();
    if (protocolReady) return const ConnectionPhase.connected();
    return switch (phase) {
      'connecting' => const ConnectionPhase.connecting(),
      'discovering' => const ConnectionPhase.settingUp(
        step: SetupStep.discoveringServices,
      ),
      'subscribing' => const ConnectionPhase.settingUp(
        step: SetupStep.negotiating,
      ),
      'disconnected' => const ConnectionPhase.reconnecting(
        attempt: 0,
        isBackground: true,
      ),
      'error' => ConnectionPhase.error(
        type: ConnectionErrorType.unknown,
        details: fields['last_error'] as String?,
      ),
      _ => const ConnectionPhase.disconnected(),
    };
  }

  Map<Object?, Object?>? get _watchInfo {
    final info = fields['watch_info'];
    return info is Map && info['address'] == fields['address'] ? info : null;
  }

  bool get hasLiveStatus =>
      protocolReady && _watchInfo?['status_generation'] == generation;

  Watch? get watch {
    final address = fields['address'];
    if (address is! String || address.isEmpty) return null;
    final info = _watchInfo;
    final battery = info?['battery_level'];
    return Watch(
      id: address,
      name: 'ZSWatch',
      firmwareVersion: info?['firmware_version'] as String?,
      hardwareVersion: info?['hardware_version'] as String?,
      batteryLevel: battery is int && battery >= 0 && battery <= 100
          ? battery
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        info?['first_seen_ms'] is int ? info!['first_seen_ms'] as int : 0,
      ),
    );
  }

  Connection get connection => Connection(
    watchId: watch?.id ?? '',
    watchName: watch?.name,
    state: connectionPhase.watchConnectionState,
    mtu: fields['att_payload_bytes'] is int
        ? (fields['att_payload_bytes']! as int) + 3
        : null,
    isCharging: _watchInfo?['is_charging'] == true,
    errorDetails: fields['last_error'] as String?,
  );
}

/// Observer/commands only. Disposing this client never stops the native service.
class CompanionPrototypeClient {
  final MethodChannel methods;
  final EventChannel events;

  const CompanionPrototypeClient({
    this.methods = const MethodChannel('dev.zswatch.app/companion_v1'),
    this.events = const EventChannel('dev.zswatch.app/companion_events_v1'),
  });

  Stream<CompanionPrototypeSnapshot> watch() => events
      .receiveBroadcastStream({'version': 1})
      .map(CompanionPrototypeSnapshot.decode);

  Future<CompanionPrototypeSnapshot> snapshot() async =>
      CompanionPrototypeSnapshot.decode(
        await methods.invokeMethod<Object?>('snapshot', {'version': 1}),
      );

  Future<CompanionNotificationStatus> notificationStatus() async =>
      CompanionNotificationStatus.decode(
        await methods.invokeMethod<Object?>('notificationStatus', {
          'version': 1,
        }),
      );

  Future<CompanionPrototypeSnapshot> setRecordingSync(bool enabled) async =>
      CompanionPrototypeSnapshot.decode(
        await methods.invokeMethod<Object?>('setRecordingSync', {
          'version': 1,
          'enabled': enabled,
        }),
      );

  Future<CompanionPrototypeSnapshot> configureHttp(bool enabled) async {
    final result = CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('configureHttp', {
        'version': 1,
        'enabled': enabled,
      }),
    );
    if (result.fields['http_enabled'] != enabled) {
      throw const FormatException('HTTP policy was not committed');
    }
    CompanionHttpStatus.decode(result.fields);
    return result;
  }

  Future<CompanionPrototypeSnapshot> configureNotifications(
    bool enabled,
    List<String> packages,
  ) async {
    if (packages.length > 64 ||
        packages.any(
          (p) => !RegExp(r'^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$').hasMatch(p),
        )) {
      throw const FormatException('Expected Android package names');
    }
    return CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('configureNotifications', {
        'version': 1,
        'enabled': enabled,
        'packages': packages,
      }),
    );
  }

  Future<void> notificationDiagnostic({
    bool requestAccess = false,
    int delaySeconds = 0,
    bool closeUi = false,
  }) async {
    if (delaySeconds < 0 ||
        delaySeconds > 60 ||
        (closeUi && delaySeconds == 0) ||
        (requestAccess && (closeUi || delaySeconds != 0))) {
      throw const FormatException('Invalid notification diagnostic delay');
    }
    final response = await methods.invokeMethod<Object?>(
      requestAccess ? 'requestNotificationAccess' : 'postTestNotification',
      {
        'version': 1,
        if (delaySeconds != 0) 'delaySeconds': delaySeconds,
        if (closeUi) 'closeUi': true,
      },
    );
    if (response is! Map ||
        response['version'] != 1 ||
        response['accepted'] != true) {
      throw const FormatException('Notification diagnostic was not accepted');
    }
  }

  Future<void> start(String address) async {
    final normalized = address.trim().toUpperCase();
    if (!RegExp(r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$').hasMatch(normalized)) {
      throw const FormatException('Expected an Android BLE MAC address');
    }
    final response = await methods.invokeMethod<Object?>('start', {
      'version': 1,
      'address': normalized,
    });
    if (response is! Map ||
        response['version'] != 1 ||
        response['accepted'] != true) {
      throw const FormatException('Start command was not accepted');
    }
  }

  Future<Map<String, Object?>> presence(
    String address, {
    bool associate = false,
  }) async {
    final normalized = address.trim().toUpperCase();
    if (!RegExp(r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$').hasMatch(normalized)) {
      throw const FormatException('Expected an Android BLE MAC address');
    }
    final value = await methods.invokeMethod<Object?>(
      associate ? 'associatePresence' : 'presenceStatus',
      {'version': 1, 'address': normalized},
    );
    if (value is! Map ||
        value['version'] != 1 ||
        value['supported'] is! bool ||
        value['associated'] is! bool ||
        value['address'] != normalized) {
      throw const FormatException('Unsupported companion presence status');
    }
    return Map<String, Object?>.from(value);
  }

  Future<CompanionPrototypeSnapshot> command(String name, {int? cursor}) async {
    if (![
          'stop',
          'syncTime',
          'requestDeviceInfo',
          'requestRecordingList',
          'retryRecordings',
          'ackEvents',
          'startRemoteFixture',
          'startLocalFixture',
        ].contains(name) ||
        (name == 'ackEvents' && (cursor == null || cursor < 0))) {
      throw const FormatException('Invalid companion command');
    }
    return CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>(name, {
        'version': 1,
        if (cursor != null) 'cursor': cursor,
      }),
    );
  }
}
