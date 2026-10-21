import 'dart:async';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';

import '../benchmark/benchmark_cases.dart';
import '../benchmark/benchmark_cases.dart' as cases;

export '../benchmark/benchmark_cases.dart' show BenchmarkCase, ExpectedItem;
import '../benchmark/benchmark_scoring.dart';
import 'llm_service.dart';

// ── Test result ──────────────────────────────────────────────────────────

class BenchmarkCaseResult {
  final String caseName;
  final bool validJson;
  final bool intentMatch;
  final bool timePresenceMatch;
  final bool titleLanguageMatch;
  final String? titleLanguageDetail;
  final bool timeResolutionCorrect;
  final String? timeResolutionDetail;
  final String intent;
  final String? title;
  final String? datetimeOriginal;
  final String? datetimeEnglish;
  final Duration elapsed;
  final double tokensPerSecond;
  final String outputPreview;
  final String? error;

  /// Number of items extracted from the output.
  final int extractedCount;

  /// Number of items expected.
  final int expectedCount;

  /// Whether the count of extracted items matches expected.
  final bool countMatch;

  /// Per-item validation details for multi-item cases.
  final List<String> itemFailures;

  /// Whether the extracted duration matches expected (for timer intents).
  final bool durationMatch;

  /// Detail about duration match failure.
  final String? durationDetail;

  const BenchmarkCaseResult({
    required this.caseName,
    required this.validJson,
    required this.intentMatch,
    required this.timePresenceMatch,
    this.titleLanguageMatch = true,
    this.titleLanguageDetail,
    this.timeResolutionCorrect = true,
    this.timeResolutionDetail,
    this.durationMatch = true,
    this.durationDetail,
    required this.intent,
    this.title,
    this.datetimeOriginal,
    this.datetimeEnglish,
    required this.elapsed,
    required this.tokensPerSecond,
    required this.outputPreview,
    this.error,
    this.extractedCount = 1,
    this.expectedCount = 1,
    this.countMatch = true,
    this.itemFailures = const [],
  });

  bool get passed =>
      validJson &&
      intentMatch &&
      timePresenceMatch &&
      titleLanguageMatch &&
      timeResolutionCorrect &&
      durationMatch &&
      countMatch &&
      itemFailures.isEmpty;
}

// ── Progress ─────────────────────────────────────────────────────────────

class BenchmarkProgress {
  final int totalModels;
  final int totalCasesPerModel;
  final int totalRuns;
  final int completedRuns;
  final int currentModelIndex;
  final int currentCaseIndex;
  final String currentModelPath;
  final String currentCaseName;

  const BenchmarkProgress({
    required this.totalModels,
    required this.totalCasesPerModel,
    required this.totalRuns,
    required this.completedRuns,
    required this.currentModelIndex,
    required this.currentCaseIndex,
    required this.currentModelPath,
    required this.currentCaseName,
  });

  double get fractionComplete => totalRuns == 0 ? 0 : completedRuns / totalRuns;
  int get remainingRuns => totalRuns - completedRuns;
  String get currentModelName =>
      currentModelPath.split(Platform.pathSeparator).last;
}

// ── Aggregate result for a model ─────────────────────────────────────────

class BenchmarkModelResult {
  final String modelPath;
  final List<BenchmarkCaseResult> cases;

  const BenchmarkModelResult({required this.modelPath, required this.cases});

  String get modelName => modelPath.split(Platform.pathSeparator).last;
  int get passedCases => cases.where((c) => c.passed).length;
  double get avgTokensPerSecond => cases.isEmpty
      ? 0
      : cases.fold<double>(0, (sum, c) => sum + c.tokensPerSecond) /
            cases.length;
  Duration get totalElapsed =>
      cases.fold(Duration.zero, (sum, c) => sum + c.elapsed);
}

// ── Service ──────────────────────────────────────────────────────────────

class ModelBenchmarkService {
  static const Duration perCaseTimeout = Duration(seconds: 90);

  /// Prompt template to use for extraction.
  String promptTemplate = ChronoPromptTemplate.compactTemplate;

  /// Fixed reference time for deterministic tests.
  /// Wednesday March 11, 2026, 10:15 AM.
  static DateTime get referenceTime => benchmarkReferenceTime;

  static List<BenchmarkCase> get benchmarkCases => cases.benchmarkCases;

  /// Timer/alarm test cases only (for --headless-timer mode).
  static List<BenchmarkCase> get timerAlarmCases => benchmarkCases
      .where((c) => c.name.contains('timer') || c.name.contains('alarm'))
      .toList();

