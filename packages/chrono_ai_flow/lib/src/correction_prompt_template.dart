/// Shared prompt template for speech-to-text correction.
///
/// Used by both the main app (`llm_service.dart`) and the AI testbench
/// (`correction_benchmark_service.dart`). Edit this file to tune the
/// correction prompt — changes apply everywhere automatically.
class CorrectionPromptTemplate {
  CorrectionPromptTemplate._();

  static const String promptPlaceholderTranscript = '{{transcript}}';

  static const String defaultTemplate =
      '''
Fix speech-to-text errors. Output ONLY the corrected text.

IMPORTANT: NEVER translate. The output language MUST be the same as the input language. Swedish input → Swedish output. German input → German output.

Fix these common STT errors:
- Homophones: "there"/"their", "weak"/"week", "by"/"buy"
- Stuttering/repeats: "I I need" → "I need", "och och" → "och"
- Filler words: remove um, uh, eh, like, you know, alltså, liksom, also
- Missing punctuation: add periods, commas, capitalize first word
- Missing diacritics: "mote" → "möte", "fur" → "für", "pa" → "på"
- Split/joined words: "i morgan" → "imorgon", "can not" → "cannot"

If already correct, repeat the input verbatim. Do NOT add explanations. Output only the corrected text.

Input: "remind me to uh call the the dentist and dont forget to by milk"
Output: "Remind me to call the dentist and don't forget to buy milk."

Input: "vi har mote med kunden pa torsdag klockan tva"
Output: "Vi har möte med kunden på torsdag klockan två."

Input: "also ich äh muss muss den Bericht fertig machen"
Output: "Ich muss den Bericht fertig machen."

Input: "$promptPlaceholderTranscript"
/no_think
Output:''';

  /// Render the correction prompt with the given [transcript].
  static String render(String template, {required String transcript}) {
    return template.replaceAll(promptPlaceholderTranscript, transcript);
  }

  /// Estimate a reasonable maxTokens for the correction output.
  ///
  /// The corrected text is always roughly the same length as (or shorter than)
  /// the input transcript. We use ~3.5 chars/token (conservative for
  /// mixed-language text with diacritics) and add a fixed margin for
  /// punctuation/capitalization changes.
  static int estimateMaxTokens(String transcript, {int margin = 32}) {
    final estimated = (transcript.length / 3.5).ceil() + margin;
    // Clamp to a sane range: at least 64, at most 512.
    return estimated.clamp(64, 512);
  }
}
