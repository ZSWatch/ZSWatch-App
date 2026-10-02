import 'package:flutter/services.dart';

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
    if (!['stop', 'syncTime', 'retryRecordings', 'ackEvents'].contains(name) ||
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
