/// Headless entry point for time extraction benchmark.
///
/// Runs the time extraction test suite and prints results to stdout.
/// Requires Flutter (for fllama), so it must be compiled as a Flutter app.
///
/// Usage:
///   flutter run -d linux --dart-entrypoint-args '--model Qwen3.5-2B-Q4_K_M.gguf'
/// Or compiled:
///   ./build/linux/x64/release/bundle/ai_testbench --headless-time --model Qwen3.5-2B-Q4_K_M.gguf
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'prompts/time_extraction_prompts.dart';
import 'services/time_extraction_benchmark_service.dart';

/// Run the time extraction benchmark headlessly.
///
/// Call from main() when --headless-time flag is detected.
Future<void> runHeadlessTimeExtraction(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final modelDir = Directory('models').absolute.path;
  String? modelFilter;
  var includeLanguageHint = false;
  var retryInvalidOutput = false;
  var promptVariant = TimeExtractionPromptVariant.full;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--model' && i + 1 < args.length) {
      modelFilter = args[++i];
    } else if (args[i] == '--language-hint') {
      includeLanguageHint = true;
    } else if (args[i] == '--retry-invalid') {
      retryInvalidOutput = true;
    } else if (args[i] == '--prompt-variant' && i + 1 < args.length) {
      final value = args[++i].toLowerCase();
      switch (value) {
        case 'full':
          promptVariant = TimeExtractionPromptVariant.full;
          break;
        case 'medium':
          promptVariant = TimeExtractionPromptVariant.medium;
          break;
        case 'short':
          promptVariant = TimeExtractionPromptVariant.short;
          break;
        default:
          stdout.writeln('ERROR: Unknown prompt variant "$value"');
          exitCode = 1;
          return;
      }
    }
  }

  // Discover models
  final modelsDirectory = Directory(modelDir);
  if (!modelsDirectory.existsSync()) {
    stdout.writeln('ERROR: models/ directory not found at $modelDir');
    exitCode = 1;
    return;
  }

  var modelPaths = modelsDirectory
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.toLowerCase().endsWith('.gguf'))
      .toList()
    ..sort();

  if (modelFilter != null) {
    modelPaths = modelPaths
        .where((p) =>
            p.toLowerCase().contains(modelFilter!.toLowerCase()))
        .toList();
  }

  if (modelPaths.isEmpty) {
    stdout.writeln('ERROR: No matching .gguf models found');
    if (modelFilter != null) {
      stdout.writeln('  Filter: $modelFilter');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('');
  stdout.writeln('╔═══════════════════════════════════════════════════════╗');
  stdout.writeln('║   Time Extraction Benchmark — Headless               ║');
  stdout.writeln('╚═══════════════════════════════════════════════════════╝');
  stdout.writeln('');
  stdout.writeln('Models: ${modelPaths.length}');
  for (final p in modelPaths) {
    stdout.writeln('  - ${p.split(Platform.pathSeparator).last}');
  }
  stdout.writeln('Test cases: ${TimeExtractionBenchmarkService.testCases.length}');
  stdout.writeln('Reference time: ${TimeExtractionBenchmarkService.referenceTime}');
  stdout.writeln('Prompt variant: ${promptVariant.name}');
  stdout.writeln('Language hint: ${includeLanguageHint ? 'enabled' : 'disabled'}');
  stdout.writeln('Retry invalid output: ${retryInvalidOutput ? 'enabled' : 'disabled'}');
  stdout.writeln('');

  final service = TimeExtractionBenchmarkService();
  final results = await service.runForModels(
    modelPaths,
    includeLanguageHint: includeLanguageHint,
    retryInvalidOutput: retryInvalidOutput,
    promptVariant: promptVariant,
    onProgress: (p) {
      stdout.writeln(
        '[${p.modelName}] ${p.completedCases}/${p.totalCases} '
        '${p.currentCaseName}',
      );
    },
  );

  stdout.writeln('');
  stdout.write(TimeExtractionBenchmarkService.formatResults(results));

  // Exit summary
  for (final model in results) {
    stdout.writeln(
      'SUMMARY ${model.modelName}: '
      '${model.passedCount}/${model.cases.length} pass, '
      '${model.partialCount} partial, '
      '${model.failedCount} fail, '
      '${model.avgTokensPerSecond.toStringAsFixed(1)} tok/s, '
      '${(model.totalElapsed.inMilliseconds / 1000).toStringAsFixed(1)}s total',
    );
  }

  exitCode = results.any((m) => m.failedCount > 0) ? 1 : 0;
}
