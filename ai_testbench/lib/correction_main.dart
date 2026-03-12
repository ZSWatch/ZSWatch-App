import 'dart:convert';
import 'dart:io';

import 'services/correction_benchmark_service.dart';

/// Headless entry point for correction benchmark.
///
/// Usage:
///   AI_BENCH_HEADLESS=1 ./build/linux/x64/release/bundle/ai_testbench \
///       --headless-correction --model-dir /tmp/bench_single_model \
///       --output /tmp/correction_bench.json
///
/// Or interactively:
///   ./build/linux/x64/release/bundle/ai_testbench \
///       --headless-correction --model Qwen3.5-2B-Q4_K_M.gguf
Future<void> runHeadlessCorrectionBenchmark(List<String> args) async {
  String? readValue(String name) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == name) return args[i + 1];
    }
    return null;
  }

  final modelDir = readValue('--model-dir') ?? Directory('models').absolute.path;
  final outputPath = readValue('--output');

  final modelPaths = Directory(modelDir)
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.toLowerCase().endsWith('.gguf'))
      .toList()
    ..sort();

  if (modelPaths.isEmpty) {
    stdout.writeln('[CorrectionBench] No .gguf files found in $modelDir');
    exitCode = 1;
    return;
  }

  stdout.writeln('╔═══════════════════════════════════════════════════════╗');
  stdout.writeln('║   Correction Benchmark — Headless                    ║');
  stdout.writeln('╚═══════════════════════════════════════════════════════╝');
  stdout.writeln('[CorrectionBench] Models: ${modelPaths.length}');
  for (final p in modelPaths) {
    stdout.writeln('  - ${p.split(Platform.pathSeparator).last}');
  }
  stdout.writeln('[CorrectionBench] Cases: ${CorrectionBenchmarkService.benchmarkCases.length}');

  final service = CorrectionBenchmarkService();
  final startedAt = DateTime.now().toUtc();

  final results = await service.runForModels(
    modelPaths,
    onProgress: (p) {
      stdout.writeln(
        '[CorrectionBench] ${p.completedRuns}/${p.totalRuns} '
        'model=${p.currentModelName} case=${p.currentCaseName}',
      );
    },
  );

  final finishedAt = DateTime.now().toUtc();

  // ── Print summary ───────────────────────────────────────────────────

  stdout.writeln('');
  stdout.writeln('${'═' * 70}');
  stdout.writeln('  CORRECTION BENCHMARK RESULTS');
  stdout.writeln('${'═' * 70}');

  for (final model in results) {
    stdout.writeln('');
    stdout.writeln('┌── ${model.modelName} ── '
        '${model.passedCases}/${model.cases.length} passed ──┐');

    for (final c in model.cases) {
      final tag = c.passed ? 'PASS' : 'FAIL';
      final reasons = <String>[];

      if (!c.modificationMatch) {
        reasons.add(c.modificationExpected
            ? 'NOT_MODIFIED'
            : 'UNEXPECTED_MODIFICATION');
      }
      if (!c.allMustContainFound) {
        reasons.add('MISSING[${c.missingKeywords.join(",")}]');
      }
      if (!c.allMustNotContainAbsent) {
        reasons.add('UNWANTED[${c.unwantedKeywordsFound.join(",")}]');
      }
      if (!c.cleanOutput) {
        reasons.add('DIRTY(${c.cleanOutputDetail})');
      }
      if (c.error != null) {
        reasons.add('ERROR');
      }

      final reasonStr = reasons.isEmpty ? '' : ' [${reasons.join(", ")}]';
      stdout.writeln('│ $tag ${c.caseName}$reasonStr');

      // Always print input vs output for failed cases
      if (!c.passed) {
        stdout.writeln('│   input:    "${c.input}"');
        stdout.writeln('│   expected: "${c.expectedOutput}"');
        stdout.writeln('│   got:      "${c.actualOutput}"');
      }
    }
    stdout.writeln('└${'─' * 68}┘');
  }

  // ── JSON output ─────────────────────────────────────────────────────

  if (outputPath != null) {
    final report = <String, dynamic>{
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'modelCount': results.length,
      'caseCount': CorrectionBenchmarkService.benchmarkCases.length,
      'results': results.map((r) => <String, dynamic>{
        'modelPath': r.modelPath,
        'modelName': r.modelName,
        'passedCases': r.passedCases,
        'totalCases': r.cases.length,
        'avgTokensPerSecond': r.avgTokensPerSecond,
        'totalElapsedMs': r.totalElapsed.inMilliseconds,
        'cases': r.cases.map((c) => <String, dynamic>{
          'caseName': c.caseName,
          'passed': c.passed,
          'wasModified': c.wasModified,
          'modificationExpected': c.modificationExpected,
          'modificationMatch': c.modificationMatch,
          'allMustContainFound': c.allMustContainFound,
          'missingKeywords': c.missingKeywords,
          'allMustNotContainAbsent': c.allMustNotContainAbsent,
          'unwantedKeywordsFound': c.unwantedKeywordsFound,
          'cleanOutput': c.cleanOutput,
          'cleanOutputDetail': c.cleanOutputDetail,
          'input': c.input,
          'expectedOutput': c.expectedOutput,
          'actualOutput': c.actualOutput,
          'elapsedMs': c.elapsed.inMilliseconds,
          'tokensPerSecond': c.tokensPerSecond,
          'error': c.error,
        }).toList(growable: false),
      }).toList(growable: false),
    };

    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln('\n[CorrectionBench] JSON results: ${file.path}');
  }

  // ── Ranked summary ──────────────────────────────────────────────────

  final ranked = [...results]
    ..sort((a, b) => b.passedCases.compareTo(a.passedCases));
  stdout.writeln('');
  for (final r in ranked) {
    stdout.writeln(
      '[CorrectionBench] ${r.modelName}: '
      '${r.passedCases}/${r.cases.length} passed, '
      '${r.avgTokensPerSecond.toStringAsFixed(1)} tok/s, '
      '${r.totalElapsed.inSeconds}s total',
    );
  }
}
