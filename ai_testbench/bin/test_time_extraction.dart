/// CLI testbench for the voice memo → time extraction pipeline.
///
/// Run with:
///   cd ai_testbench
///   LD_LIBRARY_PATH=native_libs dart run bin/test_time_extraction.dart
///
/// Options:
///   --model <filename>   Model file in models/ (default: Qwen3.5-2B-Q4_K_M.gguf)
///   --verbose            Print full raw LLM output
///
/// Requires native_libs/libllama.so built first.
library;

import 'dart:convert';
import 'dart:io';

import 'package:chrono_dart/chrono_dart.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../lib/prompts/time_extraction_prompts.dart';
import '../lib/services/time_expression_resolver.dart';

// ── Test case definition ─────────────────────────────────────────────────

class TestCase {
  final String name;
  final String transcript;
  final String expectedIntent; // 'reminder', 'event', 'note'
  final String? expectedTimeEnglish; // null = no time expected
  final DateTime? expectedDateTime; // null = no time expected
  final int toleranceMinutes; // for relative times like "in 30 minutes"

  const TestCase({
    required this.name,
    required this.transcript,
    required this.expectedIntent,
    this.expectedTimeEnglish,
    this.expectedDateTime,
    this.toleranceMinutes = 2,
  });
}

// ── LLM response structure ──────────────────────────────────────────────

class LlmExtractionResult {
  final String? intent;
  final String? title;
  final String? datetimeExpressionOriginal;
  final String? datetimeExpressionEnglish;
  final String rawOutput;

  const LlmExtractionResult({
    this.intent,
    this.title,
    this.datetimeExpressionOriginal,
    this.datetimeExpressionEnglish,
    required this.rawOutput,
  });
}

// ── Test result ─────────────────────────────────────────────────────────

enum TestStatus { pass, fail, partial }

class TestResult {
  final TestCase testCase;
  final LlmExtractionResult? llmResult;
  final ResolvedTime? resolvedTime;
  final Duration llmDuration;
  final int tokenCount;
  final TestStatus status;
  final List<String> failures;

  const TestResult({
    required this.testCase,
    this.llmResult,
    this.resolvedTime,
    required this.llmDuration,
    required this.tokenCount,
    required this.status,
    this.failures = const [],
  });
}

// ── Main ────────────────────────────────────────────────────────────────

