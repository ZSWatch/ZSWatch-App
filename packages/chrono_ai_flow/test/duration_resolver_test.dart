import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:test/test.dart';

void main() {
  final resolver = TimeExpressionResolver();

  test('English durations', () {
    const cases = {
      '10 minutes': 600,
      '8 minutes': 480,
      '1.5 hours': 5400,
      '1 hour and 30 minutes': 5400,
      'half an hour': 1800,
      'an hour': 3600,
      '90 seconds': 90,
      '2 hrs': 7200,
      'an hour and a half': 5400,
      'one and a half hours': 5400,
      'ten minutes': 600,
      'twenty-five minutes': 1500,
      'twenty five minutes': 1500,
      'two hours and fifteen minutes': 8100,
    };
    cases.forEach((expression, seconds) {
      expect(resolver.resolveDuration(expression), seconds, reason: expression);
    });
  });

  test('no duration', () {
    expect(resolver.resolveDuration(''), isNull);
    expect(resolver.resolveDuration('tomorrow'), isNull);
  });

  test('timer with an English duration phrase parses', () {
    final result = const ChronoLlmParser().parse(
      '[{"intent":"timer","title":"","datetime_expression_original":"tio minuter","datetime_expression_english":"10 minutes"}]',
    );
    expect(result.extraction?.intent, 'timer');
    expect(result.extraction?.datetimeExpressionEnglish, '10 minutes');
  });
}
