/// Prompt templates for voice memo AI processing.
///
/// Classification/extraction prompts are now shared via the chrono_ai_flow
/// package (ChronoPromptTemplate).  This file retains only the summarise
/// prompt and the supported-language list used by the testbench UI.
class PromptTemplates {
  PromptTemplates._();

  // ---------------------------------------------------------------------------
  // Summarisation prompt
  // ---------------------------------------------------------------------------

  /// Build a summarisation prompt for showing a short preview in the UI.
  ///
  /// [language] – expected language of the transcript.
  /// [transcript] – the raw STT output.
  /// [maxWords] – target summary length.
  static String summarize({
    required String language,
    required String transcript,
    int maxWords = 20,
  }) {
    return '''
You are a concise summarisation assistant.
The following transcript is in $language.
Summarise the transcript in at most $maxWords words, in $language.
Output ONLY the summary text, no extra formatting.

Transcript: "$transcript"
Summary: ''';
  }

  /// All supported languages (displayed in the UI dropdown).
  static const List<String> supportedLanguages = [
    'English',
    'Swedish',
    'German',
    'French',
    'Spanish',
    'Norwegian',
    'Danish',
    'Finnish',
    'Dutch',
    'Italian',
    'Portuguese',
    'Japanese',
    'Chinese',
    'Korean',
  ];
}
