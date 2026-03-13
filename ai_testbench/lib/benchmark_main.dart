import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'screens/testbench_screen.dart';
import 'services/model_benchmark_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = _parseConfig(args);
  final modelDir = config.modelDir;
  final hasModels = Directory(modelDir).existsSync();

  if (!hasModels) {
    stdout.writeln('[BenchmarkRunner] No models directory found at $modelDir');
    exitCode = 1;
    return;
  } else {
    final modelPaths = _discoverModelPaths(modelDir);
    final modelNames = modelPaths
        .map((path) => path.split(Platform.pathSeparator).last)
        .toList();

    if (config.headless) {
      if (modelPaths.isEmpty) {
        stdout.writeln('[BenchmarkRunner] No .gguf files found yet');
        exitCode = 1;
        return;
      }

      await _runHeadlessBenchmark(
        modelPaths: modelPaths,
        outputPath: config.outputPath,
      );
      return;
    }

    stdout.writeln('[BenchmarkRunner] Launching benchmark UI');
    stdout.writeln('[BenchmarkRunner] Models directory: $modelDir');
    if (modelNames.isEmpty) {
      stdout.writeln('[BenchmarkRunner] No .gguf files found yet');
    } else {
      for (final modelName in modelNames) {
        stdout.writeln('  - $modelName');
      }
    }
  }

  runApp(
    BenchmarkApp(
      modelDirectory: modelDir,
    ),
  );
}

class _RunnerConfig {
  const _RunnerConfig({
    required this.headless,
    required this.modelDir,
    required this.outputPath,
  });

  final bool headless;
  final String modelDir;
  final String? outputPath;
}

_RunnerConfig _parseConfig(List<String> args) {
  bool hasFlag(String flag) => args.contains(flag);
  String? readValue(String name) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == name) {
        return args[i + 1];
      }
    }
    return null;
  }

  final modelDir = readValue('--model-dir') ?? Directory('models').absolute.path;
  final outputPath = readValue('--output');
  final headless = hasFlag('--headless') || Platform.environment['AI_BENCH_HEADLESS'] == '1';

  return _RunnerConfig(
    headless: headless,
    modelDir: modelDir,
    outputPath: outputPath,
  );
}

List<String> _discoverModelPaths(String modelDir) {
  return Directory(modelDir)
      .listSync()
      .whereType<File>()
      .map((file) => file.path)
      .where((path) => path.toLowerCase().endsWith('.gguf'))
      .toList()
    ..sort();
}

Future<void> _runHeadlessBenchmark({
  required List<String> modelPaths,
  required String? outputPath,
}) async {
  final service = ModelBenchmarkService();

  stdout.writeln('[BenchmarkRunner] Running headless benchmark');
  stdout.writeln('[BenchmarkRunner] Model count: ${modelPaths.length}');
  for (final modelPath in modelPaths) {
    stdout.writeln('  - ${modelPath.split(Platform.pathSeparator).last}');
  }

  final startedAt = DateTime.now().toUtc();
  final results = await service.runForModels(
    modelPaths,
    onProgress: (progress) {
      final completed = progress.completedRuns;
      final total = progress.totalRuns;
      stdout.writeln(
        '[BenchmarkRunner] Progress $completed/$total '
        'model=${progress.currentModelName} '
        'case=${progress.currentCaseName}',
      );
    },
  );
  final finishedAt = DateTime.now().toUtc();

  final report = <String, dynamic>{
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'modelCount': results.length,
    'caseCount': ModelBenchmarkService.benchmarkCases.length,
    'results': results.map(_serializeModelResult).toList(growable: false),
  };

  final resolvedOutputPath = outputPath ??
      '${Directory.current.path}${Platform.pathSeparator}benchmark_results_${DateTime.now().millisecondsSinceEpoch}.json';
  final outputFile = File(resolvedOutputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));

  stdout.writeln('[BenchmarkRunner] Headless benchmark complete');
  stdout.writeln('[BenchmarkRunner] Results written to ${outputFile.path}');

  final ranked = [...results]
    ..sort((a, b) {
      final passCompare = b.passedCases.compareTo(a.passedCases);
      if (passCompare != 0) return passCompare;
      return b.avgTokensPerSecond.compareTo(a.avgTokensPerSecond);
    });

  for (final result in ranked) {
    stdout.writeln(
      '[BenchmarkRunner] Summary ${result.modelName}: '
      '${result.passedCases}/${result.cases.length} strict passes, '
      '${result.avgTokensPerSecond.toStringAsFixed(1)} tok/s avg, '
      '${result.totalElapsed.inSeconds}s total',
    );
  }
}

Map<String, dynamic> _serializeModelResult(BenchmarkModelResult result) {
  return <String, dynamic>{
    'modelPath': result.modelPath,
    'modelName': result.modelName,
    'passedCases': result.passedCases,
    'totalCases': result.cases.length,
    'avgTokensPerSecond': result.avgTokensPerSecond,
    'totalElapsedMs': result.totalElapsed.inMilliseconds,
    'cases': result.cases.map((caseResult) {
      return <String, dynamic>{
        'caseName': caseResult.caseName,
        'passed': caseResult.passed,
        'validJson': caseResult.validJson,
        'intentMatch': caseResult.intentMatch,
        'timePresenceMatch': caseResult.timePresenceMatch,
        'titleLanguageMatch': caseResult.titleLanguageMatch,
        'titleLanguageDetail': caseResult.titleLanguageDetail,
        'timeResolutionCorrect': caseResult.timeResolutionCorrect,
        'timeResolutionDetail': caseResult.timeResolutionDetail,
        'intent': caseResult.intent,
        'title': caseResult.title,
        'datetimeOriginal': caseResult.datetimeOriginal,
        'datetimeEnglish': caseResult.datetimeEnglish,
        'elapsedMs': caseResult.elapsed.inMilliseconds,
        'tokensPerSecond': caseResult.tokensPerSecond,
        'outputPreview': caseResult.outputPreview,
        'error': caseResult.error,
        'extractedCount': caseResult.extractedCount,
        'expectedCount': caseResult.expectedCount,
        'countMatch': caseResult.countMatch,
        if (caseResult.itemFailures.isNotEmpty)
          'itemFailures': caseResult.itemFailures,
      };
    }).toList(growable: false),
  };
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({
    super.key,
    required this.modelDirectory,
  });

  final String modelDirectory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZSWatch AI Benchmark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      home: TestbenchScreen(
        autoStartBenchmark: true,
        searchDirectories: [modelDirectory],
      ),
    );
  }
}
