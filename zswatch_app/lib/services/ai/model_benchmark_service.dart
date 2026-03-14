import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../voice_memo/transcription_engine.dart';
import 'ai_debug_info.dart';
import 'llm_service.dart';

// ---------------------------------------------------------------------------
// State model
// ---------------------------------------------------------------------------

/// Top-level state for the benchmark section.
class BenchmarkState {
  final bool isRunning;

  /// Which test is currently running ('transcription' or 'ai'), null if idle.
  final String? runningTestType;
  final AiDebugInfo? current;

  const BenchmarkState({
    this.isRunning = false,
    this.runningTestType,
    this.current,
  });

  BenchmarkState copyWith({
    bool? isRunning,
    String? runningTestType,
    AiDebugInfo? current,
  }) =>
      BenchmarkState(
        isRunning: isRunning ?? this.isRunning,
        runningTestType: runningTestType ?? this.runningTestType,
        current: current ?? this.current,
      );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Benchmarks transcription and AI models so users can gauge performance on
/// their hardware.  Streams [BenchmarkState] with live progress that the UI
/// renders in the same style as the voice-memo debug sheet.
class ModelBenchmarkService {
  final _stateSubject = BehaviorSubject<BenchmarkState>.seeded(
    const BenchmarkState(),
  );

  /// Set to `true` when the user requests an abort. Checked between phases
  /// and after async work completes. Note: Whisper and fllama FFI calls are
  /// blocking and cannot be interrupted mid-inference, so the abort takes
  /// effect as soon as the current native call returns.
  bool _abortRequested = false;

  Stream<BenchmarkState> get stateStream => _stateSubject.stream;
  BenchmarkState get currentState => _stateSubject.value;

  /// Request the current benchmark run to abort.
  void abort() {
    if (!currentState.isRunning) return;
    _abortRequested = true;
    final current = currentState.current;
    if (current != null) {
      _emit(AiDebugInfo(
        testType: current.testType,
        modelName: current.modelName,
        phase: 'running',
        partialOutput: 'Aborting after current operation…',
        tokens: current.tokens,
        elapsed: current.elapsed,
        tokensPerSecond: current.tokensPerSecond,
      ));
    }
  }

  // ---- Transcription benchmark ----

  /// Benchmark the selected transcription engine using a real voice recording.
  ///
  /// [audioFilePath] must point to an existing audio file (typically an .ogg
  /// from the voice memos directory).
  Future<void> benchmarkTranscription(
    TranscriptionEngineType type,
    String audioFilePath,
  ) async {
    _abortRequested = false;
    final info = TranscriptionModelCatalog.info(type);
    final engine = createTranscriptionEngine(type);
    StreamSubscription<TranscriptionEngineState>? engineSub;

    _emit(AiDebugInfo(
      testType: 'transcription',
      modelName: info.name,
      phase: 'loading',
      partialOutput: 'Checking model availability…',
    ));

    try {
      // Verify the audio file exists
      if (!File(audioFilePath).existsSync()) {
        _emit(AiDebugInfo(
          testType: 'transcription',
          modelName: info.name,
          phase: 'error',
          error: 'Audio file not found: $audioFilePath',
        ));
        return;
      }

      final available = await engine.isAvailable();
      if (!available) {
        _emit(AiDebugInfo(
          testType: 'transcription',
          modelName: info.name,
          phase: 'error',
          error: 'Model not downloaded – download it first.',
        ));
        return;
      }

      // Listen to engine state for status updates (loading model, transcribing)
      engineSub = engine.stateStream.listen((engineState) {
        final statusText = switch (engineState.status) {
          TranscriptionEngineStatus.downloading =>
            'Downloading model (${(engineState.downloadProgress * 100).toInt()}%)…',
          TranscriptionEngineStatus.transcribing => 'Transcribing audio…',
          TranscriptionEngineStatus.ready => 'Model ready',
          TranscriptionEngineStatus.error =>
            'Engine error: ${engineState.errorMessage ?? "unknown"}',
          _ => 'Initializing…',
        };
        // Only emit running-phase status updates while we're still running
        if (!currentState.current!.isComplete) {
          _emit(AiDebugInfo(
            testType: 'transcription',
            modelName: info.name,
            phase: 'running',
            partialOutput: statusText,
          ));
        }
      });

      _emit(AiDebugInfo(
        testType: 'transcription',
        modelName: info.name,
        phase: 'running',
        partialOutput: 'Starting transcription…',
      ));

      final sw = Stopwatch()..start();
      final output = await engine.transcribe(audioFilePath);
      sw.stop();

      if (_abortRequested) {
        _emit(AiDebugInfo(
          testType: 'transcription',
          modelName: info.name,
          phase: 'done',
          partialOutput: '(aborted)\n${output.isEmpty ? '' : output}',
          elapsed: sw.elapsed,
        ));
        return;
      }

      _emit(AiDebugInfo(
        testType: 'transcription',
        modelName: info.name,
        phase: 'done',
        partialOutput: output.isEmpty ? '(no speech detected)' : output,
        elapsed: sw.elapsed,
      ));
    } catch (e) {
      _emit(AiDebugInfo(
        testType: 'transcription',
        modelName: info.name,
        phase: 'error',
        error: e.toString(),
      ));
    } finally {
      await engineSub?.cancel();
      engine.dispose();
      _stateSubject.add(BenchmarkState(
        isRunning: false,
        runningTestType: null,
        current: currentState.current,
      ));
    }
  }

  // ---- AI benchmark ----

