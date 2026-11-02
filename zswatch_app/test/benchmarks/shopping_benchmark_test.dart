// Live OpenRouter benchmark of the shopping intent through the production
// voice worker. Skipped unless ZSWATCH_BENCH=1; it costs money.
//
//   ZSWATCH_BENCH=1 flutter test test/benchmarks/shopping_benchmark_test.dart
//
// ZSWATCH_BENCH_MODEL (default google/gemini-3.1-flash-lite),
// ZSWATCH_BENCH_RUNS (default 3), ZSWATCH_BENCH_CASES (comma-separated names).
// The key comes from OPENROUTER_API_KEY or
// ~/Documents/zswatch-integration-credentials.json. Reports go to
// .companion-hil-runs/shopping-bench/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zswatch_app/data/models/companion_recording.dart';
import 'package:zswatch_app/services/ai/companion_voice_processor.dart';
import 'package:zswatch_app/services/ai/openrouter_client.dart';

import '../support/companion_recording_fixture.dart';
import 'shopping_cases.dart';

void main() {
  final env = Platform.environment;
  final enabled = env['ZSWATCH_BENCH'] == '1';
  final model = env['ZSWATCH_BENCH_MODEL'] ?? 'google/gemini-3.1-flash-lite';
  final runs = int.tryParse(env['ZSWATCH_BENCH_RUNS'] ?? '') ?? 3;
  final only = env['ZSWATCH_BENCH_CASES']?.split(',').toSet();

  test(
    'shopping benchmark',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // The test binding answers every real HTTP request with 400.
      HttpOverrides.global = null;
      final key = _openRouterKey(env);
      final root = await Directory.systemTemp.createTemp('shopping-bench-');
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(paths, (_) async => root.path);
      addTearDown(() async {
        messenger.setMockMethodCallHandler(paths, null);
        await root.delete(recursive: true);
      });
      final recording = await seedCompanionRecording(root);
      final cases = shoppingCases
          .where((c) => only == null || only.contains(c.name))
          .toList();

      final results = <Map<String, Object?>>[];
      for (var run = 0; run < runs; run++) {
        // A few at a time: OpenRouter rate limits, and latency dominates.
        for (var i = 0; i < cases.length; i += 6) {
          results.addAll(
            await Future.wait([
              for (final c in cases.skip(i).take(6))
                _run(c, run, recording, model, key),
            ]),
          );
        }
      }
      _report(results, cases, model, runs);
    },
    skip: enabled ? false : 'Set ZSWATCH_BENCH=1 to call OpenRouter',
    timeout: Timeout.none,
  );
}

