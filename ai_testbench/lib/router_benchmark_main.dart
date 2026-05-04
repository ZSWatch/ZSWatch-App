import 'dart:convert';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/material.dart';

import 'services/llm_service.dart';

/// Benchmarks the two-stage router approach:
/// 1. Router prompt classifies input as timer_alarm / voice_memo / mixed
/// 2. Routes to dedicated timer/alarm prompt OR original 3-intent prompt
///
/// Measures: router accuracy, router latency, total pipeline latency.
Future<void> runRouterBenchmark(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final modelFilter = _readArg(args, '--model');
  final modelDir = _readArg(args, '--model-dir') ?? 'models';

  final modelPaths =
      Directory(modelDir)
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.toLowerCase().endsWith('.gguf'))
          .where(
            (p) =>
                modelFilter == null ||
                p.toLowerCase().contains(modelFilter.toLowerCase()),
          )
          .toList()
        ..sort();

  if (modelPaths.isEmpty) {
    stdout.writeln('[RouterBench] No .gguf models found');
    exitCode = 1;
    return;
  }

  final modelPath = modelPaths.first;
  stdout.writeln('[RouterBench] Using model: ${modelPath.split('/').last}');

  final llm = LlmService()
    ..setModel(modelPath)
    ..nCtx = 4096
    ..nThreads = Platform.numberOfProcessors
    ..maxTokens =
        32 // Router output is tiny: {"route":"timer_alarm"}
    ..temperature = 0.1
    ..topP = 1.0
    ..presencePenalty = 2.0
    ..enableThinking = false;

  final parser = const ChronoLlmParser();
  final referenceTime = DateTime(2026, 3, 11, 10, 15);

  // Test cases with expected route
  final cases = <_RouterTestCase>[
    // Timer cases → timer_alarm
    _RouterTestCase('Set a timer for 8 minutes', 'timer_alarm'),
    _RouterTestCase('Timer for 5 minutes for pasta', 'timer_alarm'),
    _RouterTestCase('Set a 30 second timer', 'timer_alarm'),
    _RouterTestCase('Set a timer for one and a half hours', 'timer_alarm'),
    _RouterTestCase('Sätt en timer på 10 minuter', 'timer_alarm'),
    _RouterTestCase('Timer på 5 minuter för äggen', 'timer_alarm'),
    _RouterTestCase('Stell einen Timer auf 15 Minuten', 'timer_alarm'),
    _RouterTestCase('In 10 minutes', 'timer_alarm'),
    _RouterTestCase('30 minutes', 'timer_alarm'),

    // Alarm cases → timer_alarm
    _RouterTestCase('Set an alarm for 7:30 AM', 'timer_alarm'),
    _RouterTestCase('Alarm at 6 AM, wake up', 'timer_alarm'),
    _RouterTestCase('Wake me up tomorrow at 5:30', 'timer_alarm'),
    _RouterTestCase('Ställ ett alarm klockan 7', 'timer_alarm'),
    _RouterTestCase('Wecker auf 7 Uhr stellen', 'timer_alarm'),
    _RouterTestCase('7 AM', 'timer_alarm'),

    // Reminder cases → voice_memo (NOT timer/alarm despite having time)
    _RouterTestCase('Remind me in 30 minutes to check the oven', 'voice_memo'),
    _RouterTestCase('Remind me at 3 PM to call the dentist', 'voice_memo'),
    _RouterTestCase(
      'Påminn mig om 10 minuter att stänga av ugnen',
      'voice_memo',
    ),
    _RouterTestCase(
      'Påminn mig klockan 15 att ringa tandläkaren',
      'voice_memo',
    ),

    // Event/note cases → voice_memo
    _RouterTestCase('Meeting with John next Tuesday at 2 pm', 'voice_memo'),
    _RouterTestCase('Buy milk and bread', 'voice_memo'),
    _RouterTestCase('Köp mjölk och bröd på vägen hem', 'voice_memo'),
    _RouterTestCase('Tandläkare den 15 mars klockan halv 10', 'voice_memo'),
    _RouterTestCase(
      'Fika med Anna imorgon klockan 10 och sen lämna in paketet',
      'voice_memo',
    ),

    // Mixed cases
    _RouterTestCase(
      'Set a timer for 10 minutes and an alarm for 7 AM tomorrow',
      'timer_alarm',
    ),
    _RouterTestCase('Set an alarm for 6:30 and buy milk', 'mixed'),
    _RouterTestCase(
      'Sätt en timer på 5 minuter och påminn mig klockan 3 att ringa tandläkaren',
      'mixed',
    ),
  ];

  stdout.writeln('[RouterBench] Running ${cases.length} router cases...\n');

  // ── Stage 1: Router prompt benchmark ──
  int routerCorrect = 0;
  final routerTimes = <Duration>[];

  for (final tc in cases) {
    final prompt = ChronoPromptTemplate.render(
      ChronoPromptTemplate.routerTemplate,
      transcript: tc.transcript,
      now: referenceTime,
    );

    final result = await llm
        .generate(prompt)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => const InferenceResult(
            output: '{"route":"timeout"}',
            elapsed: Duration(seconds: 30),
          ),
        );

    routerTimes.add(result.elapsed);
    final route = _parseRoute(parser.sanitizeModelOutput(result.output));
    final correct = route == tc.expectedRoute;
    if (correct) routerCorrect++;

    final status = correct ? 'OK' : 'FAIL';
    stdout.writeln(
      '  $status  route=$route (expected=${tc.expectedRoute})  '
      '${result.elapsed.inMilliseconds}ms  "${tc.transcript}"',
    );
  }

  final avgRouterMs =
      routerTimes.fold<int>(0, (s, d) => s + d.inMilliseconds) ~/
      routerTimes.length;
  stdout.writeln(
    '\n[RouterBench] Router accuracy: $routerCorrect/${cases.length}',
  );
  stdout.writeln('[RouterBench] Router avg latency: ${avgRouterMs}ms');

  // ── Stage 2: Full two-stage pipeline on timer/alarm cases ──
  stdout.writeln(
    '\n[RouterBench] Running full two-stage pipeline on timer/alarm cases...\n',
  );

  // Reconfigure for extraction (more tokens needed)
  llm.maxTokens = 384;

  final timerCases = cases
      .where((c) => c.expectedRoute == 'timer_alarm')
      .toList();

  int extractionCorrect = 0;
  final totalTimes = <Duration>[];

  for (final tc in timerCases) {
    final sw = Stopwatch()..start();

    // Stage 1: Router
    llm.maxTokens = 32;
    final routerPrompt = ChronoPromptTemplate.render(
      ChronoPromptTemplate.routerTemplate,
      transcript: tc.transcript,
      now: referenceTime,
    );
    final routerResult = await llm
        .generate(routerPrompt)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => const InferenceResult(
            output: '{"route":"timeout"}',
            elapsed: Duration(seconds: 30),
          ),
        );
    final routerMs = routerResult.elapsed.inMilliseconds;

    // Stage 2: Timer/alarm extraction
    llm.maxTokens = 384;
    final extractPrompt = ChronoPromptTemplate.render(
      ChronoPromptTemplate.timerAlarmTemplate,
      transcript: tc.transcript,
      now: referenceTime,
    );
    final extractResult = await llm
        .generate(extractPrompt)
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => const InferenceResult(
            output: '[]',
            elapsed: Duration(seconds: 60),
          ),
        );
    final extractMs = extractResult.elapsed.inMilliseconds;

    sw.stop();
    totalTimes.add(sw.elapsed);

    final parseResult = parser.parse(extractResult.output);
    final first = parseResult.extractions.isNotEmpty
        ? parseResult.extractions.first
        : null;
    final intentOk =
        first != null && (first.intent == 'timer' || first.intent == 'alarm');
    if (intentOk) extractionCorrect++;

    stdout.writeln(
      '  ${intentOk ? "OK" : "FAIL"}  intent=${first?.intent ?? "null"}  '
      'dur=${first?.durationSeconds ?? "null"}  '
      'router=${routerMs}ms  extract=${extractMs}ms  '
      'total=${sw.elapsedMilliseconds}ms  "${tc.transcript}"',
    );
  }

  final avgTotalMs =
      totalTimes.fold<int>(0, (s, d) => s + d.inMilliseconds) ~/
      totalTimes.length;
  stdout.writeln(
    '\n[RouterBench] Extraction accuracy: $extractionCorrect/${timerCases.length}',
  );
  stdout.writeln('[RouterBench] Avg total (router+extract): ${avgTotalMs}ms');
  stdout.writeln('[RouterBench] Avg router only: ${avgRouterMs}ms');
  stdout.writeln(
    '[RouterBench] Avg extract only: ${avgTotalMs - avgRouterMs}ms',
  );

  // ── Stage 3: Compare with single-pass original prompt on voice_memo cases ──
  stdout.writeln(
    '\n[RouterBench] Comparing single-pass original prompt latency...\n',
  );

  final voiceMemoCases = cases
      .where((c) => c.expectedRoute == 'voice_memo')
      .take(5)
      .toList();

  llm.maxTokens = 384;
  final singlePassTimes = <Duration>[];

  for (final tc in voiceMemoCases) {
    final prompt = ChronoPromptTemplate.render(
      ChronoPromptTemplate.compactTemplate,
      transcript: tc.transcript,
      now: referenceTime,
    );
    final result = await llm
        .generate(prompt)
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () => const InferenceResult(
            output: 'timeout',
            elapsed: Duration(seconds: 90),
          ),
        );
    singlePassTimes.add(result.elapsed);
    stdout.writeln(
      '  single-pass: ${result.elapsed.inMilliseconds}ms  "${tc.transcript}"',
    );
  }

  final avgSingleMs =
      singlePassTimes.fold<int>(0, (s, d) => s + d.inMilliseconds) ~/
      singlePassTimes.length;
  stdout.writeln(
    '\n[RouterBench] Avg single-pass (original prompt): ${avgSingleMs}ms',
  );
  stdout.writeln(
    '[RouterBench] Avg two-stage (router+extract): ${avgTotalMs}ms',
  );
  stdout.writeln(
    '[RouterBench] Overhead: ${avgTotalMs - avgSingleMs}ms (${((avgTotalMs - avgSingleMs) / avgSingleMs * 100).toStringAsFixed(0)}%)',
  );

  llm.dispose();
  stdout.writeln('\n[RouterBench] Done.');
}

String _parseRoute(String raw) {
  // Try to parse JSON
  try {
    final start = raw.indexOf('{');
    if (start == -1) return _guessRoute(raw);
    final end = raw.lastIndexOf('}');
    if (end == -1) return _guessRoute(raw);
    final json =
        jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    final route = (json['route'] as String?)?.trim().toLowerCase() ?? '';
    if (route == 'timer_alarm' || route == 'voice_memo' || route == 'mixed') {
      return route;
    }
    return _guessRoute(raw);
  } catch (_) {
    return _guessRoute(raw);
  }
}

String _guessRoute(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('timer_alarm')) return 'timer_alarm';
  if (lower.contains('voice_memo')) return 'voice_memo';
  if (lower.contains('mixed')) return 'mixed';
  return 'unknown';
}

String? _readArg(List<String> args, String name) {
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == name) return args[i + 1];
  }
  return null;
}

class _RouterTestCase {
  final String transcript;
  final String expectedRoute;
  const _RouterTestCase(this.transcript, this.expectedRoute);
}
