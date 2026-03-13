import 'dart:async';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:flutter/foundation.dart';

import 'llm_service.dart';

// ── Test case definition ─────────────────────────────────────────────────

/// Expected extraction for one item in a multi-item benchmark case.
class ExpectedItem {
  final String expectedIntent;
  final bool expectTime;
  final List<String> titleLanguageKeywords;
  final DateTime? expectedDateTime;
  final int toleranceMinutes;

  const ExpectedItem({
    required this.expectedIntent,
    required this.expectTime,
    this.titleLanguageKeywords = const [],
    this.expectedDateTime,
    this.toleranceMinutes = 5,
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
  }) : expectedItems = [
          ExpectedItem(
            expectedIntent: expectedIntent,
            expectTime: expectTime,
            titleLanguageKeywords: titleLanguageKeywords,
            expectedDateTime: expectedDateTime,
            toleranceMinutes: toleranceMinutes,
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

// ── Test result ──────────────────────────────────────────────────────────

class BenchmarkCaseResult {
  final String caseName;
  final bool validJson;
  final bool intentMatch;
  final bool timePresenceMatch;
  final bool titleLanguageMatch;
  final String? titleLanguageDetail;
  final bool timeResolutionCorrect;
  final String? timeResolutionDetail;
  final String intent;
  final String? title;
  final String? datetimeOriginal;
  final String? datetimeEnglish;
  final Duration elapsed;
  final double tokensPerSecond;
  final String outputPreview;
  final String? error;

  /// Number of items extracted from the output.
  final int extractedCount;

  /// Number of items expected.
  final int expectedCount;

  /// Whether the count of extracted items matches expected.
  final bool countMatch;

  /// Per-item validation details for multi-item cases.
  final List<String> itemFailures;

  const BenchmarkCaseResult({
    required this.caseName,
    required this.validJson,
    required this.intentMatch,
    required this.timePresenceMatch,
    this.titleLanguageMatch = true,
    this.titleLanguageDetail,
    this.timeResolutionCorrect = true,
    this.timeResolutionDetail,
    required this.intent,
    this.title,
    this.datetimeOriginal,
    this.datetimeEnglish,
    required this.elapsed,
    required this.tokensPerSecond,
    required this.outputPreview,
    this.error,
    this.extractedCount = 1,
    this.expectedCount = 1,
    this.countMatch = true,
    this.itemFailures = const [],
  });

  bool get passed =>
      validJson &&
      intentMatch &&
      timePresenceMatch &&
      titleLanguageMatch &&
      timeResolutionCorrect &&
      countMatch &&
      itemFailures.isEmpty;
}

// ── Progress ─────────────────────────────────────────────────────────────

class BenchmarkProgress {
  final int totalModels;
  final int totalCasesPerModel;
  final int totalRuns;
  final int completedRuns;
  final int currentModelIndex;
  final int currentCaseIndex;
  final String currentModelPath;
  final String currentCaseName;

  const BenchmarkProgress({
    required this.totalModels,
    required this.totalCasesPerModel,
    required this.totalRuns,
    required this.completedRuns,
    required this.currentModelIndex,
    required this.currentCaseIndex,
    required this.currentModelPath,
    required this.currentCaseName,
  });

  double get fractionComplete => totalRuns == 0 ? 0 : completedRuns / totalRuns;
  int get remainingRuns => totalRuns - completedRuns;
  String get currentModelName =>
      currentModelPath.split(Platform.pathSeparator).last;
}

// ── Aggregate result for a model ─────────────────────────────────────────

class BenchmarkModelResult {
  final String modelPath;
  final List<BenchmarkCaseResult> cases;

  const BenchmarkModelResult({
    required this.modelPath,
    required this.cases,
  });

  String get modelName => modelPath.split(Platform.pathSeparator).last;
  int get passedCases => cases.where((c) => c.passed).length;
  double get avgTokensPerSecond => cases.isEmpty
      ? 0
      : cases.fold<double>(0, (sum, c) => sum + c.tokensPerSecond) /
          cases.length;
  Duration get totalElapsed =>
      cases.fold(Duration.zero, (sum, c) => sum + c.elapsed);
}

// ── Service ──────────────────────────────────────────────────────────────

class ModelBenchmarkService {
  static const Duration perCaseTimeout = Duration(seconds: 90);
  static const ChronoLlmParser _parser = ChronoLlmParser();

  /// Fixed reference time for deterministic tests.
  /// Wednesday March 11, 2026, 10:15 AM.
  static final DateTime referenceTime = DateTime(2026, 3, 11, 10, 15);

  static final benchmarkCases = <BenchmarkCase>[
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
        ExpectedItem(
          expectedIntent: 'reminder',
          expectTime: true,
        ),
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
  ];

  Future<List<BenchmarkModelResult>> runForModels(
    List<String> modelPaths, {
    void Function(BenchmarkProgress progress)? onProgress,
  }) async {
    final results = <BenchmarkModelResult>[];
    final totalCases = benchmarkCases.length;
    final totalRuns = modelPaths.length * totalCases;
    var completedRuns = 0;
    final resolver = TimeExpressionResolver();

    for (var modelIndex = 0; modelIndex < modelPaths.length; modelIndex++) {
      final modelPath = modelPaths[modelIndex];
      final llm = LlmService()
        ..setModel(modelPath)
        ..nCtx = 2048
        ..nThreads = Platform.numberOfProcessors
        ..maxTokens = 384
        ..temperature = 0.3
        ..topP = 1.0
        ..presencePenalty = 2.0
        ..enableThinking = false;

      final caseResults = <BenchmarkCaseResult>[];
      try {
        for (var caseIndex = 0;
            caseIndex < benchmarkCases.length;
            caseIndex++) {
          final testCase = benchmarkCases[caseIndex];
          onProgress?.call(
            BenchmarkProgress(
              totalModels: modelPaths.length,
              totalCasesPerModel: totalCases,
              totalRuns: totalRuns,
              completedRuns: completedRuns,
              currentModelIndex: modelIndex,
              currentCaseIndex: caseIndex,
              currentModelPath: modelPath,
              currentCaseName: testCase.name,
            ),
          );

          // Use the shared ChronoPromptTemplate from chrono_ai_flow
          final prompt = ChronoPromptTemplate.render(
            ChronoPromptTemplate.defaultTemplate,
            transcript: testCase.transcript,
            now: referenceTime,
          );

          try {
            final result = await llm
                .generate(prompt)
                .timeout(perCaseTimeout);

            // Parse using the shared ChronoLlmParser
            final parseResult = _parser.parse(result.output);
            final extractions = parseResult.extractions;
            final validJson = extractions.isNotEmpty;

            final extractedCount = extractions.length;
            final expectedCount = testCase.expectedCount;
            final countMatch = extractedCount == expectedCount;

            // Validate each expected item against extracted items.
            // Use positional matching: expected[i] ↔ extracted[i].
            var allIntentMatch = true;
            var allTimePresenceMatch = true;
            var allTitleLangMatch = true;
            var allTimeResMatch = true;
            String? allTitleLangDetail;
            String? allTimeResDetail;
            final itemFailures = <String>[];

            final checkCount =
                extractedCount < expectedCount ? extractedCount : expectedCount;
            for (var i = 0; i < checkCount; i++) {
              final ext = extractions[i];
              final exp = testCase.expectedItems[i];

              final intentOk = _intentMatches(ext.intent, exp.expectedIntent);
              if (!intentOk) {
                allIntentMatch = false;
                itemFailures.add(
                    'item[$i] intent: got "${ext.intent}", expected "${exp.expectedIntent}"');
              }

              final hasTime = ext.datetimeExpressionOriginal != null ||
                  ext.datetimeExpressionEnglish != null;
              if (hasTime != exp.expectTime) {
                allTimePresenceMatch = false;
                itemFailures.add(
                    'item[$i] time presence: got $hasTime, expected ${exp.expectTime}');
              }

              final titleLang =
                  _checkTitleLanguageForItem(ext.title, exp);
              if (!titleLang.passed) {
                allTitleLangMatch = false;
                itemFailures.add(
                    'item[$i] title lang: ${titleLang.detail}');
              }
              allTitleLangDetail = (allTitleLangDetail ?? '') +
                  'item[$i]: ${titleLang.detail}; ';

              final timeRes = _checkTimeResolutionForItem(
                ext.datetimeExpressionEnglish ??
                    ext.datetimeExpressionOriginal,
                exp,
                resolver,
              );
              if (!timeRes.passed) {
                allTimeResMatch = false;
                itemFailures.add(
                    'item[$i] time: ${timeRes.detail}');
              }
              allTimeResDetail = (allTimeResDetail ?? '') +
                  'item[$i]: ${timeRes.detail}; ';
            }

            // If count mismatch, mark missing items as failures
            for (var i = checkCount; i < expectedCount; i++) {
              itemFailures.add('item[$i] missing from output');
              allIntentMatch = false;
              allTimePresenceMatch = false;
            }
            for (var i = checkCount; i < extractedCount; i++) {
              itemFailures
                  .add('item[$i] unexpected extra extraction');
            }

            // Use first extraction for summary fields (backward compat)
            final first = extractions.isNotEmpty ? extractions.first : null;

            caseResults.add(
              BenchmarkCaseResult(
                caseName: testCase.name,
                validJson: validJson,
                intentMatch: allIntentMatch,
                timePresenceMatch: allTimePresenceMatch,
                titleLanguageMatch: allTitleLangMatch,
                titleLanguageDetail: allTitleLangDetail,
                timeResolutionCorrect: allTimeResMatch,
                timeResolutionDetail: allTimeResDetail,
                intent: first?.intent ?? '',
                title: first?.title,
                datetimeOriginal: first?.datetimeExpressionOriginal,
                datetimeEnglish: first?.datetimeExpressionEnglish,
                elapsed: result.elapsed,
                tokensPerSecond: result.tokensPerSecond,
                outputPreview: result.output.length > 300
                    ? '${result.output.substring(0, 300)}...'
                    : result.output,
                extractedCount: extractedCount,
                expectedCount: expectedCount,
                countMatch: countMatch,
                itemFailures: itemFailures,
              ),
            );
          } on TimeoutException {
            llm.cancelInference();
            caseResults.add(
              BenchmarkCaseResult(
                caseName: testCase.name,
                validJson: false,
                intentMatch: false,
                timePresenceMatch: false,
                titleLanguageMatch: false,
                timeResolutionCorrect: false,
                intent: 'timeout',
                elapsed: perCaseTimeout,
                tokensPerSecond: 0,
                outputPreview:
                    'Timed out after ${perCaseTimeout.inSeconds}s',
                error: 'Timed out after ${perCaseTimeout.inSeconds}s',
                extractedCount: 0,
                expectedCount: testCase.expectedCount,
                countMatch: false,
              ),
            );
          } catch (e) {
            llm.cancelInference();
            caseResults.add(
              BenchmarkCaseResult(
                caseName: testCase.name,
                validJson: false,
                intentMatch: false,
                timePresenceMatch: false,
                titleLanguageMatch: false,
                timeResolutionCorrect: false,
                intent: 'error',
                elapsed: Duration.zero,
                tokensPerSecond: 0,
                outputPreview: 'Error: $e',
                error: e.toString(),
                extractedCount: 0,
                expectedCount: testCase.expectedCount,
                countMatch: false,
              ),
            );
          }

          completedRuns++;
          onProgress?.call(
            BenchmarkProgress(
              totalModels: modelPaths.length,
              totalCasesPerModel: totalCases,
              totalRuns: totalRuns,
              completedRuns: completedRuns,
              currentModelIndex: modelIndex,
              currentCaseIndex: caseIndex,
              currentModelPath: modelPath,
              currentCaseName: testCase.name,
            ),
          );
        }
      } finally {
        llm.dispose();
      }

      results.add(
          BenchmarkModelResult(modelPath: modelPath, cases: caseResults));
    }

    onProgress?.call(
      BenchmarkProgress(
        totalModels: modelPaths.length,
        totalCasesPerModel: totalCases,
        totalRuns: totalRuns,
        completedRuns: completedRuns,
        currentModelIndex:
            modelPaths.isEmpty ? 0 : modelPaths.length - 1,
        currentCaseIndex: totalCases == 0 ? 0 : totalCases - 1,
        currentModelPath: modelPaths.isEmpty ? '' : modelPaths.last,
        currentCaseName:
            benchmarkCases.isEmpty ? '' : benchmarkCases.last.name,
      ),
    );

    return results;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool _intentMatches(String got, String expected) {
    final g = got.toLowerCase().trim();
    final e = expected.toLowerCase().trim();
    if (g == e) return true;
    // Allow note <-> task fuzzy match (no time = note)
    if ({g, e}.containsAll({'note', 'task'})) return true;
    return false;
  }

  _CheckResult _checkTitleLanguage(String? title, BenchmarkCase testCase) {
    return _checkTitleLanguageForItem(title, testCase.expectedItems.first);
  }

  _CheckResult _checkTitleLanguageForItem(String? title, ExpectedItem item) {
    if (item.titleLanguageKeywords.isEmpty) {
      return const _CheckResult(passed: true, detail: 'no keyword check');
    }
    if (title == null || title.isEmpty) {
      return const _CheckResult(
        passed: false,
        detail: 'no title in output',
      );
    }

    final lower = title.toLowerCase();
    final matched = <String>[];
    for (final keyword in item.titleLanguageKeywords) {
      if (lower.contains(keyword.toLowerCase())) {
        matched.add(keyword);
      }
    }

    final passed = matched.isNotEmpty;
    final detail = passed
        ? 'found ${matched.join(", ")} in "$title"'
        : 'none of [${item.titleLanguageKeywords.join(", ")}] found in "$title"';

    return _CheckResult(passed: passed, detail: detail);
  }

  _CheckResult _checkTimeResolution(
    String? timeExpr,
    BenchmarkCase testCase,
    TimeExpressionResolver resolver,
  ) {
    return _checkTimeResolutionForItem(
        timeExpr, testCase.expectedItems.first, resolver);
  }

  _CheckResult _checkTimeResolutionForItem(
    String? timeExpr,
    ExpectedItem item,
    TimeExpressionResolver resolver,
  ) {
    if (item.expectedDateTime == null) {
      return const _CheckResult(passed: true, detail: 'no time check');
    }
    if (timeExpr == null || timeExpr.isEmpty) {
      return const _CheckResult(
        passed: false,
        detail: 'no time expression to resolve',
      );
    }

    final resolved = resolver.resolve(
      timeExpr,
      referenceDate: referenceTime,
    );

    if (resolved == null) {
      return _CheckResult(
        passed: false,
        detail: 'chrono failed to parse "$timeExpr"',
      );
    }

    final diff = resolved.dateTime
        .difference(item.expectedDateTime!)
        .inMinutes
        .abs();
    if (diff > item.toleranceMinutes) {
      return _CheckResult(
        passed: false,
        detail:
            'got ${resolved.dateTime}, expected ${item.expectedDateTime} '
            '(diff ${diff}min, tolerance ${item.toleranceMinutes}min)',
      );
    }

    return _CheckResult(
      passed: true,
      detail: '${resolved.dateTime} OK (via ${resolved.method})',
    );
  }
}

class _CheckResult {
  final bool passed;
  final String? detail;
  const _CheckResult({required this.passed, this.detail});
}