  /// Run a single short transcript through the normal app AI flow to test
  /// speed and behavior. The prompt stays fixed to the app's shared chrono
  /// extraction prompt; only the sample input text is variable.
  Future<void> benchmarkAiModel(
    LlmService llmService, {
    String? testInput,
    bool correctTranscription = false,
  }) async {
    _abortRequested = false;
    final modelName = llmService.modelName;

    _emit(AiDebugInfo(
      testType: 'ai',
      modelName: modelName,
      phase: 'loading',
      partialOutput: 'Loading model…',
    ));

    try {
      final isDownloaded = await llmService.isModelDownloaded();
      if (!isDownloaded) {
        _emit(AiDebugInfo(
          testType: 'ai',
          modelName: modelName,
          phase: 'error',
          error: 'Model not downloaded – download it first.',
        ));
        return;
      }

        final benchmarkInput = (testInput != null && testInput.trim().isNotEmpty)
          ? testInput.trim()
          : 'Remind me to buy groceries tomorrow and call the dentist at 2 PM.';

      debugPrint('[ModelBenchmark] Running AI benchmark with: $modelName');
      final sw = Stopwatch()..start();

      String lastRawOutput = '';
      final result = await llmService.processTranscript(
        benchmarkInput,
        correctTranscription: correctTranscription,
        onProgress: (phase, partial, tokens) {
          lastRawOutput = partial;
          final tps = sw.elapsedMilliseconds > 0
              ? tokens / (sw.elapsedMilliseconds / 1000.0)
              : 0.0;
          // Map LlmService phases to benchmark phases
          final benchPhase = switch (phase) {
            'correcting' => 'correcting',
            'classifying' => 'classifying',
            _ => 'running',
          };
          final mem = llmService.lastInferenceMemoryInfo;
          _emit(AiDebugInfo(
            testType: 'ai',
            modelName: modelName,
            promptStrategy: 'shared-chrono-flow',
            retryEnabled: true,
            phase: benchPhase,
            partialOutput: partial,
            rawOutput: partial,
            tokens: tokens,
            elapsed: sw.elapsed,
            tokensPerSecond: tps,
            deviceMemoryMB: mem?.deviceMB,
            availableMemoryMB: mem?.availableMB,
            modelSizeMB: mem?.modelMB,
            memoryHeadroomMB: mem?.headroomMB,
            inferenceContextSize: mem?.contextSize,
            inferenceGpuLayers: mem?.gpuLayers,
            inferenceMaxTokensCap: mem?.maxTokensCap,
          ));
        },
      );
      sw.stop();

      // Use the raw classify response when available
      final rawResponse =
          result.classifyMetrics?.rawResponse ?? lastRawOutput;

      // Helper to extract correction metrics from result
      final mem = llmService.lastInferenceMemoryInfo;
      AiDebugInfo buildAiResult({
        required String phase,
        required String partialOutput,
      }) {
        return AiDebugInfo(
          testType: 'ai',
          modelName: modelName,
          promptStrategy: result.classifyMetrics?.promptStrategy,
          rawPrompt: result.classifyMetrics?.rawPrompt,
          parsedJson: result.classifyMetrics?.parsedJson,
          extractedIntent: result.extractedIntent,
          extractedTitle: result.extractedTitle,
          datetimeExpressionOriginal: result.datetimeExpressionOriginal,
          datetimeExpressionEnglish: result.datetimeExpressionEnglish,
          resolvedDateTime: result.resolvedDateTime,
          resolverMethod: result.resolverMethod,
          extractedActions: result.actionChronoDetails,
          attempts: result.classifyMetrics?.attempts ?? 1,
          retryEnabled: result.classifyMetrics?.retryEnabled ?? false,
          phase: phase,
          partialOutput: partialOutput,
          rawOutput: rawResponse,
          tokens: result.classifyMetrics?.completionTokens ?? 0,
          elapsed: sw.elapsed,
          tokensPerSecond: result.classifyMetrics?.tokensPerSecond ?? 0.0,
          correctedTranscription: result.correctedTranscription,
          correctionTokens: result.correctionMetrics?.completionTokens ?? 0,
          correctionElapsed: result.correctionMetrics?.wallTime ?? Duration.zero,
          correctionTokensPerSecond: result.correctionMetrics?.tokensPerSecond,
          deviceMemoryMB: mem?.deviceMB,
          availableMemoryMB: mem?.availableMB,
          modelSizeMB: mem?.modelMB,
          memoryHeadroomMB: mem?.headroomMB,
          inferenceContextSize: mem?.contextSize,
          inferenceGpuLayers: mem?.gpuLayers,
          inferenceMaxTokensCap: mem?.maxTokensCap,
        );
      }

      if (_abortRequested) {
        _emit(buildAiResult(phase: 'done', partialOutput: '(aborted)'));
        return;
      }

      _emit(buildAiResult(
        phase: 'done',
        partialOutput:
            'Category: ${result.category}\n'
            'Summary: ${result.summary}\n'
            'Actions: ${result.actions.length}',
      ));
    } catch (e) {
      debugPrint('[ModelBenchmark] AI benchmark error: $e');
      _emit(AiDebugInfo(
        testType: 'ai',
        modelName: modelName,
        phase: 'error',
        error: e.toString(),
      ));
    } finally {
      _stateSubject.add(BenchmarkState(
        isRunning: false,
        runningTestType: null,
        current: currentState.current,
      ));
    }
  }

  /// Reset state to initial (no results).
  void clear() {
    _stateSubject.add(const BenchmarkState());
  }

  void dispose() {
    _stateSubject.close();
  }

  // ---- Helpers ----

  void _emit(AiDebugInfo progress) {
    _stateSubject.add(BenchmarkState(
      isRunning: !progress.isComplete,
      runningTestType: progress.isComplete ? null : progress.testType,
      current: progress,
    ));
  }
}
