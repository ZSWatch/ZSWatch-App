import 'package:flutter/foundation.dart';

import 'llm_service.dart';

/// Runs a quick self-test of the AI inference pipeline at startup.
///
/// This is a **development-time smoke test** — remove before release.
///
/// Call through [runAiStartupTest] in `ai_providers.dart` which resolves
/// [LlmService] from the Riverpod graph.
Future<void> aiStartupSelfTest(LlmService llm) async {
  debugPrint('[AiStartupTest] ========== AI STARTUP SELF-TEST START ==========');
  final sw = Stopwatch()..start();

  int passed = 0;
  int failed = 0;

  // ----- Test 1: English classify -----
  await _runTest(
    name: 'classify_en',
    input:
        'Remind me to call the mechanic tomorrow at 3 PM about the brakes '
        'and also pick up milk on the way home.',
    llm: llm,
    onPass: () => passed++,
    onFail: () => failed++,
  );

  // ----- Test 2: Swedish classify -----
  await _runTest(
    name: 'note_sv',
    input:
        'Kom ihåg att köpa mjölk och bröd på vägen hem. '
        'Dessutom behöver jag ringa tandläkaren.',
    llm: llm,
    onPass: () => passed++,
    onFail: () => failed++,
  );

  sw.stop();
  debugPrint('[AiStartupTest] Tests: $passed passed, $failed failed '
      '(total ${sw.elapsedMilliseconds} ms)');
  debugPrint('[AiStartupTest] ========== AI STARTUP SELF-TEST END ==========');
}

Future<void> _runTest({
  required String name,
  required String input,
  required LlmService llm,
  required VoidCallback onPass,
  required VoidCallback onFail,
}) async {
  debugPrint('[AiStartupTest] --- Test: $name ---');
  debugPrint('[AiStartupTest] Input: "$input"');

  try {
    final testSw = Stopwatch()..start();
    final result = await llm.processTranscript(input);
    testSw.stop();

    debugPrint('[AiStartupTest]   Summary   : ${result.summary}');
    debugPrint('[AiStartupTest]   Category  : ${result.category}');
    debugPrint('[AiStartupTest]   Actions   : ${result.actions.length}');
    debugPrint('[AiStartupTest]   Time      : ${testSw.elapsedMilliseconds} ms');
    debugPrint('[AiStartupTest]   Result    : PASS ✓');
    onPass();
  } catch (e) {
    debugPrint('[AiStartupTest]   Error     : $e');
    debugPrint('[AiStartupTest]   Result    : FAIL ✗');
    onFail();
  }
  debugPrint('[AiStartupTest] ');
}
