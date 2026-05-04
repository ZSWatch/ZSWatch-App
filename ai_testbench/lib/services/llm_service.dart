import 'dart:async';
import 'dart:io';

import 'package:fllama/fllama.dart';
import 'package:flutter/foundation.dart';

/// Result of a single inference run.
class InferenceResult {
  final String output;
  final Duration elapsed;
  final int promptTokens;
  final int outputTokens;

  const InferenceResult({
    required this.output,
    required this.elapsed,
    this.promptTokens = 0,
    this.outputTokens = 0,
  });

  double get tokensPerSecond {
    if (elapsed.inMilliseconds == 0) return 0;
    if (outputTokens > 0) {
      return outputTokens / (elapsed.inMilliseconds / 1000);
    }
    // Rough estimate: count whitespace-separated words ≈ tokens
    final estimatedTokens = output.split(RegExp(r'\s+')).length;
    return estimatedTokens / (elapsed.inMilliseconds / 1000);
  }
}

/// Wraps fllama for LLM inference.
///
/// Usage:
/// ```dart
/// final svc = LlmService();
/// svc.setModel('/path/to/model.gguf');
/// final result = await svc.generate(prompt);
/// svc.dispose();
/// ```
class LlmService {
  String? _modelPath;
  int _runningRequestId = -1;
  bool _requestInFlight = false;

  // Configuration
  int nCtx = 4096;
  int nThreads = 2;
  int maxTokens = 512;
  double temperature = 0.3;
  double topP = 1.0;
  double presencePenalty = 2.0;
  int numGpuLayers = 0;

  /// When false, disables thinking/reasoning for models like Qwen3/3.5.
  bool enableThinking = true;

  static void _logFilter(String log) {
    if (log.contains('loaded') ||
        log.contains('error') ||
        log.contains('Error') ||
        log.contains('token') ||
        log.contains('speed') ||
        log.contains('FAILED') ||
        log.contains('Model loaded') ||
        log.contains('Initialized') ||
        log.contains('Backend initialized') ||
        log.contains('Available backends')) {
      debugPrint('[llama.cpp] $log');
    }
  }

  bool get isModelLoaded => _modelPath != null;
  String? get loadedModelPath => _modelPath;

  /// Set the model path. fllama loads on first inference and caches it.
  void setModel(String path) {
    if (!File(path).existsSync()) {
      throw ArgumentError('Model file not found: $path');
    }
    _modelPath = path;
  }

  /// Run inference with the given [prompt] and return the complete result.
  ///
  /// Uses fllamaChat with the OpenAI-compatible API.
  /// The prompt is sent as a user message; for system prompts, provide
  /// [systemPrompt].
  Future<InferenceResult> generate(
    String prompt, {
    String? systemPrompt,
    int? overrideMaxTokens,
  }) async {
    if (_modelPath == null) {
      throw StateError('No model set – call setModel() first.');
    }

    final sw = Stopwatch()..start();
    final completer = Completer<String>();

    final messages = <Message>[
      if (systemPrompt != null) Message(Role.system, systemPrompt),
      Message(Role.user, prompt),
    ];

    final request = OpenAiRequest(
      messages: messages,
      modelPath: _modelPath!,
      maxTokens: overrideMaxTokens ?? maxTokens,
      numGpuLayers: numGpuLayers,
      numThreads: nThreads,
      temperature: temperature,
      topP: topP,
      frequencyPenalty: 0.0,
      presencePenalty: presencePenalty,
      contextSize: nCtx,
      logger: _logFilter,
    );

    _requestInFlight = true;
    _runningRequestId = await fllamaChat(request, (
      String response,
      String responseJson,
      bool done,
    ) {
      if (done && !completer.isCompleted) {
        _requestInFlight = false;
        _runningRequestId = -1;
        completer.complete(response);
      }
    });

    final output = await completer.future;
    sw.stop();
    _requestInFlight = false;
    _runningRequestId = -1;

    // Count output tokens
    int outputTokenCount = 0;
    try {
      outputTokenCount = await fllamaTokenize(
        FllamaTokenizeRequest(input: output, modelPath: _modelPath!),
      );
    } catch (_) {
      // Fallback estimate
      outputTokenCount = output.split(RegExp(r'\s+')).length;
    }

    return InferenceResult(
      output: _stripThinkingTags(output.trim()),
      elapsed: sw.elapsed,
      outputTokens: outputTokenCount,
    );
  }

  /// Strip Qwen3-style <think>…</think> reasoning blocks from output.
  static String _stripThinkingTags(String text) {
    // Remove complete <think>...</think> blocks
    var cleaned = text.replaceAll(
      RegExp(r'<think>.*?</think>', dotAll: true),
      '',
    );
    // Remove unclosed <think> (thinking consumed entire budget)
    cleaned = cleaned.replaceAll(RegExp(r'<think>.*', dotAll: true), '');
    return cleaned.trim();
  }

  /// Stream inference tokens as they are generated (for live preview).
  ///
  /// Yields cumulative responses (each yield is the full response so far).
  Stream<String> generateStream(
    String prompt, {
    String? systemPrompt,
    int? overrideMaxTokens,
  }) {
    if (_modelPath == null) {
      throw StateError('No model set – call setModel() first.');
    }

    final controller = StreamController<String>();

    final messages = <Message>[
      if (systemPrompt != null) Message(Role.system, systemPrompt),
      Message(Role.user, prompt),
    ];

    final request = OpenAiRequest(
      messages: messages,
      modelPath: _modelPath!,
      maxTokens: overrideMaxTokens ?? maxTokens,
      numGpuLayers: numGpuLayers,
      numThreads: nThreads,
      temperature: temperature,
      topP: topP,
      frequencyPenalty: 0.0,
      presencePenalty: presencePenalty,
      contextSize: nCtx,
      logger: _logFilter,
    );

    _requestInFlight = true;
    fllamaChat(request, (String response, String responseJson, bool done) {
      debugPrint('[LlmService] stream cb: done=$done, len=${response.length}');
      if (!controller.isClosed) {
        controller.add(response);
        if (done) {
          _requestInFlight = false;
          _runningRequestId = -1;
          controller.close();
        }
      }
    }).then((id) {
      _runningRequestId = id;
    });

    return controller.stream;
  }

  /// Cancel any running inference.
  void cancelInference() {
    if (_requestInFlight && _runningRequestId >= 0) {
      fllamaCancelInference(_runningRequestId);
      _runningRequestId = -1;
      _requestInFlight = false;
    }
  }

  void dispose() {
    cancelInference();
    _modelPath = null;
  }
}