void main(List<String> args) async {
  // Parse CLI args
  var modelFile = 'Qwen3.5-2B-Q4_K_M.gguf';
  var verbose = false;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--model' && i + 1 < args.length) {
      modelFile = args[++i];
    } else if (args[i] == '--verbose') {
      verbose = true;
    }
  }

  print('╔══════════════════════════════════════════════════════════╗');
  print('║   ZSWatch Time Extraction Testbench — CLI               ║');
  print('╚══════════════════════════════════════════════════════════╝');
  print('');

  // ── 1. Resolve paths ─────────────────────────────────────────────────
  final scriptDir = File(Platform.script.toFilePath()).parent.parent.path;
  final nativeLib = '$scriptDir/native_libs/libllama.so';
  final modelPath = '$scriptDir/models/$modelFile';

  if (!File(nativeLib).existsSync()) {
    stderr.writeln('ERROR: Native library not found at $nativeLib');
    stderr.writeln('Build it first — see README.');
    exit(1);
  }
  if (!File(modelPath).existsSync()) {
    stderr.writeln('ERROR: Model not found at $modelPath');
    stderr.writeln('Available models:');
    Directory('$scriptDir/models')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.gguf'))
        .forEach((f) => stderr.writeln('  ${f.uri.pathSegments.last}'));
    exit(1);
  }

  // ── 2. Set native lib path ────────────────────────────────────────────
  print('[1/4] Setting native library path');
  Llama.libraryPath = nativeLib;

  // ── 3. Load model ─────────────────────────────────────────────────────
  print('[2/4] Loading model: ${modelFile}');
  final sw = Stopwatch()..start();

  late Llama llama;
  try {
    llama = Llama(
      modelPath,
      modelParams: ModelParams()
        ..nGpuLayers = 0
        ..mainGpu = -1,
      contextParams: ContextParams()
        ..nCtx = 2048
        ..nBatch = 512
        ..nThreads = 4
        ..nThreadsBatch = 4
        ..nPredict = 300,
      samplerParams: SamplerParams()
        ..temp = 0.1
        ..greedy = false
        ..topK = 40
        ..topP = 0.9
        ..penaltyRepeat = 1.1,
      verbose: false,
    );
  } catch (e) {
    stderr.writeln('FAILED to load model: $e');
    exit(1);
  }
  sw.stop();
  print('   Model loaded in ${sw.elapsed.inMilliseconds}ms ✓');
  print('');

  // ── 4. Define reference time ──────────────────────────────────────────
  // Use a fixed reference time so tests are deterministic
  final referenceTime = DateTime(2026, 3, 9, 10, 15); // Monday March 9, 10:15
  print('[3/4] Reference time: $referenceTime (Monday)');
  print('');

  // ── 5. Define test cases ──────────────────────────────────────────────
  final testCases = [
    TestCase(
      name: 'EN: Simple reminder with time',
      transcript: 'Remind me tomorrow at 10 am to buy milk',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'tomorrow at 10 am',
      expectedDateTime: DateTime(2026, 3, 10, 10, 0),
    ),
    TestCase(
      name: 'SV: Reminder with time',
      transcript: 'påminn mig imorgon klockan 10 att köpa mjölk',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'tomorrow at 10',
      expectedDateTime: DateTime(2026, 3, 10, 10, 0),
    ),
    TestCase(
      name: 'DE: Reminder with time',
      transcript: 'erinnere mich morgen um 10 milch zu kaufen',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'tomorrow at 10',
      expectedDateTime: DateTime(2026, 3, 10, 10, 0),
    ),
    TestCase(
      name: 'EN: Meeting next Tuesday',
      transcript: 'meeting with John next Tuesday at 2 pm',
      expectedIntent: 'event',
      expectedTimeEnglish: 'next Tuesday at 2 pm',
      expectedDateTime: DateTime(2026, 3, 10, 14, 0), // next Tue from Mon Mar 9
    ),
    TestCase(
      name: 'EN: No time mentioned',
      transcript: 'remember to buy milk',
      expectedIntent: 'note',
      expectedTimeEnglish: null,
      expectedDateTime: null,
    ),
    TestCase(
      name: 'SV: Relative minutes',
      transcript: 'ring tandläkaren om 30 minuter',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'in 30 minutes',
      expectedDateTime: referenceTime.add(const Duration(minutes: 30)),
      toleranceMinutes: 5,
    ),
    TestCase(
      name: 'FR: Friday at 3pm',
      transcript: "rappelle-moi vendredi à 15h d'appeler le médecin",
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'Friday at 3 pm',
      expectedDateTime: DateTime(2026, 3, 13, 15, 0), // next Friday
    ),
    TestCase(
      name: 'EN: Specific date',
      transcript: 'dentist appointment on March 15th at 9:30',
      expectedIntent: 'event',
      expectedTimeEnglish: 'March 15th at 9:30',
      expectedDateTime: DateTime(2026, 3, 15, 9, 30),
    ),
    TestCase(
      name: 'SV: No time, just task',
      transcript: 'köp bröd på vägen hem',
      expectedIntent: 'note',
      expectedTimeEnglish: null,
      expectedDateTime: null,
    ),
    TestCase(
      name: 'EN: This afternoon',
      transcript: 'call the plumber this afternoon at 3',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'this afternoon at 3',
      expectedDateTime: DateTime(2026, 3, 9, 15, 0),
    ),
  ];

  // ── 6. Run tests ─────────────────────────────────────────────────────
  print('[4/4] Running ${testCases.length} test cases...');
  print('');

  final chatml = ChatMLFormat();
  final resolver = TimeExpressionResolver();
  final results = <TestResult>[];

  for (var i = 0; i < testCases.length; i++) {
    final tc = testCases[i];
    print('─── Test ${i + 1}/${testCases.length}: ${tc.name} ───────────────────────');
    print('  Input: "${tc.transcript}"');

    // Build prompt
    final formatted = chatml.formatMessages([
      {'role': 'system', 'content': TimeExtractionPrompts.systemPrompt},
      {
        'role': 'user',
        'content': TimeExtractionPrompts.userMessage(
          transcript: tc.transcript,
          now: referenceTime,
          timezone: 'Europe/Stockholm',
        ),
      },
    ]);

    // Run inference
    llama.clear();
    llama.setPrompt(formatted);

    final genSw = Stopwatch()..start();
    final buffer = StringBuffer();
    int tokenCount = 0;

    try {
      await for (final chunk in llama.generateText()) {
        buffer.write(chunk);
        tokenCount++;
        if (tokenCount >= 300) break;
      }
    } catch (e) {
      stderr.writeln('  ERROR during generation: $e');
      results.add(TestResult(
        testCase: tc,
        llmDuration: genSw.elapsed,
        tokenCount: tokenCount,
        status: TestStatus.fail,
        failures: ['LLM generation error: $e'],
      ));
      print('');
      continue;
    }

    genSw.stop();

    String raw = buffer.toString().trim();
    // Strip end-of-turn tokens
    raw = raw.replaceAll('<|im_end|>', '').trim();
    // Strip thinking blocks (Qwen3 models may use these)
    raw = raw.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();

    final secs = genSw.elapsed.inMilliseconds / 1000;
    print('  LLM time: ${secs.toStringAsFixed(2)}s (~${(tokenCount / secs).toStringAsFixed(1)} tok/s)');

    if (verbose) {
      print('  Raw output:');
      print('  $raw');
    }

    // Parse JSON from LLM output
    LlmExtractionResult? llmResult;
    try {
      final jsonStart = raw.indexOf('{');
      final jsonEnd = raw.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
        throw FormatException('No JSON object found in output');
      }
      final jsonStr = raw.substring(jsonStart, jsonEnd + 1);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      llmResult = LlmExtractionResult(
        intent: parsed['intent'] as String?,
        title: parsed['title'] as String?,
        datetimeExpressionOriginal:
            parsed['datetime_expression_original'] as String?,
        datetimeExpressionEnglish:
            parsed['datetime_expression_english'] as String?,
        rawOutput: raw,
      );

      print('  LLM result:');
      print('    intent:     ${llmResult.intent}');
      print('    title:      ${llmResult.title}');
      print('    time (orig): ${llmResult.datetimeExpressionOriginal}');
      print('    time (EN):   ${llmResult.datetimeExpressionEnglish}');
    } catch (e) {
      print('  ❌ JSON parse failed: $e');
      if (!verbose) {
        print('  Raw output: $raw');
      }
      results.add(TestResult(
        testCase: tc,
        llmDuration: genSw.elapsed,
        tokenCount: tokenCount,
        status: TestStatus.fail,
        failures: ['JSON parse failed: $e'],
      ));
      print('');
      continue;
    }

    // Resolve time expression with chrono
    ResolvedTime? resolvedTime;
    // Try English translation first, fall back to original expression
    final timeExpr = llmResult.datetimeExpressionEnglish ??
        llmResult.datetimeExpressionOriginal;
    if (timeExpr != null) {
      resolvedTime = resolver.resolve(
        timeExpr,
        referenceDate: referenceTime,
      );
      if (resolvedTime != null) {
        print('  Chrono parse: ${resolvedTime.dateTime} (via ${resolvedTime.method})');
      } else {
        print('  Chrono parse: FAILED — could not resolve "$timeExpr"');
      }
    } else {
      print('  Chrono parse: N/A (no time expression)');
    }

    // Evaluate results
    final failures = <String>[];

    // Check 1: Intent
    final intentMatch = _intentMatches(llmResult.intent, tc.expectedIntent);
    if (!intentMatch) {
      failures.add(
          'Intent mismatch: got "${llmResult.intent}", expected "${tc.expectedIntent}"');
    }

    // Check 2: Time expression present/absent
    if (tc.expectedTimeEnglish != null &&
        llmResult.datetimeExpressionEnglish == null) {
      failures.add('Expected time expression but got null');
    }
    if (tc.expectedTimeEnglish == null &&
        llmResult.datetimeExpressionEnglish != null) {
      failures.add(
          'Expected no time expression but got "${llmResult.datetimeExpressionEnglish}"');
    }

    // Check 3: Chrono parse succeeded when expected
    if (tc.expectedDateTime != null && resolvedTime == null) {
      failures.add('Chrono failed to parse time expression');
    }
    if (tc.expectedDateTime == null && resolvedTime != null) {
      failures.add(
          'Expected no resolved time but got ${resolvedTime.dateTime}');
    }

    // Check 4: DateTime accuracy
    if (tc.expectedDateTime != null && resolvedTime != null) {
      final diff =
          resolvedTime.dateTime.difference(tc.expectedDateTime!).inMinutes.abs();
      if (diff > tc.toleranceMinutes) {
        failures.add(
            'DateTime mismatch: got ${resolvedTime.dateTime}, expected ${tc.expectedDateTime} (diff: ${diff}min, tolerance: ${tc.toleranceMinutes}min)');
      }
    }

    final status = failures.isEmpty
        ? TestStatus.pass
        : (failures.length == 1 && !failures.first.contains('Intent'))
            ? TestStatus.partial
            : TestStatus.fail;

    if (failures.isEmpty) {
      print('  ✅ PASS');
    } else {
      for (final f in failures) {
        print('  ❌ $f');
      }
    }

    if (tc.expectedDateTime != null) {
      print('  Expected:   ${tc.expectedDateTime}');
    }

    results.add(TestResult(
      testCase: tc,
      llmResult: llmResult,
      resolvedTime: resolvedTime,
      llmDuration: genSw.elapsed,
      tokenCount: tokenCount,
      status: status,
      failures: failures,
    ));

    print('');
  }

  // ── 7. Summary ────────────────────────────────────────────────────────
  llama.dispose();

  final passed = results.where((r) => r.status == TestStatus.pass).length;
  final partial = results.where((r) => r.status == TestStatus.partial).length;
  final failed = results.where((r) => r.status == TestStatus.fail).length;
  final totalLlmTime = results.fold<Duration>(
      Duration.zero, (sum, r) => sum + r.llmDuration);

  print('╔══════════════════════════════════════════════════════════╗');
  print('║  Results: $passed passed, $partial partial, $failed failed '
      'out of ${testCases.length} tests');
  print('║  Total LLM time: ${(totalLlmTime.inMilliseconds / 1000).toStringAsFixed(1)}s');
  print('║  Model: $modelFile');
  print('╚══════════════════════════════════════════════════════════╝');

  // Print detailed failure summary
  if (failed + partial > 0) {
    print('');
    print('Failed/partial tests:');
    for (final r in results.where(
        (r) => r.status == TestStatus.fail || r.status == TestStatus.partial)) {
      print('  ${r.testCase.name}:');
      for (final f in r.failures) {
        print('    - $f');
      }
    }
  }

  exit(failed > 0 ? 1 : 0);
}

/// Compare intents loosely — 'event' matches 'event', 'reminder' matches
/// 'reminder'. For 'note', also accept 'task' since the boundary is fuzzy.
bool _intentMatches(String? got, String expected) {
  if (got == null) return false;
  final g = got.toLowerCase().trim();
  final e = expected.toLowerCase().trim();
  if (g == e) return true;
  // Allow note ↔ task since models often confuse these for simple items
  if ({g, e}.containsAll({'note', 'task'})) return true;
  return false;
}