Future<Map<String, Object?>> _run(
  ShoppingCase c,
  int run,
  CompanionRecording recording,
  String model,
  String key,
) async {
  final started = DateTime.now();
  final replies = _Replies();
  Map<String, Object?>? result;
  String? error;
  try {
    result = await processCompanionVoiceRecording(
      {
        'version': 1,
        'spec': {
          'provider': 'dart-voice-v1',
          'backend': 'openrouter',
          'upload_authorized': true,
          'pipeline_revision': 'voice-v1',
          'recording_id': recording.identity,
          'input_sha256': recording.sha256,
          'watch_id': recording.watchId,
          'model': 'openrouter:$model|openrouter:$model|false',
        },
        'recording': {
          'address': recording.watchId,
          'filename': recording.filename,
          'timestamp': recording.timestampUtc.millisecondsSinceEpoch ~/ 1000,
          'duration_ms': recording.durationMs,
          'size_bytes': recording.sizeBytes,
          'state': 'downloaded',
          'local_path': recording.localPath,
          'sha256': recording.sha256,
        },
        // A saved transcript skips speech-to-text, as on reanalysis.
        'transcript': c.transcript,
        'credentials': {'openrouter_key': key},
        'integrations': {'shopping_list': true},
      },
      saveTranscript: (_) async {},
      cloudFactory: (key) => OpenRouterClient(key, client: replies),
    );
  } on PlatformException catch (e) {
    // An empty analysis is a valid answer for memos with nothing to do.
    if (e.code != 'ANALYSIS_EMPTY') error = '${e.code} ${e.message}';
  } catch (e) {
    error = '$e';
  }
  final actions = [
    for (final a in (result?['actions'] as List<Object?>? ?? const []))
      Map<String, Object?>.from(a! as Map),
  ];
  final shopping = actions.where((a) => a['type'] == 'shopping').toList();
  final items = [
    for (final a in shopping)
      for (final item in a['items']! as List<Object?>) item! as String,
  ];
  final types = actions.map((a) => a['type']! as String).toSet();
  final problems = [
    if (error != null) error,
    if (shopping.length > (c.items.isEmpty ? 0 : 1))
      '${shopping.length} shopping actions',
    if (c.items.isNotEmpty && shopping.isEmpty) 'no shopping action',
    ..._itemProblems(c.items, items),
    for (final type in c.others)
      if (!types.contains(type)) 'missing $type',
  ];
  return {
    'case': c.name,
    'run': run,
    'passed': problems.isEmpty,
    'problems': problems,
    'items': items,
    'actions': actions,
    'summary': result?['summary'],
    'model_replies': replies.contents,
    'ms': DateTime.now().difference(started).inMilliseconds,
  };
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[.!?]+$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Every expected item matched once, and nothing else.
List<String> _itemProblems(List<String> expected, List<String> actual) {
  final left = actual.map(_normalize).toList();
  final problems = <String>[];
  for (final item in expected) {
    final accepted = item.split('|').map(_normalize).toSet();
    final at = left.indexWhere(accepted.contains);
    if (at < 0) {
      problems.add('missing "$item"');
    } else {
      left.removeAt(at);
    }
  }
  return [...problems, for (final extra in left) 'extra "$extra"'];
}

void _report(
  List<Map<String, Object?>> results,
  List<ShoppingCase> cases,
  String model,
  int runs,
) {
  final passed = results.where((r) => r['passed'] == true).length;
  final lines = <String>[];
  for (final c in cases) {
    final mine = results.where((r) => r['case'] == c.name).toList();
    final ok = mine.where((r) => r['passed'] == true).length;
    final failures = {
      for (final r in mine.where((r) => r['passed'] != true))
        (r['problems']! as List).join('; '),
    };
    lines.add(
      '${ok == mine.length ? 'PASS' : 'FAIL'} ${c.name} $ok/${mine.length}'
      '${failures.isEmpty ? '' : '  ${failures.join(' | ')}'}',
    );
  }
  final ms = results.map((r) => r['ms']! as int).toList()..sort();
  lines.add(
    '$model: $passed/${results.length} passed over $runs runs; '
    'median ${ms[ms.length ~/ 2]} ms',
  );
  // ignore: avoid_print
  print(lines.join('\n'));
  final dir = Directory('../.companion-hil-runs/shopping-bench')
    ..createSync(recursive: true);
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  File(
    '${dir.path}/$stamp-${model.replaceAll('/', '_')}.json',
  ).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'model': model,
      'runs': runs,
      'passed': passed,
      'total': results.length,
      'results': results,
    }),
  );
  expect(passed, results.length, reason: 'Shopping benchmark failures');
}

String _openRouterKey(Map<String, String> env) {
  final key =
      env['OPENROUTER_API_KEY'] ??
      (jsonDecode(
            File(
              '${env['HOME']}/Documents/zswatch-integration-credentials.json',
            ).readAsStringSync(),
          )
          as Map)['openrouter_api_key'];
  if (key is! String || key.isEmpty) throw StateError('No OpenRouter key');
  return key;
}

/// Keeps the model's reply text for the report.
class _Replies extends http.BaseClient {
  final _inner = http.Client();
  final contents = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final body = await response.stream.toBytes();
    try {
      final choices = (jsonDecode(utf8.decode(body)) as Map)['choices'] as List;
      contents.add(
        ((choices.first as Map)['message'] as Map)['content'] as String,
      );
    } catch (_) {}
    return http.StreamedResponse(
      Stream.value(body),
      response.statusCode,
      headers: response.headers,
      request: response.request,
    );
  }

  @override
  void close() => _inner.close();
}
