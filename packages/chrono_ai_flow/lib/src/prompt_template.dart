class ChronoPromptTemplate {
  ChronoPromptTemplate._();

  static const String promptPlaceholderCurrentLocalDateTime =
      '{{current_local_datetime}}';
  static const String promptPlaceholderCurrentLocalDateTimeCompact =
      '{{current_local_datetime_compact}}';
  static const String promptPlaceholderWeekday = '{{weekday}}';
  static const String promptPlaceholderTimezoneOffset =
      '{{timezone_offset}}';
  static const String promptPlaceholderTranscript = '{{transcript}}';

  static const String defaultTemplate = '''
You extract structured information from a voice memo.

The memo may be in ANY language.

Return JSON only. No explanation.

Your tasks:
1. Detect intent: "reminder", "event", or "note".
2. Extract the time/date phrase exactly as it appears in the memo.
3. Translate that time/date phrase into natural English. If already English, copy it.
4. Extract a short title (the task or event, NOT the time part).

Rules:
- NEVER compute or resolve dates. NEVER output ISO timestamps.
- Keep time expressions relative: "tomorrow at 10 am", NOT "2026-03-10T10:00:00".
- Copy the original time phrase exactly from the memo.
- You MUST fill "datetime_expression_english" whenever "datetime_expression_original" is not null.
- If the memo is in English, copy the same English time phrase to both fields.
- If no time/date is mentioned, set both datetime fields to null and intent to "note".
- The title must be short (2-5 words) and in the ORIGINAL language.
- Translate time expressions accurately to natural English. Convert 24-hour to 12-hour format. Translate idioms correctly (e.g. the Swedish "halv 10" means 9:30, not 10:30).
- Intent rules:
  - "event" = scheduled meetings, appointments, bookings (dentist, conference, meeting with someone)
  - "reminder" = personal tasks/actions with a specific time (call someone at 3 pm, buy milk tomorrow)
  - "note" = no time/date mentioned, or just a task without any when (buy bread, remember to call)
- NOT time expressions (never extract these as datetime):
  - Locations: "on the way home", "at work", "at the store"
  - Vague conditions: "when I get home", "after lunch", "later"
  - These make the intent "note", not "reminder"

Examples:

Memo: "Remind me tomorrow at 10 am to buy milk"
{"intent":"reminder","title":"buy milk","datetime_expression_original":"tomorrow at 10 am","datetime_expression_english":"tomorrow at 10 am"}

Memo: "påminn mig imorgon klockan 10 att köpa mjölk"
{"intent":"reminder","title":"köpa mjölk","datetime_expression_original":"imorgon klockan 10","datetime_expression_english":"tomorrow at 10 am"}

Memo: "tandläkare den 15 mars klockan halv 10"
{"intent":"event","title":"tandläkare","datetime_expression_original":"den 15 mars klockan halv 10","datetime_expression_english":"March 15th at 9:30 am"}

Memo: "remember to buy milk"
{"intent":"note","title":"buy milk","datetime_expression_original":null,"datetime_expression_english":null}

Memo: "köp bröd på vägen hem"
{"intent":"note","title":"köp bröd","datetime_expression_original":null,"datetime_expression_english":null}

Memo: "call the plumber this afternoon at 3"
{"intent":"reminder","title":"call the plumber","datetime_expression_original":"this afternoon at 3","datetime_expression_english":"this afternoon at 3 pm"}

Output JSON schema:
{
  "intent": "reminder" | "event" | "note",
  "title": "short task description in original language",
  "datetime_expression_original": "original time phrase" | null,
  "datetime_expression_english": "english translation of time phrase" | null
}

Current datetime: $promptPlaceholderCurrentLocalDateTimeCompact
Timezone: UTC$promptPlaceholderTimezoneOffset

Voice memo:

$promptPlaceholderTranscript

/no_think
JSON:''';

  static String render(
    String template, {
    required String transcript,
    DateTime? now,
  }) {
    final localNow = now ?? DateTime.now();
    final weekday = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][localNow.weekday - 1];
    final iso = localNow.toIso8601String();
    final tzOffset = localNow.timeZoneOffset;
    final tzSign = tzOffset.isNegative ? '-' : '+';
    final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
    final tzMinutes =
        (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final tz = '$tzSign$tzHours:$tzMinutes';
    final compactDateTime =
        '${localNow.year}-${localNow.month.toString().padLeft(2, '0')}-${localNow.day.toString().padLeft(2, '0')} '
        '${localNow.hour.toString().padLeft(2, '0')}:${localNow.minute.toString().padLeft(2, '0')}';

    return template
        .replaceAll(promptPlaceholderCurrentLocalDateTime, iso)
        .replaceAll(promptPlaceholderCurrentLocalDateTimeCompact, compactDateTime)
        .replaceAll(promptPlaceholderWeekday, weekday)
        .replaceAll(promptPlaceholderTimezoneOffset, tz)
        .replaceAll(promptPlaceholderTranscript, transcript);
  }
}
