import 'benchmark_cases.dart';

/// Memos as they reach the model on the phone: Whisper spellings, number
/// words, mixed items. None of them may appear in the prompt examples.
/// Reference time: Wednesday 2026-03-11 10:15.
final realWorldCases = <BenchmarkCase>[
  BenchmarkCase.single(
    name: 'rw_sv_timer_words',
    transcript: 'Sätt en timer på tio minuter.',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 600,
  ),
  BenchmarkCase.single(
    name: 'rw_sv_timer_whisper',
    transcript: 'Sett en timer på tjugo minuter',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 1200,
  ),
  BenchmarkCase.single(
    name: 'rw_sv_timer_label',
    transcript: 'Timer tolv minuter för pizzan',
    expectedIntent: 'timer',
    expectTime: true,
    titleLanguageKeywords: ['pizza'],
    expectedDurationSeconds: 720,
  ),
  BenchmarkCase.single(
    name: 'rw_de_timer_words',
    transcript: 'Stell einen Timer auf zwanzig Minuten',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 1200,
  ),
  BenchmarkCase.single(
    name: 'rw_en_timer_compound',
    transcript: 'Start a countdown for two hours and fifteen minutes',
    expectedIntent: 'timer',
    expectTime: true,
    expectedDurationSeconds: 8100,
  ),
  BenchmarkCase.single(
    name: 'rw_sv_alarm_halv',
    transcript: 'Väck mig klockan halv sju imorgon',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 6, 30),
  ),
  BenchmarkCase.single(
    name: 'rw_en_alarm_words',
    transcript: 'Wake me up at six thirty',
    expectedIntent: 'alarm',
    expectTime: true,
    expectedDateTime: DateTime(2026, 3, 12, 6, 30),
  ),
  BenchmarkCase.single(
    name: 'rw_sv_reminder_kvart',
    transcript: 'Påminn mig om en kvart att ta ut tvätten',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['tvätt'],
    expectedDateTime: DateTime(2026, 3, 11, 10, 30),
  ),
  BenchmarkCase.single(
    name: 'rw_sv_reminder_whisper',
    transcript: 'På min med i morgon klockan tio att köpa mjölk.',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['mjölk'],
    expectedDateTime: DateTime(2026, 3, 12, 10, 0),
  ),
  BenchmarkCase.single(
    name: 'rw_en_reminder_tonight',
    transcript: 'Remind me tonight at eight to call mom',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['call', 'mom'],
    expectedDateTime: DateTime(2026, 3, 11, 20, 0),
  ),
  BenchmarkCase.single(
    name: 'rw_en_reminder_in_words',
    transcript: 'In twenty minutes remind me to flip the steak',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['steak'],
    expectedDateTime: DateTime(2026, 3, 11, 10, 35),
  ),
  BenchmarkCase.single(
    name: 'rw_sv_reminder_fillers',
    transcript:
        'Eh, ja, öh, påminn mig på fredag klockan nio om att betala hyran',
    expectedIntent: 'reminder',
    expectTime: true,
    titleLanguageKeywords: ['hyra'],
    expectedDateTime: DateTime(2026, 3, 13, 9, 0),
  ),
  BenchmarkCase.single(
    name: 'rw_sv_event_weekday',
    transcript: 'Middag hos Lisa på lördag klockan sju',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['middag', 'lisa'],
    expectedDateTime: DateTime(2026, 3, 14, 19, 0),
  ),
  BenchmarkCase.single(
    name: 'rw_sv_event_halv',
    transcript: 'Fika med Johan på torsdag klockan halv fyra',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['fika', 'johan'],
    expectedDateTime: DateTime(2026, 3, 12, 15, 30),
  ),
  BenchmarkCase.single(
    name: 'rw_de_event_halb',
    transcript: 'Termin beim Friseur am Freitag um halb drei',
    expectedIntent: 'event',
    expectTime: true,
    titleLanguageKeywords: ['friseur'],
    expectedDateTime: DateTime(2026, 3, 13, 14, 30),
  ),
  BenchmarkCase.single(
    name: 'rw_sv_note_idea',
    transcript: 'Idé: visa batterinivån i procent på urtavlan',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['batteri', 'urtavla'],
  ),
  BenchmarkCase.single(
    name: 'rw_en_note_list',
    transcript: 'Shopping list: eggs, butter, coffee and oat milk',
    expectedIntent: 'note',
    expectTime: false,
    titleLanguageKeywords: ['eggs', 'shopping'],
  ),
  BenchmarkCase(
    name: 'rw_sv_multi_timer_note',
    transcript: 'Sätt en timer på fem minuter och kom ihåg att köpa batterier',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'timer',
        expectTime: true,
        expectedDurationSeconds: 300,
      ),
      ExpectedItem(
        expectedIntent: 'note',
        expectTime: false,
        titleLanguageKeywords: ['batterier'],
      ),
    ],
  ),
  BenchmarkCase(
    name: 'rw_sv_multi_carry_date',
    transcript:
        'Imorgon klockan nio ringa banken och klockan två hämta paketet',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['bank'],
        expectedDateTime: DateTime(2026, 3, 12, 9, 0),
      ),
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['paket'],
        expectedDateTime: DateTime(2026, 3, 12, 14, 0),
      ),
    ],
  ),
  BenchmarkCase(
    name: 'rw_en_multi_alarm_reminder',
    transcript:
        'Set an alarm for 6 am tomorrow and remind me at 8 to take my vitamins',
    expectedItems: [
      ExpectedItem(
        expectedIntent: 'alarm',
        expectTime: true,
        expectedDateTime: DateTime(2026, 3, 12, 6, 0),
      ),
      ExpectedItem(
        expectedIntent: 'reminder',
        expectTime: true,
        titleLanguageKeywords: ['vitamin'],
        expectedDateTime: DateTime(2026, 3, 12, 8, 0),
      ),
    ],
  ),
];
