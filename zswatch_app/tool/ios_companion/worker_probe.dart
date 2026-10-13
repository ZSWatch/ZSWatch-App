// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zswatch_app/main.dart' as app;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  app.main();
  await Future<void>.delayed(const Duration(seconds: 3));
  final result = <String, Object?>{
    'test': 'ios_headless_worker',
    'started_utc': DateTime.now().toUtc().toIso8601String(),
  };
  try {
    final fields = await const MethodChannel(
      'dev.zswatch.app/companion_v1',
    ).invokeMapMethod<String, Object?>('verifyWorkerRuntime', {'version': 1});
    if (fields == null) throw StateError('No worker reply');
    result['response'] = fields;
    final runtime = fields['runtime'] as Map?;
    if (fields['plugin_ready'] != true ||
        runtime?['path_provider'] != true ||
        runtime?['ffmpeg_version'] is! String ||
        runtime?['available_memory_mb'] is! int) {
      throw StateError('Worker plugins/memory bridge were not verified');
    }
    result['passed'] = true;
  } catch (error) {
    result['passed'] = false;
    result['error'] = error.toString();
  }
  result['finished_utc'] = DateTime.now().toUtc().toIso8601String();
  final support = await getApplicationSupportDirectory();
  await File(
    '${support.path}/ios-worker-probe.json',
  ).writeAsString(jsonEncode(result), flush: true);
  print('HIL_WORKER_RESULT ${jsonEncode(result)}');
}
