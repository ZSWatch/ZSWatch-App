// This device tool intentionally writes results to the attached console.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zswatch_app/main.dart' as app;
import 'package:zswatch_app/data/models/companion_watch_selection.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';

/// Signed device probe entry point. Uses the ordinary app and native bridge;
/// no production build flag, firmware write, unpair, or recording deletion.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  app.main();
  await Future<void>.delayed(const Duration(seconds: 2));
  const client = CompanionPrototypeClient();
  final result = <String, Object?>{
    'version': 1,
    'test': 'ios_native_ble',
    'started_utc': DateTime.now().toUtc().toIso8601String(),
  };
  CompanionPrototypeSnapshot? initial;
  Future<CompanionPrototypeSnapshot> until(
    String stage,
    bool Function(CompanionPrototypeSnapshot) accepts,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 35));
    while (DateTime.now().isBefore(deadline)) {
      final state = await client.snapshot();
      if (accepts(state)) return state;
      {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    final last = await client.snapshot();
    result['failed_stage'] = stage;
    result['last_phase'] = last.phase;
    result['last_error'] = last.fields['last_error'];
    result['scan_results'] = last.fields['scan_results'];
    result['events'] = last.fields['events'];
    throw StateError('$stage timed out');
  }

  try {
    initial = await client.snapshot();
    if (!initial.isIos) throw StateError('Wrong native owner');
    {
      await client.command('stop');
    }
    result['permissions'] = await client.permissionStatus();
    print('HIL_STAGE permissions ${jsonEncode(result['permissions'])}');
    await client.requestIosConnectionPermissions();
    await client.scan(start: true);
    print('HIL_STAGE scanning');
    final scan = await until(
      'discovery',
      (s) => (s.fields['scan_results'] as List).isNotEmpty,
    );
    final found = (scan.fields['scan_results'] as List)
        .whereType<Map<Object?, Object?>>()
        .toList();
    if (found.length != 1) {
      throw StateError('One nearby identifiable ZSWatch required');
    }
    final id = found.single['address'] as String;
    result['address'] = id;
    await client.startDiscovered(
      CompanionWatchSelection(id, scan.generation, platform: 'ios'),
    );
    print('HIL_STAGE connecting $id');
    final ready = await until(
      'protocol_ready',
      (s) =>
          s.protocolReady &&
          s.watch?.firmwareVersion != null &&
          s.hasLiveStatus,
    );
    result['ready'] = {
      'generation': ready.generation,
      'payload_bytes': ready.fields['att_payload_bytes'],
      'firmware': ready.watch?.firmwareVersion,
      'battery': ready.watch?.batteryLevel,
    };
    await client.command('syncTime');
    final subscription = client.watch().listen((_) {});
    await Future<void>.delayed(const Duration(seconds: 1));
    await subscription.cancel();
    if (!(await client.snapshot()).protocolReady) {
      throw StateError('Observer detachment stopped BLE');
    }
    result['observer_detach'] = 'passed';
    await client.command('stop');
    final stopped = await client.snapshot();
    if (stopped.runtimeActive ||
        stopped.protocolReady ||
        stopped.generation <= ready.generation) {
      throw StateError('Stop did not fence session');
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    if ((await client.snapshot()).runtimeActive) {
      throw StateError('Late callback revived Stop');
    }
    result['stop'] = 'passed';
    await client.start(id);
    final again = await until(
      'reconnect',
      (s) => s.protocolReady && s.hasLiveStatus,
    );
    if (again.generation <= stopped.generation) {
      throw StateError('Reconnect did not renew session');
    }
    result['reconnect'] = {'generation': again.generation};
    result['passed'] = true;
  } catch (error) {
    result['passed'] = false;
    result['error'] = error.toString();
  } finally {
    try {
      await client.scan(start: false);
      await client.command('stop');
      final address = initial?.fields['address'];
      if (initial?.runtimeActive == true &&
          address is String &&
          address.isNotEmpty) {
        await client.start(address);
      }
    } catch (error) {
      result['cleanup_error'] = error.toString();
    }
    result['finished_utc'] = DateTime.now().toUtc().toIso8601String();
    final support = await getApplicationSupportDirectory();
    await File(
      '${support.path}/ios-ble-probe.json',
    ).writeAsString(jsonEncode(result), flush: true);
    print('HIL_RESULT ${jsonEncode(result)}');
  }
}
