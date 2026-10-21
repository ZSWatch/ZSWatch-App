import 'benchmark_cases.dart';

/// Overfitting check: run these to compare prompt versions, never tune the
/// prompt or the pipeline to fix a case here. Replace the set when that
/// happened. Reference time: Wednesday 2026-03-11 10:15.
final heldOutCases = <BenchmarkCase>[
  BenchmarkCase.single(
    name: 'ho_sv_timer_hour_words',
    transcript: 'Starta en timer på en timme',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 3600,
  ),
  BenchmarkCase.single(
    name: 'ho_en_timer_label',
    transcript: 'Countdown three minutes for the noodles',
    expectedIntent: 'timer',
    expectTime: true,
    titleLanguageKeywords: ['noodles'],
    expectedDurationSeconds: 180,
  ),
  BenchmarkCase.single(
    name: 'ho_de_timer_seconds',
    transcript: 'Timer auf neunzig Sekunden',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 90,
  ),
  BenchmarkCase.single(
    name: 'ho_es_timer',
    transcript: 'Pon un temporizador de quince minutos',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 900,
  ),
  BenchmarkCase.single(
    name: 'ho_sv_alarm_24h',
    transcript: 'Ställ väckarklockan på 05:45',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 5, 45),
  ),
  BenchmarkCase.single(
    name: 'ho_en_alarm_saturday',
    transcript: 'Alarm Saturday at 9',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 14, 9, 0),
  ),
  BenchmarkCase.single(
    name: 'ho_fr_alarm',
    transcript: 'Réveille-moi demain à six heures',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 6, 0),
  ),
  BenchmarkCase.single(
    name: 'ho_sv_reminder_evening',
    transcript: 'Påminn mig ikväll klockan åtta att vattna blommorna',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['vattna', 'blommor'],
    expectedDateTime: DateTime(2026, 3, 11, 20, 0),
  ),
  BenchmarkCase.single(
    name: 'ho_sv_reminder_in_hours',
    transcript: 'Om två timmar ska jag flytta bilen',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['flytta', 'bil'],
    expectedDateTime: DateTime(2026, 3, 11, 12, 15),
  ),
  BenchmarkCase.single(
    name: 'ho_en_reminder_weekday',
    transcript: 'On Monday at 11 send the invoice to Peter',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['invoice'],
    expectedDateTime: DateTime(2026, 3, 16, 11, 0),
  ),
  BenchmarkCase.single(
    name: 'ho_de_reminder',
    transcript: 'Erinnere mich morgen um zehn an die Steuererklärung',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['steuererklärung'],
    expectedDateTime: DateTime(2026, 3, 12, 10, 0),
  ),
  BenchmarkCase.single(
    name: 'ho_es_reminder',
    transcript: 'Recuérdame mañana a las cuatro llamar a mi hermana',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['llamar', 'hermana'],
    expectedDateTime: DateTime(2026, 3, 12, 16, 0),
  ),
  BenchmarkCase.single(
    name: 'ho_sv_event_kvart_over',
    transcript: 'Tandhygienist på måndag kvart över två',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['tandhygienist'],
    expectedDateTime: DateTime(2026, 3, 16, 14, 15),
  ),
  BenchmarkCase.single(
    name: 'ho_en_event_date',
    transcript: 'Parent teacher meeting on the 24th at 6 pm',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['meeting', 'teacher'],
    expectedDateTime: DateTime(2026, 3, 24, 18, 0),
  ),
  BenchmarkCase.single(
    name: 'ho_de_event_halb',
    transcript: 'Abendessen mit Oma am Sonntag um halb sieben abends',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['abendessen', 'oma'],
    expectedDateTime: DateTime(2026, 3, 15, 18, 30),
  ),
  BenchmarkCase.single(
    name: 'ho_sv_note_whisper',
    transcript: 'Glöm inte att beställa nya bromsklossar till cykeln',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['bromsklossar', 'beställa'],
  ),
  BenchmarkCase.single(
    name: 'ho_en_note_thought',
    transcript:
        'Thinking out loud, the step counter screen could show weekly '
        'averages instead of just today',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['step', 'weekly'],
  ),
  BenchmarkCase.single(
    name: 'ho_de_note',
    transcript: 'Wir brauchen noch Batterien für die Fernbedienung',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['batterien'],
  ),
  BenchmarkCase(
    name: 'ho_sv_multi_timer_reminder',
    transcript:
        'Timer på åtta minuter för äggen och påminn mig klockan fyra att '
        'hämta Ella',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'timer',
        expectTime: true,
        expectedDurationSeconds: 480,
      ),
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['hämta', 'ella'],
        expectedDateTime: DateTime(2026, 3, 11, 16, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'ho_en_multi_event_note',
    transcript:
        'Badminton with Tom on Friday at 7 pm, and I should look into '
        'cheaper phone plans',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['badminton', 'tom'],
        expectedDateTime: DateTime(2026, 3, 13, 19, 0),
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['phone', 'plans'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'ho_sv_multi_two_events',
    transcript:
        'På torsdag klockan tio föräldramöte och på lördag klockan ett '
        'kalas hos Maja',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['föräldramöte'],
        expectedDateTime: DateTime(2026, 3, 12, 10, 0),
      ),
      ExpectedItem(
        expectedIntent: 'event',
        expectTime: true,
        titleLanguageKeywords: ['kalas', 'maja'],
        expectedDateTime: DateTime(2026, 3, 14, 13, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'ho_de_multi_carry_date',
    transcript: 'Übermorgen um acht zum Bäcker und um drei die Wohnung putzen',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['bäcker'],
        expectedDateTime: DateTime(2026, 3, 13, 8, 0),
      ),
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['wohnung', 'putzen'],
        expectedDateTime: DateTime(2026, 3, 13, 15, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'ho_en_filler_noise',
    transcript: 'uh okay never mind',
    expectedItems: [],
  ),
  BenchmarkCase.single(
    name: 'ho_sv_long_rambling',
    transcript:
        'Ja alltså jag tänkte att vi kanske borde, eh, boka bord på '
        'restaurangen till på fredag klockan sju, typ för hela gänget',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['boka', 'bord', 'restaurang'],
    expectedDateTime: DateTime(2026, 3, 13, 19, 0),
  ),
];
