class ChronoLlmExtraction {
  final String intent;
  final String title;
  final String? datetimeExpressionOriginal;
  final String? datetimeExpressionEnglish;

  /// Duration in seconds for timer intents. Null for all other intents.
  final int? durationSeconds;

  const ChronoLlmExtraction({
    required this.intent,
    required this.title,
    this.datetimeExpressionOriginal,
    this.datetimeExpressionEnglish,
    this.durationSeconds,
  });
}

class ChronoLlmParseResult {
  final String rawOutput;
  final String? parsedJson;
  final ChronoLlmExtraction? extraction;

  /// All extractions when the model returns a JSON array.
  /// For single-object output, this contains just the one [extraction].
  final List<ChronoLlmExtraction> extractions;

  const ChronoLlmParseResult({
    required this.rawOutput,
    this.parsedJson,
    this.extraction,
    this.extractions = const [],
  });
}

class ResolvedTime {
  final DateTime dateTime;
  final String method;

  const ResolvedTime({required this.dateTime, required this.method});
}
