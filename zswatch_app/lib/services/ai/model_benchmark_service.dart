import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../voice_memo/transcription_engine.dart';
import 'llm_service.dart';

// ---------------------------------------------------------------------------
// State model
// ---------------------------------------------------------------------------

/// Live-updating benchmark run (mirrors the AiProcessingDebugInfo pattern from
/// the voice-memo debug sheet so the UI can reuse the same visual style).
class BenchmarkProgress {
  final String testType; // 'transcription' or 'ai'
  final String modelName;
  final String? promptStrategy;
  final String? rawPrompt;
  final String? parsedJson;
  final String? extractedIntent;
  final String? extractedTitle;
  final String? datetimeExpressionOriginal;
  final String? datetimeExpressionEnglish;
  final String? resolvedDateTime;
  final String? resolverMethod;
  final int attempts;
  final bool retryEnabled;

  /// Current phase: 'loading', 'running', 'transcribing', 'correcting',
  /// 'classifying', 'done', 'error'.
  final String phase;
  final String partialOutput;
  final int tokens;
  final Duration elapsed;
  final double? tokensPerSecond;
  final String? error;

  /// Full raw LLM output preserved across completion. During live streaming
  /// this mirrors [partialOutput]; on completion [partialOutput] is set to a
  /// human-readable summary while [rawOutput] keeps the full model response.
  final String? rawOutput;

  /// Corrected transcription (if the correction pass produced one).
  final String? correctedTranscription;

  /// Metrics from the correction LLM pass (separate from classify metrics).
  final int correctionTokens;
  final Duration correctionElapsed;
  final double? correctionTokensPerSecond;

  /// Reserved for richer benchmark variants that may include a separate
  /// transcription stage.
  final String? transcriptionResult;
  final Duration? transcriptionElapsed;

  const BenchmarkProgress({
    required this.testType,
    required this.modelName,
    this.promptStrategy,
    this.rawPrompt,
    this.parsedJson,
    this.extractedIntent,
    this.extractedTitle,
    this.datetimeExpressionOriginal,
    this.datetimeExpressionEnglish,
    this.resolvedDateTime,
    this.resolverMethod,
    this.attempts = 1,
    this.retryEnabled = false,
    this.phase = 'loading',
    this.partialOutput = '',
    this.tokens = 0,
    this.elapsed = Duration.zero,
    this.tokensPerSecond,
    this.error,
    this.rawOutput,
    this.correctedTranscription,
    this.correctionTokens = 0,
    this.correctionElapsed = Duration.zero,
    this.correctionTokensPerSecond,
    this.transcriptionResult,
    this.transcriptionElapsed,
  });

  bool get isComplete => phase == 'done' || phase == 'error';
  bool get isError => phase == 'error';
}

/// Top-level state for the benchmark section.
class BenchmarkState {
  final bool isRunning;

  /// Which test is currently running ('transcription' or 'ai'), null if idle.
  final String? runningTestType;
  final BenchmarkProgress? current;

  const BenchmarkState({
    this.isRunning = false,
    this.runningTestType,
    this.current,
  });

  BenchmarkState copyWith({
    bool? isRunning,
    String? runningTestType,
    BenchmarkProgress? current,
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
      _emit(BenchmarkProgress(
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

    _emit(BenchmarkProgress(
      testType: 'transcription',
      modelName: info.name,
      phase: 'loading',
      partialOutput: 'Checking model availability…',
    ));

    try {
      // Verify the audio file exists
      if (!File(audioFilePath).existsSync()) {
        _emit(BenchmarkProgress(
          testType: 'transcription',
          modelName: info.name,
          phase: 'error',
          error: 'Audio file not found: $audioFilePath',
        ));
        return;
      }

      final available = await engine.isAvailable();
      if (!available) {
        _emit(BenchmarkProgress(
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
          _emit(BenchmarkProgress(
            testType: 'transcription',
            modelName: info.name,
            phase: 'running',
            partialOutput: statusText,
          ));
        }
      });

      _emit(BenchmarkProgress(
        testType: 'transcription',
        modelName: info.name,
        phase: 'running',
        partialOutput: 'Starting transcription…',
      ));

      final sw = Stopwatch()..start();
      final output = await engine.transcribe(audioFilePath);
      sw.stop();

      if (_abortRequested) {
        _emit(BenchmarkProgress(
          testType: 'transcription',
          modelName: info.name,
          phase: 'done',
          partialOutput: '(aborted)\n${output.isEmpty ? '' : output}',
          elapsed: sw.elapsed,
        ));
        return;
      }

      _emit(BenchmarkProgress(
        testType: 'transcription',
        modelName: info.name,
        phase: 'done',
        partialOutput: output.isEmpty ? '(no speech detected)' : output,
        elapsed: sw.elapsed,
      ));
    } catch (e) {
      _emit(BenchmarkProgress(
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
  }) async {
    _abortRequested = false;
    final modelName = llmService.modelName;

    _emit(BenchmarkProgress(
      testType: 'ai',
      modelName: modelName,
      phase: 'loading',
      partialOutput: 'Loading model…',
    ));

    try {
      final isDownloaded = await llmService.isModelDownloaded();
      if (!isDownloaded) {
        _emit(BenchmarkProgress(
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
        correctTranscription: true,
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
          _emit(BenchmarkProgress(
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
          ));
        },
      );
      sw.stop();

      // Use the raw classify response when available
      final rawResponse =
          result.classifyMetrics?.rawResponse ?? lastRawOutput;

      // Helper to extract correction metrics from result
      BenchmarkProgress buildAiResult({
        required String phase,
        required String partialOutput,
      }) {
        return BenchmarkProgress(
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
      _emit(BenchmarkProgress(
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

  void _emit(BenchmarkProgress progress) {
    _stateSubject.add(BenchmarkState(
      isRunning: !progress.isComplete,
      runningTestType: progress.isComplete ? null : progress.testType,
      current: progress,
    ));
  }
}
