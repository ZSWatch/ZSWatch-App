import 'package:flutter/services.dart';

import '../../data/models/connection.dart';
import '../../data/models/companion_watch_identity.dart';
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
import '../../data/models/crash_summary.dart';

/// V1 snapshot survives UI attachment changes; events are diagnostic replay.
class CompanionPrototypeSnapshot {
  final Map<String, Object?> fields;

  CompanionPrototypeSnapshot._(this.fields);

  factory CompanionPrototypeSnapshot.decode(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        !const [
          'android_service_native',
          'ios_companion_native',
        ].contains(value['owner']) ||
        value['runtime_active'] is! bool ||
        value['protocol_ready'] is! bool ||
        value['phase'] is! String ||
        value['event_cursor'] is! int ||
        value['generation'] is! int ||
        value['events'] is! List ||
        value['recordings'] is! Map) {
      throw const FormatException('Unsupported companion snapshot');
    }
    final address = value['address'];
    if (address != null &&
        (address is! String ||
            (address.isNotEmpty &&
                !(value['owner'] == 'ios_companion_native'
                    ? isIosWatchAddress(address)
                    : isAndroidWatchAddress(address))))) {
      throw const FormatException(
        'Watch identifier does not match native owner',
      );
    }
    return CompanionPrototypeSnapshot._(Map<String, Object?>.from(value));
  }

  bool get isIos => fields['owner'] == 'ios_companion_native';
  bool acceptsWatchAddress(String address) =>
      isIos ? isIosWatchAddress(address) : isAndroidWatchAddress(address);

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
      'bonding' => const ConnectionPhase.settingUp(step: SetupStep.bonding),
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

  CrashSummary? get crashSummary {
    final info = _watchInfo;
    final crash = info?['coredump'];
    if (crash is! Map ||
        crash['file'] is! String ||
        crash['line'] is! int ||
        crash['time'] is! String) {
      return null;
    }
    return CrashSummary(
      file: crash['file'] as String,
      line: crash['line'] as int,
      time: crash['time'] as String,
      fwVersion: info?['firmware_version'] as String? ?? '',
      fwCommitSha: info?['firmware_sha'] as String? ?? '',
      board: info?['hardware_version'] as String? ?? 'watchdk',
      buildType: info?['firmware_debug'] == true ? 'debug' : 'release',
    );
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

  Stream<Map<String, Object?>> sensors() => const EventChannel(
    'dev.zswatch.app/companion_sensors_v1',
  ).receiveBroadcastStream({'version': 1}).map(_sensorEvent);

  static Map<String, Object?> _sensorEvent(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['generation'] is! int ||
        !const ['state', 'sample'].contains(value['kind'])) {
      throw const FormatException('Unsupported sensor event');
    }
    return Map<String, Object?>.from(value);
  }

  Future<Map<String, Object?>> sensorState() async => _sensorEvent(
    await methods.invokeMethod<Object?>('sensorState', {'version': 1}),
  );

  Future<void> setSensor(int generation, String sensor, bool enabled) async {
    final reply = await methods.invokeMethod<Object?>('setSensor', {
      'version': 1,
      'generation': generation,
      'sensor': sensor,
      'enabled': enabled,
    });
    if (reply is! Map || reply['version'] != 1 || reply['completed'] != true) {
      throw const FormatException('Unsupported sensor subscription reply');
    }
  }

  Stream<Map<String, Object?>> liveLogs() =>
      const EventChannel(
        'dev.zswatch.app/companion_logs_v1',
      ).receiveBroadcastStream({'version': 1}).map((event) {
        if (event is! Map ||
            event['version'] != 1 ||
            (event['kind'] != 'state' && event['kind'] != 'log')) {
          throw const FormatException('Unsupported companion log event');
        }
        return Map<String, Object?>.from(event);
      });

  Future<void> setLogStreaming(bool enabled) async {
    await methods.invokeMethod<Object?>('setLogStreaming', {
      'version': 1,
      'enabled': enabled,
    });
  }

  Future<void> inspectCoredump(int generation, {bool erase = false}) async {
    final reply = await methods.invokeMethod<Object?>('inspectCoredump', {
      'version': 1,
      'generation': generation,
      'erase': erase,
    });
    if (reply is! Map || reply['version'] != 1 || reply['completed'] != true) {
      throw const FormatException('Unsupported coredump inspection reply');
    }
  }

  Future<Uint8List> downloadCoredump(int generation) async {
    final reply = await methods.invokeMethod<Object?>('downloadCoredump', {
      'version': 1,
      'generation': generation,
    });
    if (reply is! Map ||
        reply['version'] != 1 ||
        reply['bytes'] is! Uint8List ||
        (reply['bytes'] as Uint8List).length > 4 * 1024 * 1024) {
      throw const FormatException('Unsupported coredump download reply');
    }
    return reply['bytes'] as Uint8List;
  }

  /// Ephemeral completed NUS writes and reassembled protocol messages. Opening
  /// this stream observes the existing owner; it neither enables logs nor BLE.
  Stream<Map<String, Object?>> communicationTraffic() =>
      const EventChannel(
        'dev.zswatch.app/companion_traffic_v1',
      ).receiveBroadcastStream({'version': 1}).map((event) {
        if (event is! Map ||
            event['version'] != 1 ||
            !const ['rx', 'tx'].contains(event['direction']) ||
            event['data'] is! String ||
            event['size_bytes'] is! int ||
            (event['size_bytes'] as int) < 1 ||
            (event['size_bytes'] as int) > 65536 ||
            event['chunk_count'] is! int ||
            (event['chunk_count'] as int) < 1 ||
            event['utc_ms'] is! int ||
            event['generation'] is! int) {
          throw const FormatException('Unsupported companion traffic event');
        }
        return Map<String, Object?>.from(event);
      });

  Future<CompanionWatchSelection> discoverWatch() async =>
      CompanionWatchSelection.decode(
        await methods.invokeMethod<Object?>('discoverWatch', {'version': 1}),
      );

  Future<void> authorizeAccessory() async {
    final reply = await methods.invokeMethod<Object?>('authorizeAccessory', {
      'version': 1,
    });
    CompanionPrototypeSnapshot.decode(reply);
  }

  Future<void> startDiscovered(CompanionWatchSelection selection) async {
    // Validate even when a caller constructed the value rather than decoding it.
    CompanionWatchSelection.decode(selection.fields);
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

  Future<void> requestIosConnectionPermissions() async {
    final value = await methods.invokeMethod<Object?>(
      'requestConnectionPermissions',
      {'version': 1},
    );
    if (value is Map && value['version'] == 1 && value['bluetooth'] == false) {
      throw PlatformException(
        code: 'BLUETOOTH_PERMISSION',
        message:
            'Bluetooth access is disabled. Allow Bluetooth in iPhone Settings, '
            'then tap Find watch again.',
      );
    }
    if (value is! Map || value['version'] != 1 || value['bluetooth'] != true) {
      throw StateError('Bluetooth permission is required to connect');
    }
  }

  Future<CompanionPrototypeSnapshot> scan({required bool start}) async =>
      CompanionPrototypeSnapshot.decode(
        await methods.invokeMethod<Object?>(start ? 'scanStart' : 'scanStop', {
          'version': 1,
        }),
      );

  Future<CompanionPrototypeSnapshot> ackTelemetry(
    String journalId,
    int sequence,
  ) async {
    if (!isIosWatchAddress(journalId) || sequence < 0) {
      throw const FormatException('Invalid telemetry acknowledgement');
    }
    return CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('ackTelemetry', {
        'version': 1,
        'journal_id': journalId,
        'sequence': sequence,
      }),
    );
  }

  Future<Map<String, bool>> permissionStatus() async {
    final reply = await methods.invokeMethod<Object?>('permissionStatus', {
      'version': 1,
    });
    const keys = [
      'bluetooth',
      'notifications',
      'notification_access',
      'location',
      'background_location',
      'battery_exemption',
    ];
    if (reply is! Map ||
        reply['version'] != 1 ||
        keys.any((key) => reply[key] is! bool)) {
      throw const FormatException('Unsupported permission status');
    }
    return {for (final key in keys) key: reply[key] as bool};
  }

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

  Future<String> editVoiceTranscript(String id, String transcript) async {
    final result = await methods.invokeMethod<Object?>('editVoiceTranscript', {
      'version': 1,
      'job_id': id,
      'transcript': transcript,
    });
    if (result is! Map ||
        result['version'] != 1 ||
        result['job_id'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(result['job_id'] as String)) {
      throw const FormatException('Transcript edit was not saved');
    }
    return result['job_id'] as String;
  }

  Future<void> updateRecording(
    String identity, {
    String? title,
    bool? archived,
  }) async {
    CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('updateRecording', {
        'version': 1,
        'identity': identity,
        if (title != null) 'title': title,
        if (archived != null) 'archived': archived,
      }),
    );
  }

  Future<void> removeRecordings(List<String> identities) async {
    if (identities.isEmpty ||
        identities.length > 100 ||
        identities.toSet().length != identities.length) {
      throw const FormatException('Select up to 100 recordings');
    }
    CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('removeRecordings', {
        'version': 1,
        'identities': identities,
      }),
    );
  }

  Future<void> purgeRecordings(List<String> identities) async {
    if (identities.isEmpty ||
        identities.length > 100 ||
        identities.toSet().length != identities.length) {
      throw const FormatException(
        'Select up to 100 Recently deleted recordings',
      );
    }
    CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('purgeRecordings', {
        'version': 1,
        'identities': identities,
      }),
    );
  }

  Future<void> restoreRecording(String identity) async {
    CompanionPrototypeSnapshot.decode(
      await methods.invokeMethod<Object?>('restoreRecording', {
        'version': 1,
        'identity': identity,
      }),
    );
  }

  Future<Set<String>> searchRecordings(String query) async {
    final result = await methods.invokeMethod<Object?>('searchRecordings', {
      'version': 1,
      'query': query,
    });
    if (result is! Map ||
        result['version'] != 1 ||
        result['identities'] is! List ||
        (result['identities'] as List).length > 4096 ||
        (result['identities'] as List).any((id) => id is! String)) {
      throw const FormatException('Invalid recording search');
    }
    return (result['identities'] as List).cast<String>().toSet();
  }

  Future<CompanionPrototypeSnapshot> configureVoiceProcessing({
    required String watchId,
    required bool enabled,
    required String transcriptionModel,
    required String analysisModel,
    required bool correctTranscription,
    bool analyze = true,
  }) async => CompanionPrototypeSnapshot.decode(
    await methods.invokeMethod<Object?>('configureVoiceProcessing', {
      'version': 1,
      'watch_id': watchId,
      'enabled': enabled,
      'transcription_model': transcriptionModel,
      'analysis_model': analysisModel,
      'correct_transcription': correctTranscription,
      'analysis_enabled': analyze,
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
    if (!isCompanionWatchAddress(normalized)) {
      throw const FormatException('Expected a native watch identifier');
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
    if (!isCompanionWatchAddress(normalized)) {
      throw const FormatException('Expected a native watch identifier');
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
        (snapshot.isIos
            ? receipt['selection_removed'] != true ||
                  receipt['system_unpair_required'] != true ||
                  receipt['association_removed'] != false
            : receipt['association_removed'] != true) ||
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
    if (!isCompanionWatchAddress(normalized)) {
      throw const FormatException('Expected a native watch identifier');
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

  Future<void> restartWatch(int generation) async {
    if (generation < 0) {
      throw const FormatException('Invalid restart generation');
    }
    final reply = await methods.invokeMethod<Object?>('restartWatch', {
      'version': 1,
      'generation': generation,
    });
    if (reply is! Map ||
        reply['version'] != 1 ||
        reply['acknowledged'] != true) {
      throw const FormatException('Restart was not acknowledged');
    }
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
        if (path != null) 'path': path,
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
