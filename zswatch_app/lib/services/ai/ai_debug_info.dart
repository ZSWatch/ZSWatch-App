/// Unified debug info class shared by both the voice-memo AI pipeline and the
/// benchmark harness.  Change field definitions here — both flows use the same
/// data model so the debug sheets stay in sync automatically.
class AiDebugInfo {
  /// 'transcription', 'ai', or 'full-flow'.
  final String testType;
  final String modelName;

  // ---- Prompt / extraction details ----
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

  // ---- Phase / live progress ----

  /// Current phase: 'loading', 'running', 'transcribing', 'correcting',
  /// 'classifying', 'done', 'error'.
  final String phase;

  /// Partial or summary output.  During live streaming this accumulates
  /// token-by-token; on completion it holds a human-readable summary.
  final String partialOutput;
  final int tokens;
  final Duration elapsed;
  final double? tokensPerSecond;
  final String? error;

  /// Full raw LLM output preserved across completion.
  final String? rawOutput;

  // ---- Correction pass ----
  final String? correctedTranscription;
  final int correctionTokens;
  final Duration correctionElapsed;
  final double? correctionTokensPerSecond;

  // ---- Transcription stage ----
  final String? transcriptionResult;
  final Duration? transcriptionElapsed;

  // ---- Voice-memo context ----
  final String? filename;
  final String? summary;
  final String? category;
  final int actionCount;
  final DateTime? timestamp;

  // ---- Memory & inference parameter debug info ----
  final int? deviceMemoryMB;
  final int? availableMemoryMB;
  final int? modelSizeMB;
  final int? memoryHeadroomMB;
  final int? requestedContextSize;
  final int? inferenceContextSize;
  final int? inferenceMaxTokensCap;

  // ---- Per-action chrono extraction details (multi-action support) ----
  final List<ActionChronoDebug> extractedActions;

  const AiDebugInfo({
    this.testType = 'ai',
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
    this.filename,
    this.summary,
    this.category,
    this.actionCount = 0,
    this.timestamp,
    this.deviceMemoryMB,
    this.availableMemoryMB,
    this.modelSizeMB,
    this.memoryHeadroomMB,
    this.requestedContextSize,
    this.inferenceContextSize,
    this.inferenceMaxTokensCap,
    this.extractedActions = const [],
  });

  bool get isComplete => phase == 'done' || phase == 'error';
  bool get isError => phase == 'error';
}

/// Per-action debug data for the chrono extraction / resolution display.
class ActionChronoDebug {
  final String? intent;
  final String? title;
  final String? datetimeExpressionOriginal;
  final String? datetimeExpressionEnglish;
  final String? resolvedDateTime;
  final String? resolverMethod;

  const ActionChronoDebug({
    this.intent,
    this.title,
    this.datetimeExpressionOriginal,
    this.datetimeExpressionEnglish,
    this.resolvedDateTime,
    this.resolverMethod,
  });
}
