import 'dart:async';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/foundation.dart';

import 'llm_service.dart';

// ── Test case definition ─────────────────────────────────────────────────

class CorrectionBenchmarkCase {
  /// Unique name for the test case.
  final String name;

  /// The "bad" transcript as Whisper might produce it.
  final String input;

  /// The ideal corrected output (used for display / human review).
  final String expectedOutput;

  /// Words/phrases that MUST appear in the corrected output (case-insensitive).
  /// Used to verify the model actually performed a specific fix.
  final List<String> mustContain;

  /// Words/phrases that must NOT appear in the corrected output (case-insensitive).
  /// Used to verify the model removed errors / filler.
  final List<String> mustNotContain;

  /// If true, the model MUST change the text (detect and fix an error).
  /// If false (clean input), the model should return it mostly unchanged.
  final bool expectModification;

  /// Language of the input.
  final String language;

  const CorrectionBenchmarkCase({
    required this.name,
    required this.input,
    required this.expectedOutput,
    this.mustContain = const [],
    this.mustNotContain = const [],
    this.expectModification = true,
    this.language = 'en',
  });
}

// ── Test result ──────────────────────────────────────────────────────────

class CorrectionCaseResult {
  final String caseName;
  final String input;
  final String expectedOutput;
  final String actualOutput;
  final bool wasModified;
  final bool modificationExpected;
  final bool modificationMatch;
  final bool allMustContainFound;
  final List<String> missingKeywords;
  final bool allMustNotContainAbsent;
  final List<String> unwantedKeywordsFound;
  final bool cleanOutput;
  final String? cleanOutputDetail;
  final Duration elapsed;
  final double tokensPerSecond;
  final String? error;

  const CorrectionCaseResult({
    required this.caseName,
    required this.input,
    required this.expectedOutput,
    required this.actualOutput,
    required this.wasModified,
    required this.modificationExpected,
    required this.modificationMatch,
    required this.allMustContainFound,
    required this.missingKeywords,
    required this.allMustNotContainAbsent,
    required this.unwantedKeywordsFound,
    required this.cleanOutput,
    this.cleanOutputDetail,
    required this.elapsed,
    required this.tokensPerSecond,
    this.error,
  });

  bool get passed =>
      error == null &&
      modificationMatch &&
      allMustContainFound &&
      allMustNotContainAbsent &&
      cleanOutput;
}

// ── Progress ─────────────────────────────────────────────────────────────

class CorrectionBenchmarkProgress {
  final int totalModels;
  final int totalCasesPerModel;
  final int totalRuns;
  final int completedRuns;
  final int currentModelIndex;
  final int currentCaseIndex;
  final String currentModelPath;
  final String currentCaseName;

