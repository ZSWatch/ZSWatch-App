class ChronoLlmExtraction {
  final String intent;
  final String title;
  final String? datetimeExpressionOriginal;
  final String? datetimeExpressionEnglish;

  const ChronoLlmExtraction({
    required this.intent,
    required this.title,
    this.datetimeExpressionOriginal,
    this.datetimeExpressionEnglish,
  });
}

class ChronoLlmParseResult {
  final String rawOutput;
  final String? parsedJson;
  final ChronoLlmExtraction? extraction;

  const ChronoLlmParseResult({
    required this.rawOutput,
    this.parsedJson,
    this.extraction,
  });
}

class ResolvedTime {
  final DateTime dateTime;
  final String method;

  const ResolvedTime({required this.dateTime, required this.method});
}
