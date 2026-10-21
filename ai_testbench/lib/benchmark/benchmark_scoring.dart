import 'package:chrono_ai_flow/chrono_ai_flow.dart';

import 'benchmark_cases.dart';

bool intentMatches(String got, String expected) {
  final g = got.toLowerCase().trim();
  final e = expected.toLowerCase().trim();
  if (g == e) return true;
  // Allow note <-> task fuzzy match (no time = note)
  if ({g, e}.containsAll({'note', 'task'})) return true;
  // Allow countdown <-> timer fuzzy match
  if ({g, e}.containsAll({'countdown', 'timer'})) return true;
  return false;
}

CheckResult checkTitleLanguage(String? title, ExpectedItem item) {
  if (item.titleLanguageKeywords.isEmpty) {
    return const CheckResult(passed: true, detail: 'no keyword check');
  }
  if (title == null || title.isEmpty) {
    return const CheckResult(passed: false, detail: 'no title in output');
  }

  final lower = title.toLowerCase();
  final matched = <String>[];
  for (final keyword in item.titleLanguageKeywords) {
    if (lower.contains(keyword.toLowerCase())) {
      matched.add(keyword);
    }
  }

  final passed = matched.isNotEmpty;
  final detail = passed
      ? 'found ${matched.join(", ")} in "$title"'
      : 'none of [${item.titleLanguageKeywords.join(", ")}] found in "$title"';

  return CheckResult(passed: passed, detail: detail);
}

CheckResult checkDuration(int? gotDuration, ExpectedItem item) {
  if (item.expectedDurationSeconds == null) {
    return const CheckResult(passed: true, detail: 'no duration check');
  }
  if (gotDuration == null) {
    return const CheckResult(
      passed: false,
      detail: 'no duration_seconds in output',
    );
  }
  final diff = (gotDuration - item.expectedDurationSeconds!).abs();
  if (diff > item.durationToleranceSeconds) {
    return CheckResult(
      passed: false,
      detail:
          'got ${gotDuration}s, expected ${item.expectedDurationSeconds}s '
          '(diff ${diff}s, tolerance ${item.durationToleranceSeconds}s)',
    );
  }
  return CheckResult(passed: true, detail: '${gotDuration}s OK');
}

/// [resolved] comes from [ChronoExtractionPipeline.resolveTimes], as in the app.
CheckResult checkTimeResolution(
  String? timeExpr,
  ResolvedTime? resolved,
  ExpectedItem item,
) {
  if (item.expectedDateTime == null) {
    return const CheckResult(passed: true, detail: 'no time check');
  }
  if (timeExpr == null || timeExpr.isEmpty) {
    return const CheckResult(
      passed: false,
      detail: 'no time expression to resolve',
    );
  }
  if (resolved == null) {
    return CheckResult(
      passed: false,
      detail: 'chrono failed to parse "$timeExpr"',
    );
  }
  final diff = resolved.dateTime
      .difference(item.expectedDateTime!)
      .inMinutes
      .abs();
  if (diff > item.toleranceMinutes) {
    return CheckResult(
      passed: false,
      detail:
          'got ${resolved.dateTime} ("$timeExpr"), expected ${item.expectedDateTime}',
    );
  }
  return CheckResult(
    passed: true,
    detail: '${resolved.dateTime} OK (via ${resolved.method})',
  );
}

class CheckResult {
  final bool passed;
  final String? detail;
  const CheckResult({required this.passed, this.detail});
}

/// Failures of one case; empty when it passed. Items are matched by position.
List<String> scoreCase(
  BenchmarkCase testCase,
  List<ChronoLlmExtraction> extractions, {
  ChronoExtractionPipeline? pipeline,
}) {
  final times = (pipeline ?? ChronoExtractionPipeline()).resolveTimes(
    extractions,
    benchmarkReferenceTime,
  );
  final failures = <String>[];
  final expected = testCase.expectedItems;
  if (extractions.length != expected.length) {
    failures.add('items ${extractions.length} != ${expected.length}');
  }
  for (var i = 0; i < extractions.length && i < expected.length; i++) {
    final got = extractions[i];
    final want = expected[i];
    if (!intentMatches(got.intent, want.expectedIntent)) {
      failures.add('[$i] intent ${got.intent} != ${want.expectedIntent}');
      continue;
    }
    final hasTime =
        got.datetimeExpressionOriginal != null ||
        got.datetimeExpressionEnglish != null;
    if (hasTime != want.expectTime) {
      failures.add('[$i] time present $hasTime != ${want.expectTime}');
    }
    for (final check in [
      checkTitleLanguage(got.title, want),
      if (got.intent != 'timer')
        checkTimeResolution(got.datetimeExpressionEnglish, times[i], want),
      checkDuration(got.durationSeconds, want),
    ]) {
      if (!check.passed) failures.add('[$i] ${check.detail}');
    }
  }
  return failures;
}

/// Groups cases for the per-category summary.
String categoryOf(BenchmarkCase testCase) {
  final items = testCase.expectedItems;
  if (items.isEmpty) return 'nospeech';
  if (items.length > 1) return 'multi';
  return items.single.expectedIntent;
}