  const CorrectionBenchmarkProgress({
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
  String get currentModelName =>
      currentModelPath.split(Platform.pathSeparator).last;
}

// ── Aggregate result for a model ─────────────────────────────────────────

class CorrectionModelResult {
  final String modelPath;
  final List<CorrectionCaseResult> cases;

  const CorrectionModelResult({required this.modelPath, required this.cases});

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

class CorrectionBenchmarkService {
  static const Duration perCaseTimeout = Duration(seconds: 60);

  // ── The correction prompt — uses the shared package ───────────────────

  static String buildCorrectionPrompt(String transcript) {
    return CorrectionPromptTemplate.render(
      CorrectionPromptTemplate.defaultTemplate,
      transcript: transcript,
    );
  }

  // ── Benchmark cases ───────────────────────────────────────────────────

  static final benchmarkCases = <CorrectionBenchmarkCase>[
    // ── English: Whisper homophone / wrong-word errors ──────────────────
    const CorrectionBenchmarkCase(
      name: 'en_homophone_weak_week',
      input: 'I need to finish the report by next weak',
      expectedOutput: 'I need to finish the report by next week.',
      mustContain: ['week'],
      mustNotContain: ['weak'],
    ),
    const CorrectionBenchmarkCase(
      name: 'en_homophone_by_buy',
      input: 'remind me to by milk on the way home',
      expectedOutput: 'Remind me to buy milk on the way home.',
      mustContain: ['buy'],
      mustNotContain: ['by milk'], // "by" alone might appear in "nearby" etc
    ),
    const CorrectionBenchmarkCase(
      name: 'en_homophone_meat_meet',
      input: "let's meat at the café at half passed three",
      expectedOutput: "Let's meet at the café at half past three.",
      mustContain: ['meet', 'past'],
      mustNotContain: ['meat', 'passed'],
    ),
    const CorrectionBenchmarkCase(
      name: 'en_homophone_wood_would',
      input: 'she said she wood come at for a clock',
      expectedOutput: "She said she would come at four o'clock.",
      mustContain: ['would'],
      mustNotContain: ['wood'],
    ),
    const CorrectionBenchmarkCase(
      name: 'en_wrong_word_nonsense',
      input:
          'I have a dentist appointment and I need to cancel it because I have a cold and a terrible headache',
      expectedOutput:
          'I have a dentist appointment and I need to cancel it because I have a cold and a terrible headache.',
      mustContain: ['dentist', 'cancel', 'headache'],
      expectModification: false, // Clean input — should pass through
    ),

    // ── English: filler words + stuttering ──────────────────────────────
    const CorrectionBenchmarkCase(
      name: 'en_filler_um_stutter',
      input: 'I I need to um finish the report and and send it to the the boss',
      expectedOutput: 'I need to finish the report and send it to the boss.',
      mustContain: ['finish the report', 'send it to the boss'],
      mustNotContain: ['I I', 'and and', 'the the', ' um '],
    ),
    const CorrectionBenchmarkCase(
      name: 'en_filler_heavy',
      input:
          'so uh you know I was like thinking we should you know maybe like schedule a meeting',
      expectedOutput: 'I was thinking we should maybe schedule a meeting.',
      mustContain: ['schedule', 'meeting'],
      mustNotContain: [' uh '],
    ),

    // ── English: missing/wrong punctuation ──────────────────────────────
    const CorrectionBenchmarkCase(
      name: 'en_missing_punctuation',
      input:
          'call the plumber tomorrow at 3 then pick up the kids at 5 and dont forget to buy groceries',
      expectedOutput:
          "Call the plumber tomorrow at 3, then pick up the kids at 5, and don't forget to buy groceries.",
      mustContain: ['plumber', 'kids', 'groceries'],
      mustNotContain: [],
      expectModification:
          false, // punctuation-only change is acceptable either way
    ),

    // ── English: Whisper word-boundary / context errors ─────────────────
    const CorrectionBenchmarkCase(
      name: 'en_word_boundary',
      input:
          'I can not believe they moved the meeting to an other day with out telling us',
      expectedOutput:
          'I cannot believe they moved the meeting to another day without telling us.',
      mustContain: ['another', 'without'],
      mustNotContain: ['an other', 'with out'],
    ),

    // ── Swedish: Whisper errors ─────────────────────────────────────────
    const CorrectionBenchmarkCase(
      name: 'sv_filler_stutter',
      input: 'jag ska eh köpa köpa mjölk och bröd på på hemvägen',
      expectedOutput: 'Jag ska köpa mjölk och bröd på hemvägen.',
      mustContain: ['köpa mjölk'],
      mustNotContain: ['köpa köpa', 'på på', ' eh '],
      language: 'sv',
    ),
    const CorrectionBenchmarkCase(
      name: 'sv_split_word_imorgon',
      input: 'påminn mig att skicka rapporten till chefen i morgan',
      expectedOutput: 'Påminn mig att skicka rapporten till chefen imorgon.',
      mustContain: ['imorgon'],
      mustNotContain: ['i morgan'],
      language: 'sv',
    ),
    const CorrectionBenchmarkCase(
      name: 'sv_missing_umlaut',
      input: 'vi har mote med kunden pa torsdag klockan tva',
      expectedOutput: 'Vi har möte med kunden på torsdag klockan två.',
      mustContain: ['möte', 'på', 'två'],
      mustNotContain: ['mote', ' pa ', 'tva'],
      language: 'sv',
    ),
    const CorrectionBenchmarkCase(
      name: 'sv_clean_passthrough',
      input: 'Boka tandläkare på fredag klockan 10.',
      expectedOutput: 'Boka tandläkare på fredag klockan 10.',
      mustContain: ['tandläkare', 'fredag'],
      expectModification: false, // Clean input
      language: 'sv',
    ),
    const CorrectionBenchmarkCase(
      name: 'sv_wrong_word_whisper',
      input: 'ring veterinären och boka en tid för katten som har ont i ögat',
      expectedOutput:
          'Ring veterinären och boka en tid för katten som har ont i ögat.',
      mustContain: ['veterinären', 'katten'],
      expectModification: false, // Clean-ish input
      language: 'sv',
    ),

    // ── German: Whisper errors ──────────────────────────────────────────
    const CorrectionBenchmarkCase(
      name: 'de_missing_umlaut',
      input:
          'ich muss den Arzt anrufen und einen Termin fur nachste Woche machen',
      expectedOutput:
          'Ich muss den Arzt anrufen und einen Termin für nächste Woche machen.',
      mustContain: ['für', 'nächste'],
      mustNotContain: [' fur ', 'nachste'],
      language: 'de',
    ),
    const CorrectionBenchmarkCase(
      name: 'de_filler_stutter',
      input: 'also ich äh muss muss noch die die Präsentation fertig machen',
      expectedOutput: 'Ich muss noch die Präsentation fertig machen.',
      mustContain: ['Präsentation', 'fertig'],
      mustNotContain: ['muss muss', 'die die', ' äh ', 'also ich'],
      language: 'de',
    ),

    // ── English: Whisper misheard context-dependent words ──────────────
    const CorrectionBenchmarkCase(
      name: 'en_misheard_their_there',
      input: 'I left my keys over their on the table',
      expectedOutput: 'I left my keys over there on the table.',
      mustContain: ['there'],
      mustNotContain: ['their'],
    ),
    const CorrectionBenchmarkCase(
      name: 'en_misheard_your_youre',
      input: 'your going to be late if you dont leave now',
      expectedOutput: "You're going to be late if you don't leave now.",
      mustContain: ['late', 'leave'],
      mustNotContain: [],
    ),
    const CorrectionBenchmarkCase(
      name: 'en_clean_long_sentence',
      input:
          'I had a great meeting with the design team today and we agreed on the new color scheme for the watch face',
      expectedOutput:
          'I had a great meeting with the design team today and we agreed on the new color scheme for the watch face.',
      mustContain: ['design team', 'color scheme', 'watch face'],
      expectModification: false,
    ),

    // ── English: Whisper garbled multi-word ─────────────────────────
    const CorrectionBenchmarkCase(
      name: 'en_garbled_sentence',
      input:
          'the whether is really nice today so lets go for a walk in the park',
      expectedOutput:
          "The weather is really nice today so let's go for a walk in the park.",
      mustContain: ['weather'],
      mustNotContain: ['whether'],
    ),
    const CorrectionBenchmarkCase(
      name: 'en_multiple_errors_combined',
      input:
          'I need to by some flower for the party its on wendsday at there house',
      expectedOutput:
          "I need to buy some flowers for the party, it's on Wednesday at their house.",
      mustContain: ['buy', 'Wednesday'],
      mustNotContain: ['by some', 'wendsday'],
    ),

    // ── Swedish: more realistic Whisper errors ───────────────────
    const CorrectionBenchmarkCase(
      name: 'sv_filler_liksom',
      input: 'jag tankte liksom att vi kanske liksom borde traffas imorgon',
      expectedOutput: 'Jag tänkte att vi kanske borde träffas imorgon.',
      mustContain: ['tänkte', 'träffas'],
      mustNotContain: ['tankte', 'traffas'],
      language: 'sv',
    ),
    const CorrectionBenchmarkCase(
      name: 'sv_whisper_number',
      input: 'klockan ar halv atta och jag maste ga nu',
      expectedOutput: 'Klockan är halv åtta och jag måste gå nu.',
      mustContain: ['är', 'åtta', 'måste', 'gå'],
      mustNotContain: [' ar ', ' atta', 'maste', ' ga '],
      language: 'sv',
    ),
    const CorrectionBenchmarkCase(
      name: 'sv_clean_longer',
      input: 'Vi ses på kontoret imorgon bitti för att gå igenom rapporten.',
      expectedOutput:
          'Vi ses på kontoret imorgon bitti för att gå igenom rapporten.',
      mustContain: ['kontoret', 'rapporten'],
      expectModification: false,
      language: 'sv',
    ),

    // ── German: more realistic Whisper errors ───────────────────
    const CorrectionBenchmarkCase(
      name: 'de_eszett_and_umlaut',
      input: 'ich weiss nicht ob er die strasse finden konnte',
      expectedOutput: 'Ich weiß nicht, ob er die Straße finden konnte.',
      mustContain: ['weiß', 'Straße'],
      mustNotContain: ['weiss', 'strasse'],
      language: 'de',
    ),
    const CorrectionBenchmarkCase(
      name: 'de_clean_passthrough',
      input: 'Bitte ruf mich morgen früh an.',
      expectedOutput: 'Bitte ruf mich morgen früh an.',
      mustContain: ['morgen', 'früh'],
      expectModification: false,
      language: 'de',
    ),
  ];

  // ── Run benchmark ─────────────────────────────────────────────────────

  Future<List<CorrectionModelResult>> runForModels(
    List<String> modelPaths, {
    void Function(CorrectionBenchmarkProgress progress)? onProgress,
  }) async {
    final results = <CorrectionModelResult>[];
    final totalCases = benchmarkCases.length;
    final totalRuns = modelPaths.length * totalCases;
    var completedRuns = 0;

    for (var modelIndex = 0; modelIndex < modelPaths.length; modelIndex++) {
      final modelPath = modelPaths[modelIndex];
      final llm = LlmService()
        ..setModel(modelPath)
        ..nCtx = 2048
        ..nThreads = Platform.numberOfProcessors
        ..temperature = 0.0
        ..enableThinking = false;

      final caseResults = <CorrectionCaseResult>[];
      try {
        for (
          var caseIndex = 0;
          caseIndex < benchmarkCases.length;
          caseIndex++
        ) {
          final testCase = benchmarkCases[caseIndex];
          onProgress?.call(
            CorrectionBenchmarkProgress(
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

          final prompt = buildCorrectionPrompt(testCase.input);
          final maxTok = CorrectionPromptTemplate.estimateMaxTokens(
            testCase.input,
          );

          try {
            final result = await llm
                .generate(prompt, overrideMaxTokens: maxTok)
                .timeout(perCaseTimeout);

            final output = _cleanOutput(result.output);
            final check = _evaluate(testCase, output);

            caseResults.add(
              CorrectionCaseResult(
                caseName: testCase.name,
                input: testCase.input,
                expectedOutput: testCase.expectedOutput,
                actualOutput: output,
                wasModified: check.wasModified,
                modificationExpected: testCase.expectModification,
                modificationMatch: check.modificationMatch,
                allMustContainFound: check.allMustContainFound,
                missingKeywords: check.missingKeywords,
                allMustNotContainAbsent: check.allMustNotContainAbsent,
                unwantedKeywordsFound: check.unwantedKeywordsFound,
                cleanOutput: check.cleanOutput,
                cleanOutputDetail: check.cleanOutputDetail,
                elapsed: result.elapsed,
                tokensPerSecond: result.tokensPerSecond,
              ),
            );
          } on TimeoutException {
            llm.cancelInference();
            caseResults.add(
              CorrectionCaseResult(
                caseName: testCase.name,
                input: testCase.input,
                expectedOutput: testCase.expectedOutput,
                actualOutput: '',
                wasModified: false,
                modificationExpected: testCase.expectModification,
                modificationMatch: false,
                allMustContainFound: false,
                missingKeywords: testCase.mustContain,
                allMustNotContainAbsent: true,
                unwantedKeywordsFound: const [],
                cleanOutput: false,
                cleanOutputDetail: 'Timed out',
                elapsed: perCaseTimeout,
                tokensPerSecond: 0,
                error: 'Timed out after ${perCaseTimeout.inSeconds}s',
              ),
            );
          } catch (e) {
            llm.cancelInference();
            caseResults.add(
              CorrectionCaseResult(
                caseName: testCase.name,
                input: testCase.input,
                expectedOutput: testCase.expectedOutput,
                actualOutput: '',
                wasModified: false,
                modificationExpected: testCase.expectModification,
                modificationMatch: false,
                allMustContainFound: false,
                missingKeywords: testCase.mustContain,
                allMustNotContainAbsent: true,
                unwantedKeywordsFound: const [],
                cleanOutput: false,
                cleanOutputDetail: 'Error: $e',
                elapsed: Duration.zero,
                tokensPerSecond: 0,
                error: e.toString(),
              ),
            );
          }

          completedRuns++;
          onProgress?.call(
            CorrectionBenchmarkProgress(
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
        CorrectionModelResult(modelPath: modelPath, cases: caseResults),
      );
    }

    return results;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Strip common LLM wrapper cruft from the output.
  String _cleanOutput(String raw) {
    var output = raw.trim();

    // Strip markdown code fences (```text ... ``` or ```\n ... ```)
    final codeFenceRe = RegExp(r'^```[a-zA-Z]*\n?(.*?)\n?```$', dotAll: true);
    final codeFenceMatch = codeFenceRe.firstMatch(output);
    if (codeFenceMatch != null) {
      output = codeFenceMatch.group(1)!.trim();
    }

    // Remove surrounding quotes
    if ((output.startsWith('"') && output.endsWith('"')) ||
        (output.startsWith("'") && output.endsWith("'"))) {
      output = output.substring(1, output.length - 1).trim();
    }

    // If model prefixed with "Output:" or "Corrected:" etc., take what's after
    final prefixes = [
      'output:',
      'corrected:',
      'corrected transcription:',
      'corrected text:',
    ];
    final lower = output.toLowerCase();
    for (final prefix in prefixes) {
      if (lower.startsWith(prefix)) {
        output = output.substring(prefix.length).trim();
        // Remove surrounding quotes again after prefix removal
        if ((output.startsWith('"') && output.endsWith('"')) ||
            (output.startsWith("'") && output.endsWith("'"))) {
          output = output.substring(1, output.length - 1).trim();
        }
        break;
      }
    }

    return output;
  }

  _EvalResult _evaluate(CorrectionBenchmarkCase testCase, String output) {
    final outputLower = output.toLowerCase();
    final inputLower = testCase.input.toLowerCase();

    // Check if modified (normalize whitespace + case for comparison)
    final normalizedInput = inputLower.replaceAll(RegExp(r'\s+'), ' ').trim();
    final normalizedOutput = outputLower.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Strip trailing punctuation for comparison
    final normalizedInputNoPunct = normalizedInput
        .replaceAll(RegExp(r'[.!?,;:]+$'), '')
        .trim();
    final normalizedOutputNoPunct = normalizedOutput
        .replaceAll(RegExp(r'[.!?,;:]+$'), '')
        .trim();
    final wasModified = normalizedInputNoPunct != normalizedOutputNoPunct;

    // Modification expectation check
    // If modification is expected, it must have changed
    // If no modification expected, echoing it back is fine (but changing is also OK)
    final modificationMatch = testCase.expectModification ? wasModified : true;

    // Must-contain check
    final missingKeywords = <String>[];
    for (final keyword in testCase.mustContain) {
      if (!outputLower.contains(keyword.toLowerCase())) {
        missingKeywords.add(keyword);
      }
    }

    // Must-not-contain check
    final unwantedFound = <String>[];
    for (final keyword in testCase.mustNotContain) {
      if (outputLower.contains(keyword.toLowerCase())) {
        unwantedFound.add(keyword);
      }
    }

    // Clean output check — no markdown, no explanations
    final isClean = _checkClean(output);

    return _EvalResult(
      wasModified: wasModified,
      modificationMatch: modificationMatch,
      allMustContainFound: missingKeywords.isEmpty,
      missingKeywords: missingKeywords,
      allMustNotContainAbsent: unwantedFound.isEmpty,
      unwantedKeywordsFound: unwantedFound,
      cleanOutput: isClean.passed,
      cleanOutputDetail: isClean.detail,
    );
  }

  _CleanCheck _checkClean(String output) {
    if (output.isEmpty) {
      return const _CleanCheck(passed: false, detail: 'empty output');
    }

    // Check for markdown
    if (output.contains('```') ||
        output.contains('**') ||
        output.contains('##')) {
      return const _CleanCheck(passed: false, detail: 'contains markdown');
    }

    // Check for explanatory preamble
    final lower = output.toLowerCase();
    final preambles = [
      'here is',
      'the corrected',
      'i have fixed',
      'i corrected',
      'below is',
      'note:',
      'explanation:',
      'changes made:',
    ];
    for (final p in preambles) {
      if (lower.startsWith(p)) {
        return _CleanCheck(passed: false, detail: 'starts with preamble: "$p"');
      }
    }

    // Check for excessive length (more than 3x input length likely means explanations)
    // Relaxed — just flag it
    if (output.length > 500) {
      return const _CleanCheck(
        passed: false,
        detail: 'output suspiciously long (>500 chars)',
      );
    }

    return const _CleanCheck(passed: true, detail: null);
  }
}

class _EvalResult {
  final bool wasModified;
  final bool modificationMatch;
  final bool allMustContainFound;
  final List<String> missingKeywords;
  final bool allMustNotContainAbsent;
  final List<String> unwantedKeywordsFound;
  final bool cleanOutput;
  final String? cleanOutputDetail;

  const _EvalResult({
    required this.wasModified,
    required this.modificationMatch,
    required this.allMustContainFound,
    required this.missingKeywords,
    required this.allMustNotContainAbsent,
    required this.unwantedKeywordsFound,
    required this.cleanOutput,
    this.cleanOutputDetail,
  });
}

class _CleanCheck {
  final bool passed;
  final String? detail;
  const _CleanCheck({required this.passed, this.detail});
}