  Future<List<BenchmarkModelResult>> runForModels(
    List<String> modelPaths, {
    void Function(BenchmarkProgress progress)? onProgress,
    List<BenchmarkCase>? selectedCases,
  }) async {
    final results = <BenchmarkModelResult>[];
    final casesToRun = selectedCases ?? benchmarkCases;
    final totalCases = casesToRun.length;
    final totalRuns = modelPaths.length * totalCases;
    var completedRuns = 0;
    final pipeline = ChronoExtractionPipeline();

    for (var modelIndex = 0; modelIndex < modelPaths.length; modelIndex++) {
      final modelPath = modelPaths[modelIndex];
      final llm = LlmService()
        ..setModel(modelPath)
        ..nCtx = 4096
        ..nThreads = Platform.numberOfProcessors
        ..maxTokens = 384
        ..temperature = 0.3
        ..topP = 1.0
        ..presencePenalty = 2.0
        ..enableThinking = false;

      final caseResults = <BenchmarkCaseResult>[];
      try {
        for (var caseIndex = 0; caseIndex < casesToRun.length; caseIndex++) {
          final testCase = casesToRun[caseIndex];
          onProgress?.call(
            BenchmarkProgress(
              totalModels: modelPaths.length,
              totalCasesPerModel: totalCases,
              totalRuns: totalRuns,
              completedRuns: completedRuns,
              currentModelIndex: modelIndex,
              currentCaseIndex: caseIndex,
              currentModelPath: modelPath,
              currentCaseName: testCase.name,
            ),
          );

          // Use the shared ChronoPromptTemplate from chrono_ai_flow
          final prompt = ChronoPromptTemplate.render(
            promptTemplate,
            transcript: testCase.transcript,
            now: referenceTime,
          );

          try {
            final result = await llm.generate(prompt).timeout(perCaseTimeout);

            // Same post-processing as the app.
            final extractions = pipeline.extract(result.output);
            final times = pipeline.resolveTimes(extractions, referenceTime);
            // An empty array [] is valid JSON when we expect 0 items
            // (no-speech / garbage input).
            final validJson =
                extractions.isNotEmpty ||
                (testCase.expectedCount == 0 &&
                    _containsEmptyJsonArray(result.output));

            final extractedCount = extractions.length;
            final expectedCount = testCase.expectedCount;
            final countMatch = extractedCount == expectedCount;

            // Validate each expected item against extracted items.
            // Use positional matching: expected[i] ↔ extracted[i].
            var allIntentMatch = true;
            var allTimePresenceMatch = true;
            var allTitleLangMatch = true;
            var allTimeResMatch = true;
            var allDurationMatch = true;
            String? allTitleLangDetail;
            String? allTimeResDetail;
            String? allDurationDetail;
            final itemFailures = <String>[];

            final checkCount = extractedCount < expectedCount
                ? extractedCount
                : expectedCount;
            for (var i = 0; i < checkCount; i++) {
              final ext = extractions[i];
              final exp = testCase.expectedItems[i];

              final intentOk = intentMatches(ext.intent, exp.expectedIntent);
              if (!intentOk) {
                allIntentMatch = false;
                itemFailures.add(
                  'item[$i] intent: got "${ext.intent}", expected "${exp.expectedIntent}"',
                );
              }

              final hasTime =
                  ext.datetimeExpressionOriginal != null ||
                  ext.datetimeExpressionEnglish != null;
              if (hasTime != exp.expectTime) {
                allTimePresenceMatch = false;
                itemFailures.add(
                  'item[$i] time presence: got $hasTime, expected ${exp.expectTime}',
                );
              }

              final titleLang = checkTitleLanguage(ext.title, exp);
              if (!titleLang.passed) {
                allTitleLangMatch = false;
                itemFailures.add('item[$i] title lang: ${titleLang.detail}');
              }
              allTitleLangDetail =
                  (allTitleLangDetail ?? '') +
                  'item[$i]: ${titleLang.detail}; ';

              final timeRes = checkTimeResolution(
                ext.datetimeExpressionEnglish,
                times[i],
                exp,
              );
              if (!timeRes.passed) {
                allTimeResMatch = false;
                itemFailures.add('item[$i] time: ${timeRes.detail}');
              }
              allTimeResDetail =
                  (allTimeResDetail ?? '') + 'item[$i]: ${timeRes.detail}; ';

              // Duration validation for timer intents
              final durRes = checkDuration(ext.durationSeconds, exp);
              if (!durRes.passed) {
                allDurationMatch = false;
                itemFailures.add('item[$i] duration: ${durRes.detail}');
              }
              allDurationDetail =
                  (allDurationDetail ?? '') + 'item[$i]: ${durRes.detail}; ';
            }

            // If count mismatch, mark missing items as failures
            for (var i = checkCount; i < expectedCount; i++) {
              itemFailures.add('item[$i] missing from output');
              allIntentMatch = false;
              allTimePresenceMatch = false;
            }
            for (var i = checkCount; i < extractedCount; i++) {
              itemFailures.add('item[$i] unexpected extra extraction');
            }

            // Use first extraction for summary fields (backward compat)
            final first = extractions.isNotEmpty ? extractions.first : null;

            caseResults.add(
              BenchmarkCaseResult(
                caseName: testCase.name,
                validJson: validJson,
                intentMatch: allIntentMatch,
                timePresenceMatch: allTimePresenceMatch,
                titleLanguageMatch: allTitleLangMatch,
                titleLanguageDetail: allTitleLangDetail,
                timeResolutionCorrect: allTimeResMatch,
                timeResolutionDetail: allTimeResDetail,
                durationMatch: allDurationMatch,
                durationDetail: allDurationDetail,
                intent: first?.intent ?? '',
                title: first?.title,
                datetimeOriginal: first?.datetimeExpressionOriginal,
                datetimeEnglish: first?.datetimeExpressionEnglish,
                elapsed: result.elapsed,
                tokensPerSecond: result.tokensPerSecond,
                outputPreview: result.output.length > 300
                    ? '${result.output.substring(0, 300)}...'
                    : result.output,
                extractedCount: extractedCount,
                expectedCount: expectedCount,
                countMatch: countMatch,
                itemFailures: itemFailures,
              ),
            );
          } on TimeoutException {
            llm.cancelInference();
            caseResults.add(
              BenchmarkCaseResult(
                caseName: testCase.name,
                validJson: false,
                intentMatch: false,
                timePresenceMatch: false,
                titleLanguageMatch: false,
                timeResolutionCorrect: false,
                intent: 'timeout',
                elapsed: perCaseTimeout,
                tokensPerSecond: 0,
                outputPreview: 'Timed out after ${perCaseTimeout.inSeconds}s',
                error: 'Timed out after ${perCaseTimeout.inSeconds}s',
                extractedCount: 0,
                expectedCount: testCase.expectedCount,
                countMatch: false,
              ),
            );
          } catch (e) {
            llm.cancelInference();
            caseResults.add(
              BenchmarkCaseResult(
                caseName: testCase.name,
                validJson: false,
                intentMatch: false,
                timePresenceMatch: false,
                titleLanguageMatch: false,
                timeResolutionCorrect: false,
                intent: 'error',
                elapsed: Duration.zero,
                tokensPerSecond: 0,
                outputPreview: 'Error: $e',
                error: e.toString(),
                extractedCount: 0,
                expectedCount: testCase.expectedCount,
                countMatch: false,
              ),
            );
          }

          completedRuns++;
          onProgress?.call(
            BenchmarkProgress(
              totalModels: modelPaths.length,
              totalCasesPerModel: totalCases,
              totalRuns: totalRuns,
              completedRuns: completedRuns,
              currentModelIndex: modelIndex,
              currentCaseIndex: caseIndex,
              currentModelPath: modelPath,
              currentCaseName: testCase.name,
            ),
          );
        }
      } finally {
        llm.dispose();
      }

      results.add(
        BenchmarkModelResult(modelPath: modelPath, cases: caseResults),
      );
    }

    onProgress?.call(
      BenchmarkProgress(
        totalModels: modelPaths.length,
        totalCasesPerModel: totalCases,
        totalRuns: totalRuns,
        completedRuns: completedRuns,
        currentModelIndex: modelPaths.isEmpty ? 0 : modelPaths.length - 1,
        currentCaseIndex: totalCases == 0 ? 0 : totalCases - 1,
        currentModelPath: modelPaths.isEmpty ? '' : modelPaths.last,
        currentCaseName: benchmarkCases.isEmpty ? '' : benchmarkCases.last.name,
      ),
    );

    return results;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Check if the raw output contains an empty JSON array `[]`.
  bool _containsEmptyJsonArray(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), '');
    return cleaned.contains('[]');
  }
}
