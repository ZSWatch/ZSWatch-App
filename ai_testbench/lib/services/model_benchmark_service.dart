import 'dart:async';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/foundation.dart';

import 'llm_service.dart';

// ── Test case definition ─────────────────────────────────────────────────

class BenchmarkCase {
  final String name;
  final String transcript;
  final String expectedIntent; // 'reminder', 'event', 'note'
  final bool expectTime; // whether datetime fields should be non-null

  /// Keywords that should appear (case-insensitive) in the title to verify the
  /// model kept the output in the native language.
  /// Empty list => skip the check (always pass).
  final List<String> titleLanguageKeywords;

  /// Optional: expected resolved DateTime for time-resolution validation.
  final DateTime? expectedDateTime;

  /// Tolerance in minutes for DateTime comparison.
  final int toleranceMinutes;

  const BenchmarkCase({
    required this.name,
    required this.transcript,
    required this.expectedIntent,
    required this.expectTime,
    this.titleLanguageKeywords = const [],
    this.expectedDateTime,
    this.toleranceMinutes = 5,
  });
}

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

  const BenchmarkCaseResult({
    required this.caseName,
    required this.validJson,
    required this.intentMatch,
    required this.timePresenceMatch,
    this.titleLanguageMatch = true,
    this.titleLanguageDetail,
    this.timeResolutionCorrect = true,
    this.timeResolutionDetail,
    required this.intent,
    this.title,
    this.datetimeOriginal,
    this.datetimeEnglish,
    required this.elapsed,
    required this.tokensPerSecond,
    required this.outputPreview,
    this.error,
  });

  bool get passed =>
      validJson &&
      intentMatch &&
      timePresenceMatch &&
      titleLanguageMatch &&
      timeResolutionCorrect;
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

  const BenchmarkModelResult({
    required this.modelPath,
    required this.cases,
  });

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
  static const ChronoLlmParser _parser = ChronoLlmParser();

  /// Fixed reference time for deterministic tests.
  /// Wednesday March 11, 2026, 10:15 AM.
  static final DateTime referenceTime = DateTime(2026, 3, 11, 10, 15);

  static final benchmarkCases = <BenchmarkCase>[
    // ── English cases ──────────────────────────────────────────────────

    BenchmarkCase(
      name: 'en_event_precise_time',
      transcript:
          'Schedule a design review with Erik and Sara on March 14 at 3:30 PM in Lab 3.',
      expectedIntent: 'event',
      expectTime: true,
      expectedDateTime: DateTime(2026, 3, 14, 15, 30),
    ),
    BenchmarkCase(
      name: 'en_reminder_tomorrow',
      transcript:
          'Remind me tomorrow at 7:15 AM to take the prototype battery off the charger.',
      expectedIntent: 'reminder',
      expectTime: true,
      expectedDateTime: DateTime(2026, 3, 12, 7, 15),
    ),
    BenchmarkCase(
      name: 'en_event_next_tuesday',
      transcript: 'Meeting with John next Tuesday at 2 pm.',
      expectedIntent: 'event',
      expectTime: true,
      expectedDateTime: DateTime(2026, 3, 17, 14, 0),
    ),
    BenchmarkCase(
      name: 'en_reminder_next_friday',
      transcript:
          'I need to finish the PCB layout review and send it to the manufacturer by next Friday at 5 PM.',
      expectedIntent: 'reminder',
      expectTime: true,
      expectedDateTime: DateTime(2026, 3, 20, 17, 0),
    ),
    BenchmarkCase(
      name: 'en_event_dentist',
      transcript:
          'Dentist appointment on April 22nd at 10:30 AM at the clinic downtown.',
      expectedIntent: 'event',
      expectTime: true,
      expectedDateTime: DateTime(2026, 4, 22, 10, 30),
    ),
    BenchmarkCase(
      name: 'en_note_no_time',
      transcript:
          'Had an interesting idea about using a pressure sensor to detect altitude changes for the hiking app.',
      expectedIntent: 'note',
      expectTime: false,
    ),
    BenchmarkCase(
      name: 'en_reminder_this_afternoon',
      transcript: 'Call the plumber this afternoon at 3.',
      expectedIntent: 'reminder',
      expectTime: true,
      expectedDateTime: DateTime(2026, 3, 11, 15, 0),
    ),

    // ── Swedish cases (native language title validation) ──────────────

    BenchmarkCase(
      name: 'sv_reminder_tomorrow',
      transcript: 'Påminn mig imorgon klockan 8 att ringa tandläkaren.',
      expectedIntent: 'reminder',
      expectTime: true,
      titleLanguageKeywords: ['ringa', 'tandläkare'],
      expectedDateTime: DateTime(2026, 3, 12, 8, 0),
    ),
    BenchmarkCase(
      name: 'sv_event_meeting',
      transcript:
          'Möte med projektgruppen på torsdag klockan 14 i stora konferensrummet.',
      expectedIntent: 'event',
      expectTime: true,
      titleLanguageKeywords: ['möte', 'projektgrupp'],
      expectedDateTime: DateTime(2026, 3, 12, 14, 0),
    ),
    BenchmarkCase(
      name: 'sv_note_no_time',
      transcript: 'Köp mjölk och bröd på vägen hem.',
      expectedIntent: 'note',
      expectTime: false,
      titleLanguageKeywords: ['köp', 'mjölk', 'bröd'],
    ),
    BenchmarkCase(
      name: 'sv_note_idea',
      transcript:
          'Bra idé om att lägga till stegräknare i klockan, kanske använda BMI270 sensorn.',
      expectedIntent: 'note',
      expectTime: false,
      titleLanguageKeywords: ['stegräknare', 'klocka', 'idé', 'sensor'],
    ),
    BenchmarkCase(
      name: 'sv_event_specific_date',
      transcript: 'Tandläkare den 15 mars klockan halv 10.',
      expectedIntent: 'event',
      expectTime: true,
      titleLanguageKeywords: ['tandläkare'],
      expectedDateTime: DateTime(2026, 3, 15, 9, 30),
    ),

    // ── German cases (native language title validation) ───────────────

    BenchmarkCase(
      name: 'de_event_appointment',
      transcript:
          'Arzttermin am Donnerstag um 9 Uhr in der Praxis am Marktplatz.',
      expectedIntent: 'event',
      expectTime: true,
      titleLanguageKeywords: ['arzt', 'termin', 'praxis'],
      expectedDateTime: DateTime(2026, 3, 12, 9, 0),
    ),
    BenchmarkCase(
      name: 'de_reminder_deadline',
      transcript:
          'Ich muss den Bericht bis Freitag um 17 Uhr fertig haben und an den Chef schicken.',
      expectedIntent: 'reminder',
      expectTime: true,
      titleLanguageKeywords: ['bericht', 'chef', 'schicken'],
      expectedDateTime: DateTime(2026, 3, 13, 17, 0),
    ),
  ];

  Future<List<BenchmarkModelResult>> runForModels(
    List<String> modelPaths, {
    void Function(BenchmarkProgress progress)? onProgress,
  }) async {
    final results = <BenchmarkModelResult>[];
    final totalCases = benchmarkCases.length;
    final totalRuns = modelPaths.length * totalCases;
    var completedRuns = 0;
    final resolver = TimeExpressionResolver();

    for (var modelIndex = 0; modelIndex < modelPaths.length; modelIndex++) {
      final modelPath = modelPaths[modelIndex];
      final llm = LlmService()
        ..setModel(modelPath)
        ..nCtx = 2048
        ..nThreads = Platform.numberOfProcessors
        ..maxTokens = 384
        ..temperature = 0.1
        ..enableThinking = false;

      final caseResults = <BenchmarkCaseResult>[];
      try {
        for (var caseIndex = 0;
            caseIndex < benchmarkCases.length;
            caseIndex++) {
          final testCase = benchmarkCases[caseIndex];
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
            ChronoPromptTemplate.defaultTemplate,
            transcript: testCase.transcript,
            now: referenceTime,
          );

          try {
            final result = await llm
                .generate(prompt)
                .timeout(perCaseTimeout);

            // Parse using the shared ChronoLlmParser
            final parseResult = _parser.parse(result.output);
            final extraction = parseResult.extraction;

            final validJson = extraction != null;
            final intent = extraction?.intent ?? '';
            final title = extraction?.title;
            final dtOriginal = extraction?.datetimeExpressionOriginal;
            final dtEnglish = extraction?.datetimeExpressionEnglish;

            // Intent validation
            final intentMatch =
                _intentMatches(intent, testCase.expectedIntent);

            // Time presence validation
            final hasTime = dtOriginal != null || dtEnglish != null;
            final timePresenceMatch = hasTime == testCase.expectTime;

            // Title language validation
            final titleLang = _checkTitleLanguage(title, testCase);

            // Time resolution validation
            final timeRes = _checkTimeResolution(
              dtEnglish ?? dtOriginal,
              testCase,
              resolver,
            );

            caseResults.add(
              BenchmarkCaseResult(
                caseName: testCase.name,
                validJson: validJson,
                intentMatch: intentMatch,
                timePresenceMatch: timePresenceMatch,
                titleLanguageMatch: titleLang.passed,
                titleLanguageDetail: titleLang.detail,
                timeResolutionCorrect: timeRes.passed,
                timeResolutionDetail: timeRes.detail,
                intent: intent,
                title: title,
                datetimeOriginal: dtOriginal,
                datetimeEnglish: dtEnglish,
                elapsed: result.elapsed,
                tokensPerSecond: result.tokensPerSecond,
                outputPreview: result.output.length > 300
                    ? '${result.output.substring(0, 300)}...'
                    : result.output,
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
                outputPreview:
                    'Timed out after ${perCaseTimeout.inSeconds}s',
                error: 'Timed out after ${perCaseTimeout.inSeconds}s',
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
          BenchmarkModelResult(modelPath: modelPath, cases: caseResults));
    }

    onProgress?.call(
      BenchmarkProgress(
        totalModels: modelPaths.length,
        totalCasesPerModel: totalCases,
        totalRuns: totalRuns,
        completedRuns: completedRuns,
        currentModelIndex:
            modelPaths.isEmpty ? 0 : modelPaths.length - 1,
        currentCaseIndex: totalCases == 0 ? 0 : totalCases - 1,
        currentModelPath: modelPaths.isEmpty ? '' : modelPaths.last,
        currentCaseName:
            benchmarkCases.isEmpty ? '' : benchmarkCases.last.name,
      ),
    );

    return results;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool _intentMatches(String got, String expected) {
    final g = got.toLowerCase().trim();
    final e = expected.toLowerCase().trim();
    if (g == e) return true;
    // Allow note <-> task fuzzy match (no time = note)
    if ({g, e}.containsAll({'note', 'task'})) return true;
    return false;
  }

  _CheckResult _checkTitleLanguage(String? title, BenchmarkCase testCase) {
    if (testCase.titleLanguageKeywords.isEmpty) {
      return const _CheckResult(passed: true, detail: 'no keyword check');
    }
    if (title == null || title.isEmpty) {
      return const _CheckResult(
        passed: false,
        detail: 'no title in output',
      );
    }

    final lower = title.toLowerCase();
    final matched = <String>[];
    for (final keyword in testCase.titleLanguageKeywords) {
      if (lower.contains(keyword.toLowerCase())) {
        matched.add(keyword);
      }
    }

    final passed = matched.isNotEmpty;
    final detail = passed
        ? 'found ${matched.join(", ")} in "$title"'
        : 'none of [${testCase.titleLanguageKeywords.join(", ")}] found in "$title"';

    return _CheckResult(passed: passed, detail: detail);
  }

  _CheckResult _checkTimeResolution(
    String? timeExpr,
    BenchmarkCase testCase,
    TimeExpressionResolver resolver,
  ) {
    if (testCase.expectedDateTime == null) {
      return const _CheckResult(passed: true, detail: 'no time check');
    }
    if (timeExpr == null || timeExpr.isEmpty) {
      return const _CheckResult(
        passed: false,
        detail: 'no time expression to resolve',
      );
    }

    final resolved = resolver.resolve(
      timeExpr,
      referenceDate: referenceTime,
    );

    if (resolved == null) {
      return _CheckResult(
        passed: false,
        detail: 'chrono failed to parse "$timeExpr"',
      );
    }

    final diff = resolved.dateTime
        .difference(testCase.expectedDateTime!)
        .inMinutes
        .abs();
    if (diff > testCase.toleranceMinutes) {
      return _CheckResult(
        passed: false,
        detail:
            'got ${resolved.dateTime}, expected ${testCase.expectedDateTime} '
            '(diff ${diff}min, tolerance ${testCase.toleranceMinutes}min)',
      );
    }

    return _CheckResult(
      passed: true,
      detail: '${resolved.dateTime} OK (via ${resolved.method})',
    );
  }
}

class _CheckResult {
  final bool passed;
  final String? detail;
  const _CheckResult({required this.passed, this.detail});
}
