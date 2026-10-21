/// Benchmark cases for the voice memo extraction prompt. Pure Dart, so both
/// the Flutter testbench and the headless `bin/` runners can use them.
library;

/// Fixed reference time for deterministic tests.
/// Wednesday March 11, 2026, 10:15 AM.
final benchmarkReferenceTime = DateTime(2026, 3, 11, 10, 15);

// ── Test case definition ─────────────────────────────────────────────────

/// Expected extraction for one item in a multi-item benchmark case.
class ExpectedItem {
  final String expectedIntent;
  final bool expectTime;
  final List<String> titleLanguageKeywords;
  final DateTime? expectedDateTime;
  final int toleranceMinutes;

  /// For timer intent: expected duration in seconds.
  final int? expectedDurationSeconds;

  /// Tolerance for duration matching (default ±5 seconds).
  final int durationToleranceSeconds;

  const ExpectedItem({
    required this.expectedIntent,
    required this.expectTime,
    this.titleLanguageKeywords = const [],
    this.expectedDateTime,
    this.toleranceMinutes = 5,
    this.expectedDurationSeconds,
    this.durationToleranceSeconds = 5,
  });
}

class BenchmarkCase {
  final String name;
  final String transcript;

  /// Expected items. For single-extraction cases, this has one element.
  final List<ExpectedItem> expectedItems;

  BenchmarkCase({
    required this.name,
    required this.transcript,
    required this.expectedItems,
  });

  /// Convenience constructor for single-extraction cases (backward compat).
  BenchmarkCase.single({
    required this.name,
    required this.transcript,
    required String expectedIntent,
    required bool expectTime,
    List<String> titleLanguageKeywords = const [],
    DateTime? expectedDateTime,
    int toleranceMinutes = 5,
    int? expectedDurationSeconds,
    int durationToleranceSeconds = 5,
  }) : expectedItems = [
         ExpectedItem(
           expectedIntent: expectedIntent,
           expectTime: expectTime,
           titleLanguageKeywords: titleLanguageKeywords,
           expectedDateTime: expectedDateTime,
           toleranceMinutes: toleranceMinutes,
           expectedDurationSeconds: expectedDurationSeconds,
           durationToleranceSeconds: durationToleranceSeconds,
         ),
       ];

  /// Shorthand accessors for single-item cases (used by existing code).
  String get expectedIntent => expectedItems.first.expectedIntent;
  bool get expectTime => expectedItems.first.expectTime;
  List<String> get titleLanguageKeywords =>
      expectedItems.first.titleLanguageKeywords;
  DateTime? get expectedDateTime => expectedItems.first.expectedDateTime;
  int get toleranceMinutes => expectedItems.first.toleranceMinutes;

  int get expectedCount => expectedItems.length;
  bool get isMultiItem => expectedItems.length > 1;
}

