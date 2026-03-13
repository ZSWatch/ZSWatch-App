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

A memo may contain ONE or MULTIPLE items. Return a JSON array with one object per item.

The memo may be in ANY language.

Return JSON only. No explanation.

Your tasks per item:
1. Detect intent: "reminder", "event", or "note".
2. Extract the time/date phrase exactly as it appears in the memo.
3. Translate that time/date phrase into natural English. If already English, copy it.
4. Extract a short title (the task or event, NOT the time part).

Rules:
- ALWAYS return a JSON array, even for a single item.
- Each distinct task, event, or note in the memo becomes its own object in the array.
- Multi-item date context: when a preceding item establishes a date (e.g. "tomorrow", "on Friday"), carry it into subsequent items that only mention a time. Example: if item 1 says "tomorrow at 8 am" and item 2 says "at 3 pm", translate item 2 as "tomorrow at 3 pm".
- The title MUST stay in the SAME language as the voice memo. DO NOT translate the title to English.
- NEVER compute or resolve dates. NEVER output ISO timestamps.
- Keep time expressions relative: "tomorrow at 10 am", NOT "2026-03-10T10:00:00".
- Copy the original time phrase exactly from the memo.
- You MUST fill "datetime_expression_english" whenever "datetime_expression_original" is not null.
- If the memo is in English, copy the same English time phrase to both fields.
- If no time/date is mentioned for an item, set both datetime fields to null and intent to "note".
- Title must be short (2-5 words). Only translate datetime fields to English, NEVER the title.
- Translate time expressions accurately to natural English. Convert 24-hour to 12-hour format. Translate idioms correctly (e.g. the Swedish "halv 10" means 9:30, not 10:30). Use PM for afternoon/evening context (e.g. picking up children, dinner, after work → PM, not AM).
- Translate weekday references directly. Do NOT add "next" unless the original explicitly says "next" or equivalent ("nächsten", "nästa", "prochain"). When the original DOES contain "next" or its equivalent, you MUST preserve "next" in the English translation. E.g. "am Freitag" → "on Friday", "på torsdag" → "on Thursday", "nächsten Montag" → "next Monday", "by next Friday" → "by next Friday".
- Intent rules:
  - "event" = scheduled meetings, appointments, social plans, bookings (dentist, conference, meeting with someone, lunch with a person)
  - "reminder" = personal tasks/actions with a specific time that are NOT meetings/appointments (call someone at 3 pm, pick up package at 5)
  - "note" = no time/date mentioned at all (buy bread, good idea about sensors)
  - When a task has NO time but appears alongside timed tasks, it is a "note" — NOT a "reminder"
- Deadlines ARE time expressions: "by Friday", "bis Freitag", "senast fredag", "until Monday" → extract the deadline date/time.
- NOT time expressions (never extract these as datetime):
  - Locations: "on the way home", "at work", "at the store"
  - Vague conditions: "when I get home", "after lunch", "later"
  - These make the intent "note", not "reminder"

Examples:

Memo: "Remind me tomorrow at 10 am to buy milk"
[{"intent":"reminder","title":"buy milk","datetime_expression_original":"tomorrow at 10 am","datetime_expression_english":"tomorrow at 10 am"}]

Memo: "Tomorrow at 5 pm pick up the dog and then at 9 turn off all lights"
[{"intent":"reminder","title":"pick up the dog","datetime_expression_original":"tomorrow at 5 pm","datetime_expression_english":"tomorrow at 5 pm"},{"intent":"reminder","title":"turn off all lights","datetime_expression_original":"at 9","datetime_expression_english":"tomorrow at 9 pm"}]

Memo: "påminn mig imorgon klockan 10 att köpa mjölk"
[{"intent":"reminder","title":"köpa mjölk","datetime_expression_original":"imorgon klockan 10","datetime_expression_english":"tomorrow at 10 am"}]

Memo: "tandläkare den 15 mars klockan halv 10 och sen handla mat på vägen hem"
[{"intent":"event","title":"tandläkare","datetime_expression_original":"den 15 mars klockan halv 10","datetime_expression_english":"March 15th at 9:30 am"},{"intent":"note","title":"handla mat","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "remember to buy milk"
[{"intent":"note","title":"buy milk","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "köp bröd på vägen hem"
[{"intent":"note","title":"köp bröd","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "call the plumber this afternoon at 3"
[{"intent":"reminder","title":"call the plumber","datetime_expression_original":"this afternoon at 3","datetime_expression_english":"this afternoon at 3 pm"}]

Memo: "Meeting with Sarah on Monday at 10 am and lunch with the team on Wednesday at noon"
[{"intent":"event","title":"meeting with Sarah","datetime_expression_original":"on Monday at 10 am","datetime_expression_english":"on Monday at 10 am"},{"intent":"event","title":"lunch with the team","datetime_expression_original":"on Wednesday at noon","datetime_expression_english":"on Wednesday at 12 pm"}]

Memo: "Tomorrow at 3 pm call the electrician and also buy new light bulbs"
[{"intent":"reminder","title":"call the electrician","datetime_expression_original":"tomorrow at 3 pm","datetime_expression_english":"tomorrow at 3 pm"},{"intent":"note","title":"buy new light bulbs","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Arzttermin am Donnerstag um 9 Uhr und Zahnarzt am Freitag um 14 Uhr"
[{"intent":"event","title":"Arzttermin","datetime_expression_original":"am Donnerstag um 9 Uhr","datetime_expression_english":"Thursday at 9 am"},{"intent":"event","title":"Zahnarzt","datetime_expression_original":"am Freitag um 14 Uhr","datetime_expression_english":"Friday at 2 pm"}]

Memo: "Den Bericht bis Freitag um 17 Uhr an den Chef schicken"
[{"intent":"reminder","title":"Bericht an Chef schicken","datetime_expression_original":"bis Freitag um 17 Uhr","datetime_expression_english":"on Friday at 5 pm"}]

WRONG — never translate the title, not even for notes:
Memo: "möte med projektgruppen på torsdag klockan 14"
WRONG: [{"intent":"event","title":"meeting with project group",...}]
RIGHT: [{"intent":"event","title":"möte projektgruppen","datetime_expression_original":"på torsdag klockan 14","datetime_expression_english":"Thursday at 2 pm"}]

Output JSON schema (always an array):
[
  {
    "intent": "reminder" | "event" | "note",
    "title": "short task description in original language",
    "datetime_expression_original": "original time phrase" | null,
    "datetime_expression_english": "english translation of time phrase" | null
  }
]

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
