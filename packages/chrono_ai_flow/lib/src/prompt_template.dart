class ChronoPromptTemplate {
  ChronoPromptTemplate._();

  static const String promptPlaceholderCurrentLocalDateTime =
      '{{current_local_datetime}}';
  static const String promptPlaceholderCurrentLocalDateTimeCompact =
      '{{current_local_datetime_compact}}';
  static const String promptPlaceholderWeekday = '{{weekday}}';
  static const String promptPlaceholderTimezoneOffset = '{{timezone_offset}}';
  static const String promptPlaceholderTranscript = '{{transcript}}';

  static const String defaultTemplate =
      '''
You extract structured information from a voice memo.

A memo may contain ONE or MULTIPLE items. Return a JSON array with one object per item.

The memo may be in ANY language.

Return JSON only. Output MUST start with '[' and end with ']'. No text before or after.

If the memo is noise, gibberish, a silence marker, or contains no meaningful words, return an empty array: []

Your tasks per item:
1. Detect intent: "reminder", "event", or "note".
2. Extract the time/date phrase exactly as it appears in the memo.
3. Translate that time/date phrase into natural English. If already English, copy it.
4. Extract a short title (the task or event, NOT the time part).

IMPORTANT — item splitting:
- ALWAYS return a JSON array, even for a single item.
- NEVER drop items. Every distinct action in the memo MUST appear as a separate object.
- Connectors that introduce a NEW item: "and", "and then", "also", "och", "och sen", "sen", "und", commas between clauses, sentence boundaries.
- A single idea with elaboration/details stays as ONE item.
- Comma-separated lists (shopping items, ingredients, supplies) are ONE item.

IMPORTANT — intent classification:
- "event" = meetings, appointments, social plans, bookings, standups — things you ATTEND with others or at a place (dentist, fika with someone, team standup, conference, lunch with a person)
- "reminder" = personal tasks/actions WITH a specific time — things you DO alone (call someone at 3 pm, pick up package at 5, go to gym at 8, take medicine at 8)
- "note" = NO time/date mentioned — ideas, shopping lists, tasks without a deadline (buy bread, good idea about sensors, prototype a feature)
- A task with NO time appearing alongside timed tasks is still a "note"

Rules:
- Multi-item date context: if a later item only mentions a time (e.g. "at 3 pm"), reuse the most recent date from a previous item. Example: "tomorrow at 8 am ... at 3 pm" → item 2 is "tomorrow at 3 pm".
- Copy title words directly from the memo. Never translate the title. Keep titles short (2-5 words).
- Title must NOT contain time or date words.
- Do not resolve relative dates to absolute dates or ISO timestamps. Keep expressions relative: "tomorrow at 10 am", NOT "2026-03-10T10:00:00".
- Copy the original time phrase exactly. Fill "datetime_expression_english" whenever "datetime_expression_original" is not null.
- If the memo is in English, copy the same phrase to both datetime fields.
- If no time/date for an item, set both datetime fields to null.
- Translate time expressions to natural English. Convert 24-hour to 12-hour. Use PM for afternoon/evening context.
- Do NOT add "next" to weekday translations unless the original explicitly says "next" / "nästa" / "nächsten".
- Deadlines ARE time expressions: "by Friday", "senast fredag", "bis Freitag" → extract them.
- NOT time expressions: locations ("at the store"), vague conditions ("when I get home", "after lunch"), words that look like time but aren't ("boka tid" = book appointment)

Output JSON schema (always an array):
[
  {
    "intent": "reminder" | "event" | "note",
    "title": "short task description in original language",
    "datetime_expression_original": "original time phrase" | null,
    "datetime_expression_english": "english translation of time phrase" | null
  }
]

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

Memo: "Boka tid hos frisören"
[{"intent":"note","title":"boka tid hos frisören","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Fika med Anna imorgon klockan 10 och sen lämna in paketet på posten"
[{"intent":"event","title":"fika med Anna","datetime_expression_original":"imorgon klockan 10","datetime_expression_english":"tomorrow at 10 am"},{"intent":"note","title":"lämna in paketet","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Vi behöver fixa buggen och sen refaktorera koden"
[{"intent":"note","title":"fixa buggen","datetime_expression_original":null,"datetime_expression_english":null},{"intent":"note","title":"refaktorera koden","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Bilservice på tisdag klockan 8"
[{"intent":"event","title":"bilservice","datetime_expression_original":"på tisdag klockan 8","datetime_expression_english":"on Tuesday at 8 am"}]

Memo: "Hämta barnen imorgon klockan halv 5"
[{"intent":"reminder","title":"hämta barnen","datetime_expression_original":"imorgon klockan halv 5","datetime_expression_english":"tomorrow at 4:30 pm"}]

Memo: "Ring tandläkaren imorgon klockan 9, köp presenter till kalaset och möte med chefen på fredag klockan 14"
[{"intent":"reminder","title":"ring tandläkaren","datetime_expression_original":"imorgon klockan 9","datetime_expression_english":"tomorrow at 9 am"},{"intent":"note","title":"köp presenter","datetime_expression_original":null,"datetime_expression_english":null},{"intent":"event","title":"möte med chefen","datetime_expression_original":"på fredag klockan 14","datetime_expression_english":"on Friday at 2 pm"}]

Memo: "Team standup tomorrow at 9:15 and I should prototype the new notification system"
[{"intent":"event","title":"team standup","datetime_expression_original":"tomorrow at 9:15","datetime_expression_english":"tomorrow at 9:15 am"},{"intent":"note","title":"prototype notification system","datetime_expression_original":null,"datetime_expression_english":null}]

WRONG — never translate the title:
Memo: "Bra idé om att lägga till stegräknare i klockan"
WRONG: [{"intent":"note","title":"add step counter to watch",...}]
RIGHT: [{"intent":"note","title":"stegräknare i klockan","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "[NO SPEECH DETECTED]"
[]

Current datetime: $promptPlaceholderCurrentLocalDateTimeCompact
Timezone: UTC$promptPlaceholderTimezoneOffset

Voice memo:

$promptPlaceholderTranscript

/no_think
JSON:''';

  /// Compact prompt with fewer examples for low-memory devices (nCtx < 4096).
  /// Same rules, 5 examples instead of 18.
  static const String compactTemplate =
      '''
You extract structured information from a voice memo.

A memo may contain ONE or MULTIPLE items. Return a JSON array with one object per item.

The memo may be in ANY language.

Return JSON only. Output MUST start with '[' and end with ']'. No text before or after.

If the memo is noise, gibberish, a silence marker, or contains no meaningful words, return an empty array: []

Your tasks per item:
1. Detect intent: "reminder", "event", or "note".
2. Extract the time/date phrase exactly as it appears in the memo.
3. Translate that time/date phrase into natural English. If already English, copy it.
4. Extract a short title (the task or event, NOT the time part).

IMPORTANT — item splitting:
- ALWAYS return a JSON array, even for a single item.
- NEVER drop items. Every distinct action in the memo MUST appear as a separate object.
- Connectors that introduce a NEW item: "and", "and then", "also", "och", "och sen", "sen", "und", commas between clauses, sentence boundaries.
- A single idea with elaboration/details stays as ONE item.
- Comma-separated lists (shopping items, ingredients, supplies) are ONE item.

IMPORTANT — intent classification:
- "event" = meetings, appointments, social plans, bookings, standups — things you ATTEND with others or at a place
- "reminder" = personal tasks/actions WITH a specific time — things you DO alone
- "note" = NO time/date mentioned — ideas, shopping lists, tasks without a deadline
- A task with NO time appearing alongside timed tasks is still a "note"

Rules:
- Multi-item date context: if a later item only mentions a time (e.g. "at 3 pm"), reuse the most recent date from a previous item.
- Copy title words directly from the memo. Never translate the title. Keep titles short (2-5 words).
- Title must NOT contain time or date words.
- Keep expressions relative: "tomorrow at 10 am", NOT "2026-03-10T10:00:00".
- Copy the original time phrase exactly. Fill "datetime_expression_english" whenever "datetime_expression_original" is not null.
- If the memo is in English, copy the same phrase to both datetime fields.
- If no time/date for an item, set both datetime fields to null.
- Translate time expressions to natural English. Convert 24-hour to 12-hour. Use PM for afternoon/evening context.
- Do NOT add "next" to weekday translations unless the original explicitly says "next" / "nästa" / "nächsten".
- Deadlines ARE time expressions: "by Friday", "senast fredag", "bis Freitag" → extract them.
- NOT time expressions: locations ("at the store"), vague conditions ("when I get home", "after lunch"), words that look like time but aren't ("boka tid" = book appointment)

Output JSON schema (always an array):
[
  {
    "intent": "reminder" | "event" | "note",
    "title": "short task description in original language",
    "datetime_expression_original": "original time phrase" | null,
    "datetime_expression_english": "english translation of time phrase" | null
  }
]

Examples:

Memo: "Remind me tomorrow at 10 am to buy milk"
[{"intent":"reminder","title":"buy milk","datetime_expression_original":"tomorrow at 10 am","datetime_expression_english":"tomorrow at 10 am"}]

Memo: "tandläkare den 15 mars klockan halv 10 och sen handla mat på vägen hem"
[{"intent":"event","title":"tandläkare","datetime_expression_original":"den 15 mars klockan halv 10","datetime_expression_english":"March 15th at 9:30 am"},{"intent":"note","title":"handla mat","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Tomorrow at 3 pm call the electrician and also buy new light bulbs"
[{"intent":"reminder","title":"call the electrician","datetime_expression_original":"tomorrow at 3 pm","datetime_expression_english":"tomorrow at 3 pm"},{"intent":"note","title":"buy new light bulbs","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "Ring tandläkaren imorgon klockan 9, köp presenter till kalaset och möte med chefen på fredag klockan 14"
[{"intent":"reminder","title":"ring tandläkaren","datetime_expression_original":"imorgon klockan 9","datetime_expression_english":"tomorrow at 9 am"},{"intent":"note","title":"köp presenter","datetime_expression_original":null,"datetime_expression_english":null},{"intent":"event","title":"möte med chefen","datetime_expression_original":"på fredag klockan 14","datetime_expression_english":"on Friday at 2 pm"}]

Memo: "köp bröd på vägen hem"
[{"intent":"note","title":"köp bröd","datetime_expression_original":null,"datetime_expression_english":null}]

Memo: "[NO SPEECH DETECTED]"
[]

Current datetime: $promptPlaceholderCurrentLocalDateTimeCompact
Timezone: UTC$promptPlaceholderTimezoneOffset

Voice memo:

$promptPlaceholderTranscript

/no_think
JSON:''';

  /// Lightweight pre-classifier prompt. Determines if the input is a
  /// timer/alarm or a general voice memo. Output is a single JSON object
  /// with a "route" field. Designed to be as small as possible for speed.
  static const String routerTemplate =
      '''
Classify this voice memo. The memo may be in ANY language.

Output ONLY a JSON object. No other text.

Rules:
- "none" = NOT a real voice memo. Noise, gibberish, silence markers, music symbols, filler sounds, or no meaningful words.
- "timer_alarm" = setting a timer, countdown, alarm, or wake-up. No task or action — just ring after a duration or at a time.
- "voice_memo" = anything with meaningful content: reminders, events, notes, ideas, tasks.
- IMPORTANT: if the memo mentions an ACTION to perform at a time ("remind me to X", "call Y at 3 PM"), that is "voice_memo", NOT "timer_alarm".
- If the memo contains BOTH a timer/alarm AND other items, output "mixed".

{"route": "none" | "timer_alarm" | "voice_memo" | "mixed"}

Examples:

Memo: "<|nospeech|>"
{"route":"none"}

Memo: ", , ,"
{"route":"none"}

Memo: "uh eh um"
{"route":"none"}

Memo: "Set a timer for 5 minutes"
{"route":"timer_alarm"}

Memo: "Remind me to call the dentist at 3 pm"
{"route":"voice_memo"}

Memo: "Buy milk"
{"route":"voice_memo"}

Memo: "$promptPlaceholderTranscript"

/no_think
JSON:''';

  /// Dedicated timer/alarm extraction prompt. Used after the router
  /// classifies input as "timer_alarm". Smaller and more focused than
  /// the full 5-intent prompt — no event/reminder/note rules to confuse the model.
  static const String timerAlarmTemplate =
      '''
Extract timer or alarm details from this voice memo. The memo may be in ANY language.

Return a JSON array. Output MUST start with '[' and end with ']'. No text before or after.

If the memo is noise, gibberish, a silence marker, or contains no meaningful words, return an empty array: []

Rules:
- "timer" = countdown for a duration. Extract duration as integer seconds in "duration_seconds". Set datetime fields to null.
- "alarm" = ring at a specific clock time. Extract time into datetime fields. Set duration_seconds to null.
- Keep title in the original language. If no label, set title to empty string.
- Copy the original time phrase exactly into datetime_expression_original.
- Translate to English in datetime_expression_english. Convert 24h to 12h format.
- For timers: convert all durations to total seconds (e.g. "1.5 hours" = 5400).

Output schema:
[{"intent": "timer" | "alarm", "title": "label", "datetime_expression_original": "..." | null, "datetime_expression_english": "..." | null, "duration_seconds": 480 | null}]

Examples:

Memo: "Set a timer for 8 minutes"
[{"intent":"timer","title":"","datetime_expression_original":null,"datetime_expression_english":null,"duration_seconds":480}]

Memo: "Timer for 5 minutes for pasta"
[{"intent":"timer","title":"pasta","datetime_expression_original":null,"datetime_expression_english":null,"duration_seconds":300}]

Memo: "Set an alarm for 7:30 AM"
[{"intent":"alarm","title":"","datetime_expression_original":"7:30 AM","datetime_expression_english":"7:30 AM","duration_seconds":null}]

Memo: "Sätt en timer på 10 minuter"
[{"intent":"timer","title":"","datetime_expression_original":null,"datetime_expression_english":null,"duration_seconds":600}]

Memo: "Ställ ett alarm klockan 7"
[{"intent":"alarm","title":"","datetime_expression_original":"klockan 7","datetime_expression_english":"at 7 AM","duration_seconds":null}]

Memo: "Wecker auf 7 Uhr stellen"
[{"intent":"alarm","title":"","datetime_expression_original":"7 Uhr","datetime_expression_english":"at 7 AM","duration_seconds":null}]

Memo: "Set a timer for one and a half hours"
[{"intent":"timer","title":"","datetime_expression_original":null,"datetime_expression_english":null,"duration_seconds":5400}]

Memo: "$promptPlaceholderTranscript"

/no_think
JSON:''';

  /// Returns the appropriate template for the given context size.
  static String templateForContextSize(int nCtx) {
    // Always use compactTemplate (5 examples, ~1030 tokens) — the full
    // template with 19 examples produces ~2150 tokens which dominates
    // inference time due to O(n²) attention.  The compact template is
    // sufficient for structured extraction quality.
    return compactTemplate;
  }

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
    final tzMinutes = (tzOffset.inMinutes.abs() % 60).toString().padLeft(
      2,
      '0',
    );
    final tz = '$tzSign$tzHours:$tzMinutes';
    final compactDateTime =
        '${localNow.year}-${localNow.month.toString().padLeft(2, '0')}-${localNow.day.toString().padLeft(2, '0')} '
        '${localNow.hour.toString().padLeft(2, '0')}:${localNow.minute.toString().padLeft(2, '0')}';

    return template
        .replaceAll(promptPlaceholderCurrentLocalDateTime, iso)
        .replaceAll(
          promptPlaceholderCurrentLocalDateTimeCompact,
          compactDateTime,
        )
        .replaceAll(promptPlaceholderWeekday, weekday)
        .replaceAll(promptPlaceholderTimezoneOffset, tz)
        .replaceAll(promptPlaceholderTranscript, transcript);
  }
}