final benchmarkCases = <BenchmarkCase>[
  // ── English single-item cases ──────────────────────────────────────
  BenchmarkCase.single(
    name: 'en_event_precise_time',
    transcript:
        'Schedule a design review with Erik and Sara on March 14 at 3:30 PM in Lab 3.',
    expectedIntent: 'event',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 14, 15, 30),
  ),
  BenchmarkCase.single(
    name: 'en_reminder_tomorrow',
    transcript:
        'Remind me tomorrow at 7:15 AM to take the prototype battery off the charger.',
    expectedIntent: 'reminder',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 7, 15),
  ),
  BenchmarkCase.single(
    name: 'en_event_next_tuesday',
    transcript: 'Meeting with John next Tuesday at 2 pm.',
    expectedIntent: 'event',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 17, 14, 0),
  ),
  BenchmarkCase.single(
    name: 'en_reminder_next_friday',
    transcript:
        'I need to finish the PCB layout review and send it to the manufacturer by next Friday at 5 PM.',
    expectedIntent: 'reminder',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 20, 17, 0),
  ),
  BenchmarkCase.single(
    name: 'en_event_dentist',
    transcript:
        'Dentist appointment on April 22nd at 10:30 AM at the clinic downtown.',
    expectedIntent: 'event',
    expectTime: true,
    expectedDateTime: DateTime(2026, 4, 22, 10, 30),
  ),
  BenchmarkCase.single(
    name: 'en_note_no_time',
    transcript:
        'Had an interesting idea about using a pressure sensor to detect altitude changes for the hiking app.',
    expectedIntent: 'note',
    expectTime: false,
  ),
  BenchmarkCase.single(
    name: 'en_reminder_this_afternoon',
    transcript: 'Call the plumber this afternoon at 3.',
    expectedIntent: 'reminder',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 11, 15, 0),
  ),

  // ── Swedish single-item cases (native language title validation) ──
  BenchmarkCase.single(
    name: 'sv_reminder_tomorrow',
    transcript: 'Påminn mig imorgon klockan 8 att ringa tandläkaren.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['ringa', 'tandläkare'],
    expectedDateTime: DateTime(2026, 3, 12, 8, 0),
  ),
  BenchmarkCase.single(
    name: 'sv_event_meeting',
    transcript:
        'Möte med projektgruppen på torsdag klockan 14 i stora konferensrummet.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['möte', 'projektgrupp'],
    expectedDateTime: DateTime(2026, 3, 12, 14, 0),
  ),
  BenchmarkCase.single(
    name: 'sv_note_no_time',
    transcript: 'Köp mjölk och bröd på vägen hem.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['köp', 'mjölk', 'bröd'],
  ),
  BenchmarkCase.single(
    name: 'sv_note_idea',
    transcript:
        'Bra idé om att lägga till stegräknare i klockan, kanske använda BMI270 sensorn.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['stegräknare', 'klocka', 'idé', 'sensor'],
  ),
  BenchmarkCase.single(
    name: 'sv_event_specific_date',
    transcript: 'Tandläkare den 15 mars klockan halv 10.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['tandläkare'],
    expectedDateTime: DateTime(2026, 3, 15, 9, 30),
  ),

  // ── German single-item cases (native language title validation) ───
  BenchmarkCase.single(
    name: 'de_event_appointment',
    transcript:
        'Arzttermin am Donnerstag um 9 Uhr in der Praxis am Marktplatz.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['arzt', 'termin', 'praxis'],
    expectedDateTime: DateTime(2026, 3, 12, 9, 0),
  ),
  BenchmarkCase.single(
    name: 'de_reminder_deadline',
    transcript:
        'Ich muss den Bericht bis Freitag um 17 Uhr fertig haben und an den Chef schicken.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['bericht', 'chef', 'schicken'],
    expectedDateTime: DateTime(2026, 3, 13, 17, 0),
  ),

  // ── Additional English single-item cases ─────────────────────────
  BenchmarkCase.single(
    name: 'en_reminder_specific_date',
    transcript: 'Submit the expense report by March 20th at 9 AM.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['expense', 'report'],
    expectedDateTime: DateTime(2026, 3, 20, 9, 0),
  ),
  BenchmarkCase.single(
    name: 'en_event_birthday',
    transcript: 'Mom\'s birthday party on April 5th at 6 PM.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['birthday'],
    expectedDateTime: DateTime(2026, 4, 5, 18, 0),
  ),
  BenchmarkCase.single(
    name: 'en_note_idea_short',
    transcript: 'Try using Rust for the sensor driver.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['rust', 'sensor'],
  ),

  // ── Additional Swedish single-item cases ─────────────────────────
  BenchmarkCase.single(
    name: 'sv_event_fika',
    transcript: 'Fika med Lisa på fredag klockan 15.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['fika', 'lisa'],
    expectedDateTime: DateTime(2026, 3, 13, 15, 0),
  ),
  BenchmarkCase.single(
    name: 'sv_reminder_pickup_kids',
    transcript: 'Hämta barnen på förskolan imorgon klockan halv 5.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['hämta', 'barn'],
    expectedDateTime: DateTime(2026, 3, 12, 16, 30),
  ),
  BenchmarkCase.single(
    name: 'sv_event_doctor',
    transcript: 'Läkartid på vårdcentralen den 18 mars klockan 10.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['läkar'],
    expectedDateTime: DateTime(2026, 3, 18, 10, 0),
  ),
  BenchmarkCase.single(
    name: 'sv_reminder_medicine',
    transcript: 'Ta medicinen varje dag klockan 8 på morgonen.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['medicin'],
  ),
  BenchmarkCase.single(
    name: 'sv_event_dinner',
    transcript: 'Middag hos mamma och pappa på lördag klockan 18.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['middag', 'mamma'],
    expectedDateTime: DateTime(2026, 3, 14, 18, 0),
  ),
  BenchmarkCase.single(
    name: 'sv_event_car_service',
    transcript: 'Bilservice på tisdag klockan 8 hos Mekonomen.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['bilservice'],
    expectedDateTime: DateTime(2026, 3, 17, 8, 0),
  ),
  BenchmarkCase.single(
    name: 'sv_note_grocery',
    transcript: 'Handla potatis, lök och grädde till middagen.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['handla', 'potatis'],
  ),
  BenchmarkCase.single(
    name: 'sv_event_parents_meeting',
    transcript: 'Föräldramöte på skolan onsdag klockan 18:30.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['föräldramöte'],
    expectedDateTime: DateTime(2026, 3, 18, 18, 30),
  ),
  BenchmarkCase.single(
    name: 'sv_reminder_deadline',
    transcript: 'Skicka in rapporten senast fredag klockan 12.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['rapport', 'skicka'],
    expectedDateTime: DateTime(2026, 3, 13, 12, 0),
  ),

  // ── Voice note tests – short (1-2 sentences, casual/fragmented) ──
  BenchmarkCase.single(
    name: 'voice_short_en_idea',
    transcript: 'Maybe add a compass widget to the watch face.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['compass'],
  ),
  BenchmarkCase.single(
    name: 'voice_short_sv_idea',
    transcript: 'Testa att använda e-paper display till nästa version.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['e-paper', 'display'],
  ),
  BenchmarkCase.single(
    name: 'voice_short_en_quick_reminder',
    transcript: 'Oh yeah, water the plants at 5.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['water', 'plant'],
  ),
  BenchmarkCase.single(
    name: 'voice_short_sv_quick_reminder',
    transcript: 'Ah just det, ring försäkringsbolaget imorgon.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['ring', 'försäkring'],
  ),
  BenchmarkCase.single(
    name: 'voice_short_en_fragment',
    transcript: 'Buy batteries.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['batter'],
  ),
  BenchmarkCase.single(
    name: 'voice_short_sv_fragment',
    transcript: 'Boka tid hos frisören.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['boka', 'frisör'],
  ),

  // ── Voice note tests – long (rambling, filler words, multi-sentence) ─
  BenchmarkCase.single(
    name: 'voice_long_en_rambling_reminder',
    transcript:
        'So I was thinking, um, I really need to remember to pick up the dry cleaning, '
        'I think the ticket is in my jacket, anyway I should do it tomorrow before noon '
        'because they close early on Thursdays.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['dry clean'],
  ),
  BenchmarkCase.single(
    name: 'voice_long_sv_rambling_event',
    transcript:
        'Öh jag pratade med Johan igår och vi bestämde att vi ska ha ett möte, '
        'tror det var på torsdag klockan 10 eller nåt, i alla fall ska vi gå igenom '
        'hela budgeten för nästa kvartal.',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['möte', 'johan', 'budget'],
    expectedDateTime: DateTime(2026, 3, 12, 10, 0),
  ),
  BenchmarkCase.single(
    name: 'voice_long_en_idea_note',
    transcript:
        'Had a really interesting conversation with the hardware team today about, '
        'you know, potentially integrating an ambient light sensor so the display '
        'brightness adjusts automatically. Could save a lot of battery and the user '
        'experience would be much smoother. Should look into the VEML7700 or maybe '
        'the BH1750 sensor, both are I2C and pretty cheap.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['light', 'sensor', 'display'],
  ),
  BenchmarkCase.single(
    name: 'voice_long_sv_idea_note',
    transcript:
        'Jag tänkte på en grej, vi borde kanske lägga till sömnspårning i appen, '
        'alltså använda accelerometern för att mäta rörelser under natten och sen '
        'visa statistik på morgonen. Det finns en bra algoritm i den där forskningsartikeln '
        'jag läste förra veckan, kolla upp det.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['sömnspårning', 'accelerometer', 'app'],
  ),

  // ── Additional multi-item cases ──────────────────────────────────
  BenchmarkCase(
    name: 'sv_multi_fika_and_errand',
    transcript:
        'Fika med Anna imorgon klockan 10 och sen lämna in paketet på posten.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['fika', 'anna'],
        expectedDateTime: DateTime(2026, 3, 12, 10, 0),
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['paket'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'sv_multi_three_items',
    transcript:
        'Ring tandläkaren imorgon klockan 9, köp presenter till kalaset och '
        'möte med chefen på fredag klockan 14.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['tandläkare', 'ring'],
        expectedDateTime: DateTime(2026, 3, 12, 9, 0),
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['present', 'kalas'],
      ),
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['möte', 'chef'],
        expectedDateTime: DateTime(2026, 3, 13, 14, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'en_multi_event_and_idea',
    transcript:
        'Team standup tomorrow at 9:15 and I should really prototype '
        'the new notification system with stacked cards.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['standup'],
        expectedDateTime: DateTime(2026, 3, 12, 9, 15),
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['notification', 'prototype'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'voice_long_multi_sv',
    transcript:
        'Okej så imorgon klockan 8 måste jag gå till gymmet och sen på eftermiddagen '
        'typ klockan 3 ska jag träffa Erik för att prata om projektet och sen behöver '
        'jag också komma ihåg att köpa kattsand.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['gym'],
        expectedDateTime: DateTime(2026, 3, 12, 8, 0),
      ),
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['erik', 'projekt'],
        expectedDateTime: DateTime(2026, 3, 12, 15, 0),
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['kattsand'],
      ),
    ],
  ),

  // ── Conversational Swedish / Swenglish voice notes ───────────────
  BenchmarkCase(
    name: 'sv_multi_dev_tasks_swenglish',
    transcript:
        'Vi ska cleana upp klockans kod för voice memons sen ska vi testa att '
        'det går avbryta en calender tilläggning genom att klicka cancel på popup på klockan',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['clean', 'kod', 'voice'],
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['testa', 'calender', 'cancel'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'sv_multi_casual_planning',
    transcript:
        'Vi behöver fixa buggen med Bluetooth-anslutningen och sen ska vi '
        'refaktorera sensor-koden lite grann.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['bugg', 'bluetooth'],
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['refaktor', 'sensor'],
      ),
    ],
  ),
  BenchmarkCase.single(
    name: 'sv_note_swenglish_long',
    transcript:
        'Jag tänkte att vi kanske borde adda en feature för att synca '
        'notifications mellan telefonen och klockan typ via BLE, '
        'kolla om det finns nåt library för det.',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['sync', 'notification', 'feature'],
  ),

  // ── Multi-item cases ─────────────────────────────────────────────
  BenchmarkCase(
    name: 'en_multi_two_reminders',
    transcript:
        'Tomorrow at 5 pm we have to pick up the dog and then at 9 turn off all lights.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['dog', 'pick'],
      ),
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['light'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'en_multi_reminder_and_note',
    transcript:
        'Call the plumber at 3 pm tomorrow and also buy new light bulbs.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['plumber'],
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['light', 'bulb'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'en_multi_two_events',
    transcript:
        'Meeting with Sarah on Monday at 10 am and lunch with the team on Wednesday at noon.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['sarah'],
        expectedDateTime: DateTime(2026, 3, 16, 10, 0),
      ),
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['lunch'],
        expectedDateTime: DateTime(2026, 3, 18, 12, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'en_multi_three_mixed',
    transcript:
        'Tomorrow at 8 go for a run then have lunch with Mike at noon and buy groceries.',
    expectedItems: [
      ExpectedItem(expectedIntent: 'reminder', expectTime: true),
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['lunch'],
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['grocer'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'sv_multi_event_and_note',
    transcript:
        'Tandläkare den 15 mars klockan halv 10 och sen handla mat på vägen hem.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['tandläkare'],
        expectedDateTime: DateTime(2026, 3, 15, 9, 30),
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['handla'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'de_multi_two_events',
    transcript:
        'Arzttermin am Donnerstag um 9 Uhr und Zahnarzt am Freitag um 14 Uhr.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['arzt'],
        expectedDateTime: DateTime(2026, 3, 12, 9, 0),
      ),
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['zahnarzt'],
        expectedDateTime: DateTime(2026, 3, 13, 14, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'en_multi_same_day_reminders',
    transcript:
        'Today at 3 pm call the electrician and at 6 pm pick up the kids from school.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['electrician'],
        expectedDateTime: DateTime(2026, 3, 11, 15, 0),
      ),
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['kids'],
        expectedDateTime: DateTime(2026, 3, 11, 18, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'sv_multi_two_reminders',
    transcript:
        'Imorgon klockan 8 gå till gymmet och klockan 15 hämta paketet på posten.',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['gym'],
        expectedDateTime: DateTime(2026, 3, 12, 8, 0),
      ),
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['paket'],
        expectedDateTime: DateTime(2026, 3, 12, 15, 0),
      ),
    ],
  ),

  // ── Timer cases ──────────────────────────────────────────────────
  BenchmarkCase.single(
    name: 'en_timer_simple',
    transcript: 'Set a timer for 8 minutes',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 480,
  ),
  BenchmarkCase.single(
    name: 'en_timer_labeled',
    transcript: 'Timer for 5 minutes for pasta',
    expectedIntent: 'timer',
    expectTime: true,
    titleLanguageKeywords: ['pasta'],
    expectedDurationSeconds: 300,
  ),
  BenchmarkCase.single(
    name: 'en_timer_seconds',
    transcript: 'Set a 30 second timer',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 30,
  ),
  BenchmarkCase.single(
    name: 'en_timer_hour',
    transcript: 'Set a timer for one and a half hours',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 5400,
  ),
  BenchmarkCase.single(
    name: 'sv_timer_simple',
    transcript: 'Sätt en timer på 10 minuter',
    expectedIntent: 'timer',
    expectTime: true,
    titleLanguageKeywords: [],
    expectedDurationSeconds: 600,
  ),
  BenchmarkCase.single(
    name: 'sv_timer_labeled',
    transcript: 'Timer på 5 minuter för äggen',
    expectedIntent: 'timer',
    expectTime: true,
    titleLanguageKeywords: ['äggen'],
    expectedDurationSeconds: 300,
  ),
  BenchmarkCase.single(
    name: 'de_timer_simple',
    transcript: 'Stell einen Timer auf 15 Minuten',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 900,
  ),
  BenchmarkCase.single(
    name: 'en_timer_vs_reminder',
    transcript: 'Remind me in 30 minutes to check the oven',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['check', 'oven'],
  ),
  BenchmarkCase.single(
    name: 'en_timer_bare_duration',
    transcript: 'In 10 minutes',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 600,
  ),
  BenchmarkCase.single(
    name: 'en_timer_not_reminder',
    transcript: '30 minutes',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 1800,
  ),
  BenchmarkCase.single(
    name: 'sv_timer_vs_reminder',
    transcript: 'Påminn mig om 10 minuter att stänga av ugnen',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['stänga', 'ugnen'],
  ),

  // ── Alarm cases ──────────────────────────────────────────────────
  BenchmarkCase.single(
    name: 'en_alarm_morning',
    transcript: 'Set an alarm for 7:30 AM',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 7, 30),
  ),
  BenchmarkCase.single(
    name: 'en_alarm_labeled',
    transcript: 'Alarm at 6 AM, wake up',
    expectedIntent: 'alarm',
    expectTime: true,
    titleLanguageKeywords: ['wake'],
    expectedDateTime: DateTime(2026, 3, 12, 6, 0),
  ),
  BenchmarkCase.single(
    name: 'en_alarm_weekdays',
    transcript: 'Set an alarm for 7 AM every weekday',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 7, 0),
  ),
  BenchmarkCase.single(
    name: 'en_alarm_tomorrow',
    transcript: 'Wake me up tomorrow at 5:30',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 5, 30),
  ),
  BenchmarkCase.single(
    name: 'sv_alarm_simple',
    transcript: 'Ställ ett alarm klockan 7',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 7, 0),
  ),
  BenchmarkCase.single(
    name: 'sv_alarm_labeled',
    transcript: 'Alarm klockan halv 8, dags att gå',
    expectedIntent: 'alarm',
    expectTime: true,
    titleLanguageKeywords: ['dags', 'gå'],
    expectedDateTime: DateTime(2026, 3, 12, 7, 30),
  ),
  BenchmarkCase.single(
    name: 'de_alarm_simple',
    transcript: 'Wecker auf 7 Uhr stellen',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 7, 0),
  ),
  BenchmarkCase.single(
    name: 'en_alarm_vs_reminder',
    transcript: 'Remind me at 3 PM to call the dentist',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['call', 'dentist'],
    expectedDateTime: DateTime(2026, 3, 11, 15, 0),
  ),
  BenchmarkCase.single(
    name: 'en_alarm_no_action',
    transcript: '7 AM',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 7, 0),
  ),
  BenchmarkCase.single(
    name: 'sv_alarm_vs_reminder',
    transcript: 'Påminn mig klockan 15 att ringa tandläkaren',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['ringa', 'tandläkaren'],
    expectedDateTime: DateTime(2026, 3, 11, 15, 0),
  ),

  // ── Multi-item cases with timers/alarms ──────────────────────────
  BenchmarkCase(
    name: 'en_multi_timer_and_alarm',
    transcript: 'Set a timer for 10 minutes and an alarm for 7 AM tomorrow',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'timer',
        expectTime: true,
        expectedDurationSeconds: 600,
      ),
      ExpectedItem(
        expectedIntent: 'alarm',
        expectTime: true,
        expectedDateTime: DateTime(2026, 3, 12, 7, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'en_multi_alarm_and_note',
    transcript: 'Set an alarm for 6:30 and buy milk',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'alarm',
        expectTime: true,
        expectedDateTime: DateTime(2026, 3, 12, 6, 30),
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['milk'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'sv_multi_timer_and_reminder',
    transcript:
        'Sätt en timer på 5 minuter och påminn mig klockan 3 att ringa tandläkaren',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'timer',
        expectTime: true,
        expectedDurationSeconds: 300,
      ),
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['ringa', 'tandläkaren'],
        expectedDateTime: DateTime(2026, 3, 11, 15, 0),
      ),
    ],
  ),

  // ── No-speech / garbage input cases ─────────────────────────────────
  // These should produce an empty array []. The LLM should not
  // hallucinate actions from noise or silence markers.
  BenchmarkCase(
    name: 'nospeech_blank_audio_marker',
    transcript: '[BLANK_AUDIO]',
    expectedItems: [],
  ),
  BenchmarkCase(
    name: 'nospeech_silence_marker',
    transcript: '[silence]',
    expectedItems: [],
  ),
  BenchmarkCase(
    name: 'nospeech_music_marker',
    transcript: '(music)',
    expectedItems: [],
  ),
  BenchmarkCase(
    name: 'nospeech_just_punctuation',
    transcript: '... . ,',
    expectedItems: [],
  ),
  BenchmarkCase(
    name: 'nospeech_gibberish_short',
    transcript: 'hmm uhh',
    expectedItems: [],
  ),
  BenchmarkCase(
    name: 'nospeech_whisper_noise_artifact',
    transcript: '♪ ♪ ♪',
    expectedItems: [],
  ),
];
