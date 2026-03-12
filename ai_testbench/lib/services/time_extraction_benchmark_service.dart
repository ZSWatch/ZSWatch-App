import 'dart:async';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/foundation.dart';

import 'llm_service.dart';
import '../prompts/time_extraction_prompts.dart';

// ── Test case definition ─────────────────────────────────────────────────

class TimeExtractionTestCase {
  final String name;
  final String transcript;
  final String expectedIntent; // 'reminder', 'event', 'note'
  final String? expectedTimeEnglish; // null = no time expected
  final DateTime? expectedDateTime; // null = no time expected
  final int toleranceMinutes; // for relative times like "in 30 minutes"

  const TimeExtractionTestCase({
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

class TimeExtractionTestResult {
  final TimeExtractionTestCase testCase;
  final LlmExtractionResult? llmResult;
  final ResolvedTime? resolvedTime;
  final Duration llmDuration;
  final double tokensPerSecond;
  final TestStatus status;
  final List<String> failures;

  const TimeExtractionTestResult({
    required this.testCase,
    this.llmResult,
    this.resolvedTime,
    required this.llmDuration,
    required this.tokensPerSecond,
    required this.status,
    this.failures = const [],
  });
}

// ── Progress ────────────────────────────────────────────────────────────

class TimeExtractionProgress {
  final int totalCases;
  final int completedCases;
  final String currentCaseName;
  final String modelName;

  const TimeExtractionProgress({
    required this.totalCases,
    required this.completedCases,
    required this.currentCaseName,
    required this.modelName,
  });

  double get fraction =>
      totalCases == 0 ? 0 : completedCases / totalCases;
}

// ── Aggregate result for a model ────────────────────────────────────────

class TimeExtractionModelResult {
  final String modelPath;
  final List<TimeExtractionTestResult> cases;

  const TimeExtractionModelResult({
    required this.modelPath,
    required this.cases,
  });

  String get modelName => modelPath.split(Platform.pathSeparator).last;
  int get passedCount =>
      cases.where((c) => c.status == TestStatus.pass).length;
  int get partialCount =>
      cases.where((c) => c.status == TestStatus.partial).length;
  int get failedCount =>
      cases.where((c) => c.status == TestStatus.fail).length;
  double get avgTokensPerSecond => cases.isEmpty
      ? 0
      : cases.fold<double>(0, (sum, c) => sum + c.tokensPerSecond) /
          cases.length;
  Duration get totalElapsed =>
      cases.fold(Duration.zero, (sum, c) => sum + c.llmDuration);
}

// ── Service ─────────────────────────────────────────────────────────────

class TimeExtractionBenchmarkService {
  static const Duration perCaseTimeout = Duration(seconds: 90);
  static const ChronoLlmParser _parser = ChronoLlmParser();

  /// Fixed reference time for deterministic tests.
  /// Monday March 9, 2026, 10:15 AM.
  static final DateTime referenceTime = DateTime(2026, 3, 9, 10, 15);

  static final testCases = <TimeExtractionTestCase>[
    TimeExtractionTestCase(
      name: 'EN: Simple reminder with time',
      transcript: 'Remind me tomorrow at 10 am to buy milk',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'tomorrow at 10 am',
      expectedDateTime: DateTime(2026, 3, 10, 10, 0),
    ),
    TimeExtractionTestCase(
      name: 'SV: Reminder with time',
      transcript: 'påminn mig imorgon klockan 10 att köpa mjölk',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'tomorrow at 10',
      expectedDateTime: DateTime(2026, 3, 10, 10, 0),
    ),
    TimeExtractionTestCase(
      name: 'DE: Reminder with time',
      transcript: 'erinnere mich morgen um 10 milch zu kaufen',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'tomorrow at 10',
      expectedDateTime: DateTime(2026, 3, 10, 10, 0),
    ),
    TimeExtractionTestCase(
      name: 'EN: Meeting next Tuesday',
      transcript: 'meeting with John next Tuesday at 2 pm',
      expectedIntent: 'event',
      expectedTimeEnglish: 'next Tuesday at 2 pm',
      expectedDateTime: DateTime(2026, 3, 10, 14, 0),
    ),
    TimeExtractionTestCase(
      name: 'EN: No time mentioned',
      transcript: 'remember to buy milk',
      expectedIntent: 'note',
      expectedTimeEnglish: null,
      expectedDateTime: null,
    ),
    TimeExtractionTestCase(
      name: 'SV: Relative minutes',
      transcript: 'ring tandläkaren om 30 minuter',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'in 30 minutes',
      expectedDateTime: DateTime(2026, 3, 9, 10, 45),
      toleranceMinutes: 5,
    ),
    TimeExtractionTestCase(
      name: 'FR: Friday at 3pm',
      transcript: "rappelle-moi vendredi à 15h d'appeler le médecin",
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'Friday at 3 pm',
      expectedDateTime: DateTime(2026, 3, 13, 15, 0),
    ),
    TimeExtractionTestCase(
      name: 'EN: Specific date',
      transcript: 'dentist appointment on March 15th at 9:30',
      expectedIntent: 'event',
      expectedTimeEnglish: 'March 15th at 9:30',
      expectedDateTime: DateTime(2026, 3, 15, 9, 30),
    ),
    TimeExtractionTestCase(
      name: 'SV: No time, just task',
      transcript: 'köp bröd på vägen hem',
      expectedIntent: 'note',
      expectedTimeEnglish: null,
      expectedDateTime: null,
    ),
    TimeExtractionTestCase(
      name: 'EN: This afternoon',
      transcript: 'call the plumber this afternoon at 3',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'this afternoon at 3',
      expectedDateTime: DateTime(2026, 3, 9, 15, 0),
    ),
    // ── Additional Swedish cases (translation stress tests) ──────────
    TimeExtractionTestCase(
      name: 'SV: Meeting next Tuesday',
      transcript: 'möte med Erik nästa tisdag klockan 14',
      expectedIntent: 'event',
      expectedTimeEnglish: 'next Tuesday at 2 pm',
      expectedDateTime: DateTime(2026, 3, 10, 14, 0),
    ),
    TimeExtractionTestCase(
      name: 'SV: This afternoon',
      transcript: 'ring rörmokaren i eftermiddag klockan 3',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'this afternoon at 3',
      expectedDateTime: DateTime(2026, 3, 9, 15, 0),
    ),
    TimeExtractionTestCase(
      name: 'SV: Specific date and time',
      transcript: 'tandläkare den 15 mars klockan halv 10',
      expectedIntent: 'event',
      expectedTimeEnglish: 'March 15th at 9:30',
      expectedDateTime: DateTime(2026, 3, 15, 9, 30),
    ),
    TimeExtractionTestCase(
      name: 'SV: Friday with 24h time',
      transcript: 'boka konferensrum på fredag klockan 15',
      expectedIntent: 'event',
      expectedTimeEnglish: 'Friday at 3 pm',
      expectedDateTime: DateTime(2026, 3, 13, 15, 0),
    ),
    TimeExtractionTestCase(
      name: 'SV: In two hours',
      transcript: 'påminn mig om två timmar att ta medicinen',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'in 2 hours',
      expectedDateTime: DateTime(2026, 3, 9, 12, 15),
      toleranceMinutes: 5,
    ),
    TimeExtractionTestCase(
      name: 'SV: Day after tomorrow morning',
      transcript: 'skicka rapporten i övermorgon på morgonen klockan 8',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'day after tomorrow at 8 am',
      expectedDateTime: DateTime(2026, 3, 11, 8, 0),
    ),
    TimeExtractionTestCase(
      name: 'SV: Tonight',
      transcript: 'handla mat ikväll klockan 6',
      expectedIntent: 'reminder',
      expectedTimeEnglish: 'tonight at 6',
      expectedDateTime: DateTime(2026, 3, 9, 18, 0),
    ),
  ];

  Future<List<TimeExtractionModelResult>> runForModels(
    List<String> modelPaths, {
    void Function(TimeExtractionProgress progress)? onProgress,
    bool includeLanguageHint = false,
    bool retryInvalidOutput = false,
    TimeExtractionPromptVariant promptVariant =
        TimeExtractionPromptVariant.full,
  }) async {
    final results = <TimeExtractionModelResult>[];
    final resolver = TimeExpressionResolver();

    for (final modelPath in modelPaths) {
      final modelName = modelPath.split(Platform.pathSeparator).last;
      final llm = LlmService()
        ..setModel(modelPath)
        ..nCtx = 2048
        ..nThreads = 4
        ..maxTokens = 384
        ..temperature = 0.1;

      final caseResults = <TimeExtractionTestResult>[];

      try {
        for (var i = 0; i < testCases.length; i++) {
          final tc = testCases[i];

          onProgress?.call(TimeExtractionProgress(
            totalCases: testCases.length,
            completedCases: i,
            currentCaseName: tc.name,
            modelName: modelName,
          ));

          debugPrint(
            '\n─── Test ${i + 1}/${testCases.length}: ${tc.name} ───',
          );
          debugPrint('  Input: "${tc.transcript}"');

          try {
            final prompt = TimeExtractionPrompts.singlePrompt(
              transcript: tc.transcript,
              now: referenceTime,
            );

            Duration totalElapsed = Duration.zero;
            double lastTokensPerSecond = 0;
            var attempts = 0;
            InferenceResult? result;
            LlmExtractionResult? llmResult;

            while (true) {
              attempts++;
              result = await llm
                  .generate(prompt)
                  .timeout(perCaseTimeout);
              totalElapsed += result.elapsed;
              lastTokensPerSecond = result.tokensPerSecond;
              llmResult = _parseLlmOutput(result.output);

              if (!retryInvalidOutput ||
                  attempts >= 2 ||
                  !_shouldRetryInvalidOutput(tc, llmResult)) {
                break;
              }

              debugPrint('  ↻ Retrying invalid output (attempt ${attempts + 1}/2)');
            }

            debugPrint('  LLM time: ${totalElapsed.inMilliseconds}ms '
                '(${lastTokensPerSecond.toStringAsFixed(1)} tok/s)');
            debugPrint('  attempts: $attempts');
            debugPrint('  intent: ${llmResult.intent}');
            debugPrint('  title: ${llmResult.title}');
            debugPrint('  time (orig): ${llmResult.datetimeExpressionOriginal}');
            debugPrint('  time (EN): ${llmResult.datetimeExpressionEnglish}');

            // Resolve time expression
            ResolvedTime? resolvedTime;
            final timeExpr = llmResult.datetimeExpressionEnglish ??
                llmResult.datetimeExpressionOriginal;
            if (timeExpr != null) {
              resolvedTime = resolver.resolve(
                timeExpr,
                referenceDate: referenceTime,
              );
              debugPrint(resolvedTime != null
                  ? '  Chrono: ${resolvedTime.dateTime} (via ${resolvedTime.method})'
                  : '  Chrono: FAILED for "$timeExpr"');
            }

            // Evaluate
            final failures = _evaluate(tc, llmResult, resolvedTime);
            final status = failures.isEmpty
                ? TestStatus.pass
                : (failures.length == 1 &&
                        !failures.first.contains('Intent'))
                    ? TestStatus.partial
                    : TestStatus.fail;

            for (final f in failures) {
              debugPrint('  ❌ $f');
            }
            if (failures.isEmpty) {
              debugPrint('  ✅ PASS');
            }

            caseResults.add(TimeExtractionTestResult(
              testCase: tc,
              llmResult: llmResult,
              resolvedTime: resolvedTime,
              llmDuration: totalElapsed,
              tokensPerSecond: lastTokensPerSecond,
              status: status,
              failures: failures,
            ));
          } on TimeoutException {
            llm.cancelInference();
            debugPrint('  ⏱ TIMEOUT');
            caseResults.add(TimeExtractionTestResult(
              testCase: tc,
              llmDuration: perCaseTimeout,
              tokensPerSecond: 0,
              status: TestStatus.fail,
              failures: ['Timed out after ${perCaseTimeout.inSeconds}s'],
            ));
          } catch (e) {
            llm.cancelInference();
            debugPrint('  ❌ ERROR: $e');
            caseResults.add(TimeExtractionTestResult(
              testCase: tc,
              llmDuration: Duration.zero,
              tokensPerSecond: 0,
              status: TestStatus.fail,
              failures: ['Error: $e'],
            ));
          }

          onProgress?.call(TimeExtractionProgress(
            totalCases: testCases.length,
            completedCases: i + 1,
            currentCaseName: tc.name,
            modelName: modelName,
          ));
        }
      } finally {
        llm.dispose();
      }

      results.add(TimeExtractionModelResult(
        modelPath: modelPath,
        cases: caseResults,
      ));
    }

    return results;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  LlmExtractionResult _parseLlmOutput(String raw) {
    final parsed = _parser.parse(raw);
    return LlmExtractionResult(
      intent: parsed.extraction?.intent,
      title: parsed.extraction?.title,
      datetimeExpressionOriginal: parsed.extraction?.datetimeExpressionOriginal,
      datetimeExpressionEnglish: parsed.extraction?.datetimeExpressionEnglish,
      rawOutput: parsed.rawOutput,
    );
  }

  bool _shouldRetryInvalidOutput(
    TimeExtractionTestCase testCase,
    LlmExtractionResult llmResult,
  ) {
    final hasIntent = llmResult.intent != null && llmResult.intent!.isNotEmpty;
    final hasAnyTime = (llmResult.datetimeExpressionEnglish != null &&
            llmResult.datetimeExpressionEnglish!.isNotEmpty) ||
        (llmResult.datetimeExpressionOriginal != null &&
            llmResult.datetimeExpressionOriginal!.isNotEmpty);
    final hasJsonFields = hasIntent ||
        llmResult.title != null ||
        llmResult.datetimeExpressionEnglish != null ||
        llmResult.datetimeExpressionOriginal != null;

    if (!hasJsonFields) {
      return true;
    }

    if (!hasIntent) {
      return true;
    }

    if (testCase.expectedTimeEnglish != null && !hasAnyTime) {
      return true;
    }

    return false;
  }

  List<String> _evaluate(
    TimeExtractionTestCase tc,
    LlmExtractionResult llm,
    ResolvedTime? resolved,
  ) {
    final failures = <String>[];

    // Intent match
    if (!_intentMatches(llm.intent, tc.expectedIntent)) {
      failures.add(
        'Intent: got "${llm.intent}", expected "${tc.expectedIntent}"',
      );
    }

    // Time expression present/absent
    if (tc.expectedTimeEnglish != null &&
        llm.datetimeExpressionEnglish == null &&
        llm.datetimeExpressionOriginal == null) {
      failures.add('Expected time expression but got null');
    }
    if (tc.expectedTimeEnglish == null &&
        llm.datetimeExpressionEnglish != null) {
      failures.add(
        'Expected no time but got "${llm.datetimeExpressionEnglish}"',
      );
    }

    // Chrono parse success
    if (tc.expectedDateTime != null && resolved == null) {
      failures.add('Chrono failed to parse time expression');
    }
    if (tc.expectedDateTime == null && resolved != null) {
      failures.add('Expected no resolved time but got ${resolved.dateTime}');
    }

    // DateTime accuracy
    if (tc.expectedDateTime != null && resolved != null) {
      final diff = resolved.dateTime
          .difference(tc.expectedDateTime!)
          .inMinutes
          .abs();
      if (diff > tc.toleranceMinutes) {
        failures.add(
          'DateTime: got ${resolved.dateTime}, expected ${tc.expectedDateTime} '
          '(diff ${diff}min, tolerance ${tc.toleranceMinutes}min)',
        );
      }
    }

    return failures;
  }

  bool _intentMatches(String? got, String expected) {
    if (got == null) return false;
    final g = got.toLowerCase().trim();
    final e = expected.toLowerCase().trim();
    if (g == e) return true;
    // note ↔ task are fuzzy
    if ({g, e}.containsAll({'note', 'task'})) return true;
    return false;
  }

  /// Format results as a readable string for display.
  static String formatResults(List<TimeExtractionModelResult> results) {
    final buf = StringBuffer();

    for (final model in results) {
      buf.writeln('╔══════════════════════════════════════════════════════╗');
      buf.writeln('║ Model: ${model.modelName}');
      buf.writeln('║ Results: ${model.passedCount} passed, '
          '${model.partialCount} partial, ${model.failedCount} failed '
          'of ${model.cases.length}');
      buf.writeln('║ Total time: '
          '${(model.totalElapsed.inMilliseconds / 1000).toStringAsFixed(1)}s');
      buf.writeln('║ Avg: '
          '${model.avgTokensPerSecond.toStringAsFixed(1)} tok/s');
      buf.writeln('╚══════════════════════════════════════════════════════╝');
      buf.writeln();

      for (final r in model.cases) {
        final icon = switch (r.status) {
          TestStatus.pass => '✅',
          TestStatus.partial => '⚠️',
          TestStatus.fail => '❌',
        };
        buf.writeln('$icon ${r.testCase.name}');
        buf.writeln('   Input: "${r.testCase.transcript}"');
        if (r.llmResult != null) {
          buf.writeln('   Intent: ${r.llmResult!.intent}');
          buf.writeln('   Title: ${r.llmResult!.title}');
          buf.writeln(
              '   Time (orig): ${r.llmResult!.datetimeExpressionOriginal}');
          buf.writeln(
              '   Time (EN): ${r.llmResult!.datetimeExpressionEnglish}');
        }
        if (r.resolvedTime != null) {
          buf.writeln(
              '   Resolved: ${r.resolvedTime!.dateTime} (${r.resolvedTime!.method})');
        }
        if (r.testCase.expectedDateTime != null) {
          buf.writeln('   Expected: ${r.testCase.expectedDateTime}');
        }
        buf.writeln(
            '   LLM: ${r.llmDuration.inMilliseconds}ms, '
            '${r.tokensPerSecond.toStringAsFixed(1)} tok/s');
        for (final f in r.failures) {
          buf.writeln('   ↳ $f');
        }
        buf.writeln();
      }
    }

    return buf.toString();
  }
}
