import 'package:flutter/services.dart';

import '../../data/models/connection.dart';
import '../../data/models/connection_phase.dart';
import '../../data/models/connection_state.dart';
import '../../data/models/watch.dart';
import '../../data/models/companion_notification_status.dart';
import '../../data/models/companion_http_status.dart';
import '../../data/models/companion_watch_selection.dart';
import '../../data/models/companion_gps_status.dart';
import '../../data/models/companion_shell_result.dart';
import '../../data/models/companion_log_files.dart';
import '../../data/models/companion_watchface_status.dart';
import '../../data/models/companion_firmware_status.dart';

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

  Future<CompanionWatchSelection> discoverWatch() async =>
      CompanionWatchSelection.decode(
        await methods.invokeMethod<Object?>('discoverWatch', {'version': 1}),
      );

  Future<void> startDiscovered(CompanionWatchSelection selection) async {
    // Validate even when a caller constructed the value rather than decoding it.
    CompanionWatchSelection.decode({
      'version': 1,
      'associated': true,
      'address': selection.address,
      'generation': selection.generation,
    });
    final response = await methods.invokeMethod<Object?>('startDiscovered', {
      'version': 1,
      'address': selection.address,
      'generation': selection.generation,
    });
    if (response is! Map ||
        response['version'] != 1 ||
        response['accepted'] != true) {
      throw const FormatException('Watch connection was not accepted');
    }
  }

  Future<CompanionNotificationStatus> notificationStatus() async =>
      CompanionNotificationStatus.decode(
        await methods.invokeMethod<Object?>('notificationStatus', {
          'version': 1,
        }),
      );

  Future<String> processRecording(Map<String, Object?> configuration) async {
    final result = await methods.invokeMethod<Object?>('processRecording', {
      ...configuration,
      'version': 1,
    });
    if (result is! Map ||
        result['version'] != 1 ||
        result['job_id'] is! String) {
      throw const FormatException('Processing job was not accepted');
    }
    return result['job_id'] as String;
  }

  Future<Map<String, Object?>> voiceJob(
    String id, {
    bool cancel = false,
  }) async {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const FormatException('Invalid processing job');
    }
    final result = await methods.invokeMethod<Object?>(
      cancel ? 'cancelVoiceJob' : 'voiceJob',
      {'version': 1, 'job_id': id},
    );
    if (result is! Map ||
        result['version'] != 1 ||
        result['job_id'] != id ||
        result['job'] is! Map) {
      throw const FormatException('Invalid processing status');
    }
    return Map<String, Object?>.from(result['job'] as Map);
  }

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

  Future<CompanionPrototypeSnapshot> findWatch(int generation) async {
    if (generation < 0) throw const FormatException('Invalid Ready generation');
    final snapshot = CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('findWatch', {
        'version': 1,
        'generation': generation,
      }),
    );
    final receipt = snapshot.fields['find_receipt'];
    if (receipt is! Map ||
        receipt['accepted'] != true ||
        receipt['generation'] is! int ||
        receipt['generation'] != generation) {
      throw const FormatException('Watch finding was not accepted');
    }
    return snapshot;
  }

  Future<CompanionPrototypeSnapshot> configureGps(bool enabled) async {
    final snapshot = CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('configureGps', {
        'version': 1,
        'enabled': enabled,
      }),
    );
    if (snapshot.fields['gps_enabled'] != enabled) {
      throw const FormatException('Location policy was not committed');
    }
    CompanionGpsStatus.decode(snapshot.fields);
    return snapshot;
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

  Future<CompanionPrototypeSnapshot> forgetWatch(String address) async {
    final normalized = address.trim().toUpperCase();
    if (!RegExp(r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$').hasMatch(normalized)) {
      throw const FormatException('Expected an Android BLE MAC address');
    }
    final snapshot = CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('forgetWatch', {
        'version': 1,
        'address': normalized,
      }),
    );
    final receipt = snapshot.fields['forget_receipt'];
    final tombstones = snapshot.fields['forgotten_watches'];
    if (receipt is! Map ||
        receipt['address'] != normalized ||
        receipt['association_removed'] != true ||
        receipt['generation'] is! int ||
        (receipt['generation'] as int) < 0 ||
        receipt['generation'] != snapshot.generation ||
        tombstones is! Map ||
        tombstones[normalized] != receipt['generation'] ||
        snapshot.fields['address'] == normalized) {
      throw const FormatException('Native Forget was not committed');
    }
    return snapshot;
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

  /// Prepare handles before accepting a command. This stage executes no command
  /// and may cross one service-change recovery; the command itself never replays.
  Future<int> prepareShell(int generation) async {
    if (generation < 0) throw const FormatException('Invalid shell generation');
    final value = await methods.invokeMethod<Object?>('prepareShell', {
      'version': 1,
      'generation': generation,
    });
    if (value is! Map ||
        value['version'] != 1 ||
        value['prepared_from_generation'] is! int ||
        value['prepared_from_generation'] != generation ||
        value['generation'] is! int ||
        (value['generation'] as int) < generation ||
        (value['generation'] as int) > generation + 1) {
      throw const FormatException('Unsupported SMP preparation response');
    }
    return value['generation'] as int;
  }

  Future<CompanionFirmwareAcceptance> startFirmware(
    int generation,
    List<CompanionFirmwareImage> images, {
    Uint8List? resources,
  }) async {
    if (generation < 0) {
      throw const FormatException('Invalid firmware generation');
    }
    CompanionFirmwareImage.validate(images, allowEmpty: resources != null);
    if (resources != null) CompanionResourceTarget.validatePayload(resources);
    final value = await methods.invokeMethod<Object?>('startFirmware', {
      'version': 1,
      'generation': generation,
      if (resources != null) 'resources': resources,
      'images': images
          .map((image) => {'index': image.index, 'bytes': image.bytes})
          .toList(),
    });
    if (value is! Map ||
        value['version'] != 1 ||
        value['accepted'] != true ||
        !CompanionFirmwareStatus.validId(value['id']) ||
        value['generation'] is! int ||
        value['generation'] != generation + 1) {
      // An invalid/lost receipt does not prove that the native start was rejected.
      throw const FormatException(
        'Firmware acceptance is unknown. Check native status before retrying.',
      );
    }
    return CompanionFirmwareAcceptance(
      value['id'] as String,
      value['generation'] as int,
    );
  }

  Future<void> cancelFirmware(String id) async {
    if (!CompanionFirmwareStatus.validId(id)) {
      throw const FormatException('Invalid firmware operation ID');
    }
    final value = await methods.invokeMethod<Object?>('cancelFirmware', {
      'version': 1,
      'id': id,
    });
    if (value is! Map || value['version'] != 1 || value['accepted'] != true) {
      throw const FormatException('Firmware cancellation was not accepted');
    }
    // The service snapshot, not this receipt, establishes terminal cancellation.
  }

  Future<String> startWatchface(
    int generation,
    Uint8List bytes,
    String name,
  ) async {
    CompanionWatchfaceStatus.validateImage(bytes);
    if (name.trim().isEmpty ||
        name.length > 64 ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(name)) {
      throw const FormatException('Invalid background name');
    }
    return _watchfaceCommand('startWatchface', generation, {
      'bytes': bytes,
      'name': name,
    });
  }

  Future<String> resetWatchface(int generation) =>
      _watchfaceCommand('resetWatchface', generation, {});
  Future<String> _watchfaceCommand(
    String method,
    int generation,
    Map<String, Object?> extra,
  ) async {
    if (generation < 0) {
      throw const FormatException('Invalid watchface generation');
    }
    final value = await methods.invokeMethod<Object?>(method, {
      'version': 1,
      'generation': generation,
      ...extra,
    });
    if (value is! Map ||
        value['version'] != 1 ||
        value['generation'] is! int ||
        value['generation'] != generation ||
        value['accepted'] != true ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        (value['id'] as String).length > 64) {
      throw const FormatException('Unsupported watchface acceptance');
    }
    return value['id'] as String;
  }

  Future<CompanionLogFiles> inspectLogs(int generation, {String? path}) async {
    if (generation < 0 ||
        (path != null && !CompanionLogFiles.validPath(path))) {
      throw const FormatException('Invalid log inspection request');
    }
    return CompanionLogFiles.decode(
      await methods.invokeMethod<Object?>('inspectLogs', {
        'version': 1,
        'generation': generation,
        'path': path,
      }),
      generation,
      path: path,
    );
  }

  Future<CompanionShellResult> executeShell(
    int generation,
    String command,
  ) async {
    if (generation < 0 ||
        command.trim().isEmpty ||
        command.length > 512 ||
        command.contains('\u0000')) {
      throw const FormatException('Invalid native shell request');
    }
    return CompanionShellResult.decode(
      await methods.invokeMethod<Object?>('executeShell', {
        'version': 1,
        'generation': generation,
        'command': command,
      }),
      generation,
    );
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
