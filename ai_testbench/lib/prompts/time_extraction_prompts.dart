import 'package:chrono_ai_flow/chrono_ai_flow.dart';

enum TimeExtractionPromptVariant { full, medium, short }

class TimeExtractionPrompts {
  TimeExtractionPrompts._();

  static String get fullSystemPrompt => ChronoPromptTemplate.defaultTemplate;
  static String get mediumSystemPrompt => ChronoPromptTemplate.defaultTemplate;
  static String get shortSystemPrompt => ChronoPromptTemplate.defaultTemplate;

  static String systemPromptForVariant(TimeExtractionPromptVariant variant) {
    switch (variant) {
      case TimeExtractionPromptVariant.full:
        return fullSystemPrompt;
      case TimeExtractionPromptVariant.medium:
        return mediumSystemPrompt;
      case TimeExtractionPromptVariant.short:
        return shortSystemPrompt;
    }
  }

  static String get systemPrompt => fullSystemPrompt;

  /// Build the user message with context and transcript.
  ///
  /// [transcript] — the voice memo text.
  /// [now] — current datetime for context (not for LLM to compute with,
  ///   but to help it understand what "today" means if needed).
  /// [timezone] — timezone name (e.g. "Europe/Stockholm").
  static String userMessage({
    required String transcript,
    DateTime? now,
    String? timezone,
    String? transcriptLanguage,
  }) {
    return ChronoPromptTemplate.render(
      ChronoPromptTemplate.defaultTemplate,
      transcript: transcript,
      now: now,
    );
  }

  /// Combine system + user message into a single prompt string
  /// (for models that don't support separate system/user roles).
  static String singlePrompt({
    required String transcript,
    DateTime? now,
    String? timezone,
    String? transcriptLanguage,
  }) {
    return ChronoPromptTemplate.render(
      ChronoPromptTemplate.defaultTemplate,
      transcript: transcript,
      now: now,
    );
  }
}
