import 'models.dart';
import 'parser.dart';
import 'time_expression_resolver.dart';

/// Turns raw model output into the items the app acts on. Shared by the app
/// and the testbench so benchmarks measure what ships.
class ChronoExtractionPipeline {
  ChronoExtractionPipeline({
    this.parser = const ChronoLlmParser(),
    TimeExpressionResolver? resolver,
  }) : resolver = resolver ?? TimeExpressionResolver();

  final ChronoLlmParser parser;
  final TimeExpressionResolver resolver;

  /// Whisper no-speech markers and transcripts without words. These never
  /// reach the model.
  static bool isNoSpeech(String transcript) {
    final lower = transcript.trim().toLowerCase();
    const markers = [
      '[blank_audio]',
      '[no speech]',
      '<no speech>',
      '(no speech)',
      '[silence]',
      '<|nospeech|>',
      '[music]',
      '(music)',
    ];
    return markers.any(lower.contains) ||
        lower.replaceAll(RegExp(r'[\s\p{P}\p{S}]+', unicode: true), '').isEmpty;
  }

  /// Prompt for a second attempt. fllama reuses the whole cached prompt and
  /// only repeats the end token unless the prompt changes.
  static String retryPrompt(String prompt) => '$prompt\n';

  /// Parsed items without empty ones (noise often becomes an empty note).
  /// Timers get their seconds from the English duration phrase; models get
  /// the arithmetic wrong more often than the translation. A reminder or
  /// event without a time is a note and a note with a time is a reminder,
  /// as the prompt defines them.
  List<ChronoLlmExtraction> extract(String raw) => [
    for (final e in parser.parse(raw).extractions)
      if (e.title.isNotEmpty ||
          e.datetimeExpressionEnglish != null ||
          e.durationSeconds != null)
        if (e.intent == 'timer')
          ChronoLlmExtraction(
            intent: e.intent,
            title: e.title,
            datetimeExpressionOriginal: e.datetimeExpressionOriginal,
            datetimeExpressionEnglish: e.datetimeExpressionEnglish,
            durationSeconds:
                (e.datetimeExpressionEnglish == null
                    ? null
                    : resolver.resolveDuration(e.datetimeExpressionEnglish!)) ??
                e.durationSeconds,
          )
        else if ((e.intent == 'reminder' || e.intent == 'event') &&
            e.datetimeExpressionOriginal == null &&
            e.datetimeExpressionEnglish == null)
          ChronoLlmExtraction(intent: 'note', title: e.title)
        else if (e.intent == 'note' && e.datetimeExpressionEnglish != null)
          ChronoLlmExtraction(
            intent: 'reminder',
            title: e.title,
            datetimeExpressionOriginal: e.datetimeExpressionOriginal,
            datetimeExpressionEnglish: e.datetimeExpressionEnglish,
          )
        else
          e,
  ];

  static final _dateWords = RegExp(
    r'\b(today|tonight|tomorrow|yesterday|monday|tuesday|wednesday|thursday|'
    r'friday|saturday|sunday|january|february|march|april|may|june|july|'
    r'august|september|october|november|december|next|week|month|year|'
    r'days?|weekend)\b|\b\d{1,2}(st|nd|rd|th)\b|\d{4}-\d{2}-\d{2}|\bin\s',
  );

  /// When each item happens, or null (notes, timers, unparsable phrases).
  /// An item with only a clock time ("at 3 pm") is on the day of the item
  /// before it, as the prompt asks; models often drop that context.
  List<ResolvedTime?> resolveTimes(
    List<ChronoLlmExtraction> items,
    DateTime now,
  ) {
    final times = <ResolvedTime?>[];
    DateTime? previous;
    for (final item in items) {
      final english = item.datetimeExpressionEnglish;
      ResolvedTime? time;
      if (item.intent != 'timer' && english != null) {
        final carry =
            previous != null &&
            !_dateWords.hasMatch(english.toLowerCase()) &&
            DateTime(previous.year, previous.month, previous.day).isAfter(now);
        time = resolver.resolve(
          english,
          referenceDate: carry
              ? DateTime(previous.year, previous.month, previous.day)
              : now,
          assumeDaytime: item.intent != 'alarm',
        );
      }
      if (time != null) previous = time.dateTime;
      times.add(time);
    }
    return times;
  }

  /// Small models sometimes return a prompt example verbatim. Its title or
  /// time phrase then shares no word with the memo (both are copied from it).
  bool copiedFromExamples(String raw, String transcript) {
    final memo = _words(transcript).toSet();
    bool foreign(String? text) =>
        text != null &&
        _words(text).isNotEmpty &&
        !_words(text).any(memo.contains);
    return parser
        .parse(raw)
        .extractions
        .any((e) => foreign(e.title) || foreign(e.datetimeExpressionOriginal));
  }

  static List<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();
}
