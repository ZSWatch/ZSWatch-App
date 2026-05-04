import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:test/test.dart';

void main() {
  const parser = ChronoLlmParser();

  group('Single object (backward compat)', () {
    test('parses single JSON object with intent', () {
      const raw =
          '{"intent":"reminder","title":"buy milk","datetime_expression_original":"tomorrow at 10 am","datetime_expression_english":"tomorrow at 10 am"}';
      final result = parser.parse(raw);
      expect(result.extraction, isNotNull);
      expect(result.extractions, hasLength(1));
      expect(result.extraction!.intent, 'reminder');
      expect(result.extraction!.title, 'buy milk');
      expect(result.extraction!.datetimeExpressionEnglish, 'tomorrow at 10 am');
    });

    test('wraps single object in extractions list', () {
      const raw =
          '{"intent":"note","title":"buy bread","datetime_expression_original":null,"datetime_expression_english":null}';
      final result = parser.parse(raw);
      expect(result.extractions, hasLength(1));
      expect(result.extractions.first.intent, 'note');
      expect(result.extractions.first.title, 'buy bread');
    });
  });

  group('Array output (multi-event)', () {
    test('parses JSON array with multiple items', () {
      const raw =
          '[{"intent":"reminder","title":"pick up dog","datetime_expression_original":"tomorrow at 5 pm","datetime_expression_english":"tomorrow at 5 pm"},'
          '{"intent":"reminder","title":"turn off lights","datetime_expression_original":"at 9","datetime_expression_english":"tomorrow at 9 pm"}]';
      final result = parser.parse(raw);
      expect(result.extractions, hasLength(2));
      expect(result.extraction!.title, 'pick up dog');
      expect(result.extractions[0].intent, 'reminder');
      expect(result.extractions[0].title, 'pick up dog');
      expect(
        result.extractions[0].datetimeExpressionEnglish,
        'tomorrow at 5 pm',
      );
      expect(result.extractions[1].intent, 'reminder');
      expect(result.extractions[1].title, 'turn off lights');
      expect(
        result.extractions[1].datetimeExpressionEnglish,
        'tomorrow at 9 pm',
      );
    });

    test('parses array with mixed intents', () {
      const raw =
          '[{"intent":"event","title":"tandläkare","datetime_expression_original":"den 15 mars klockan halv 10","datetime_expression_english":"March 15th at 9:30 am"},'
          '{"intent":"note","title":"handla mat","datetime_expression_original":null,"datetime_expression_english":null}]';
      final result = parser.parse(raw);
      expect(result.extractions, hasLength(2));
      expect(result.extractions[0].intent, 'event');
      expect(result.extractions[0].title, 'tandläkare');
      expect(result.extractions[1].intent, 'note');
      expect(result.extractions[1].title, 'handla mat');
      expect(result.extractions[1].datetimeExpressionOriginal, isNull);
    });

    test('parses single-item array', () {
      const raw =
          '[{"intent":"reminder","title":"buy milk","datetime_expression_original":"tomorrow","datetime_expression_english":"tomorrow"}]';
      final result = parser.parse(raw);
      expect(result.extractions, hasLength(1));
      expect(result.extraction!.intent, 'reminder');
      expect(result.extraction!.title, 'buy milk');
    });

    test('handles array with model prefix text', () {
      const raw =
          'Here is the JSON:\n[{"intent":"reminder","title":"call plumber","datetime_expression_original":"at 3 pm","datetime_expression_english":"at 3 pm"}]';
      final result = parser.parse(raw);
      expect(result.extractions, hasLength(1));
      expect(result.extractions.first.title, 'call plumber');
    });

    test('handles array with trailing model tokens', () {
      const raw =
          '[{"intent":"event","title":"dentist","datetime_expression_original":"Thursday at 9 am","datetime_expression_english":"Thursday at 9 am"}]<|im_end|>';
      final result = parser.parse(raw);
      expect(result.extractions, hasLength(1));
      expect(result.extractions.first.title, 'dentist');
    });
  });

  group('extractFirstJsonArray', () {
    test('extracts array from mixed text', () {
      const raw = 'prefix [{"a":1},{"b":2}] suffix';
      final result = parser.extractFirstJsonArray(raw);
      expect(result, '[{"a":1},{"b":2}]');
    });

    test('returns null when no array', () {
      const raw = '{"a":1}';
      final result = parser.extractFirstJsonArray(raw);
      expect(result, isNull);
    });

    test('handles nested brackets in strings', () {
      const raw = '[{"title":"array [test]"}]';
      final result = parser.extractFirstJsonArray(raw);
      expect(result, '[{"title":"array [test]"}]');
    });
  });

  group('shouldRetryInvalidChronoOutput', () {
    test('retries on empty output', () {
      expect(parser.shouldRetryInvalidChronoOutput(''), true);
    });

    test('does not retry on valid array', () {
      const raw =
          '[{"intent":"note","title":"test","datetime_expression_original":null,"datetime_expression_english":null}]';
      expect(parser.shouldRetryInvalidChronoOutput(raw), false);
    });

    test('does not retry on valid single object', () {
      const raw =
          '{"intent":"note","title":"test","datetime_expression_original":null,"datetime_expression_english":null}';
      expect(parser.shouldRetryInvalidChronoOutput(raw), false);
    });
  });

  group('intent normalization', () {
    test('normalizes task to reminder', () {
      const raw =
          '[{"intent":"task","title":"test","datetime_expression_original":null,"datetime_expression_english":null}]';
      final result = parser.parse(raw);
      expect(result.extractions.first.intent, 'reminder');
    });

    test('normalizes meeting to event', () {
      const raw =
          '[{"intent":"meeting","title":"test","datetime_expression_original":null,"datetime_expression_english":null}]';
      final result = parser.parse(raw);
      expect(result.extractions.first.intent, 'event');
    });
  });
}
