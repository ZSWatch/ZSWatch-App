import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:test/test.dart';

void main() {
  final pipeline = ChronoExtractionPipeline();

  test('timer seconds come from the English duration', () {
    final items = pipeline.extract(
      '[{"intent":"timer","title":"","datetime_expression_original":"tio minuter","datetime_expression_english":"10 minutes","duration_seconds":480}]',
    );
    expect(items.single.durationSeconds, 600);
  });

  test('empty notes are dropped', () {
    expect(
      pipeline.extract(
        '[{"intent":"note","title":"","datetime_expression_original":null,"datetime_expression_english":null}]',
      ),
      isEmpty,
    );
  });

  test('a reminder without a time is a note', () {
    final item = pipeline
        .extract(
          '[{"intent":"event","title":"boka tid hos frisören","datetime_expression_original":null,"datetime_expression_english":null}]',
        )
        .single;
    expect(item.intent, 'note');
  });

  test('a note with a time is a reminder', () {
    final item = pipeline
        .extract(
          '[{"intent":"note","title":"bericht","datetime_expression_original":"bis Freitag um 17 Uhr","datetime_expression_english":"by Friday at 5 pm"}]',
        )
        .single;
    expect(item.intent, 'reminder');
    expect(item.datetimeExpressionEnglish, 'by Friday at 5 pm');
  });

  test('a title not from the memo is a copied example', () {
    const raw =
        '[{"intent":"note","title":"köp bröd","datetime_expression_original":null,"datetime_expression_english":null}]';
    expect(pipeline.copiedFromExamples(raw, '(music)'), isTrue);
    expect(pipeline.copiedFromExamples(raw, 'Köp bröd och mjölk'), isFalse);
  });

  test('a copied example is detected', () {
    const copied =
        '[{"intent":"timer","title":"","datetime_expression_original":"tre minuter","datetime_expression_english":"3 minutes"}]';
    expect(
      pipeline.copiedFromExamples(copied, 'Set a timer for 8 minutes'),
      isTrue,
    );
    expect(
      pipeline.copiedFromExamples(copied, 'Timer på tre minuter'),
      isFalse,
    );
  });

  group('times', () {
    final now = DateTime(2026, 3, 11, 10, 15);
    ChronoLlmExtraction item(String intent, String english) =>
        ChronoLlmExtraction(
          intent: intent,
          title: 'x',
          datetimeExpressionOriginal: english,
          datetimeExpressionEnglish: english,
        );
    DateTime? at(String intent, String english) =>
        pipeline.resolveTimes([item(intent, english)], now).single?.dateTime;

    test('clock times without am/pm are in the daytime', () {
      expect(at('reminder', 'tomorrow at 4:30'), DateTime(2026, 3, 12, 16, 30));
      expect(at('reminder', 'at 3'), DateTime(2026, 3, 11, 15));
      expect(at('reminder', 'tomorrow at 9'), DateTime(2026, 3, 12, 9));
      expect(at('reminder', 'tomorrow at 5 am'), DateTime(2026, 3, 12, 5));
      expect(at('alarm', 'at 6:30'), DateTime(2026, 3, 12, 6, 30));
    });

    test('English clock phrases', () {
      expect(at('alarm', 'half past 7'), DateTime(2026, 3, 12, 7, 30));
      expect(at('event', "Tuesday at 8 o'clock"), DateTime(2026, 3, 17, 8));
      expect(
        at('reminder', 'tomorrow at quarter to 3'),
        DateTime(2026, 3, 12, 14, 45),
      );
      expect(at('alarm', "7 o'clock"), DateTime(2026, 3, 12, 7));
      expect(at('reminder', '8'), DateTime(2026, 3, 11, 20));
      expect(at('event', 'on the 24th at 6 pm'), DateTime(2026, 3, 24, 18));
      expect(at('event', 'the 2nd at 9 am'), DateTime(2026, 4, 2, 9));
    });

    test('a later time-only item keeps the earlier date', () {
      final times = pipeline.resolveTimes([
        item('reminder', 'tomorrow at 8 am'),
        item('reminder', 'at 3 pm'),
      ], now);
      expect(times.last?.dateTime, DateTime(2026, 3, 12, 15));
    });
  });
}
