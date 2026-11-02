import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:test/test.dart';

void main() {
  final pipeline = ChronoExtractionPipeline();

  test('the section goes before the current time in both templates', () {
    for (final template in [
      ChronoPromptTemplate.defaultTemplate,
      ChronoPromptTemplate.compactTemplate,
    ]) {
      final prompt = ShoppingIntent.addTo(template);
      expect(
        prompt.indexOf('SHOPPING LIST'),
        lessThan(prompt.indexOf('Current datetime:')),
      );
      expect(
        prompt,
        contains(ChronoPromptTemplate.promptPlaceholderTranscript),
      );
    }
    expect(
      () => ShoppingIntent.addTo(ChronoPromptTemplate.routerTemplate),
      throwsArgumentError,
    );
  });

  test('shopping items keep quantities and sit beside other intents', () {
    final items = pipeline.extract(
      '[{"intent":"shopping","title":"","items":[" två liter mjölk","ägg"],'
      '"datetime_expression_original":null,"datetime_expression_english":null},'
      '{"intent":"reminder","title":"ring Anna","datetime_expression_original":"imorgon klockan 9",'
      '"datetime_expression_english":"tomorrow at 9"}]',
    );
    expect(items.first.intent, 'shopping');
    expect(items.first.items, ['två liter mjölk', 'ägg']);
    expect(items.last.intent, 'reminder');
  });

  test('a shopping item without valid products is dropped', () {
    for (final items in ['[]', '["mjölk", 3]', '[""]', 'null', '"mjölk"']) {
      expect(
        pipeline.extract(
          '[{"intent":"shopping","title":"","items":$items,'
          '"datetime_expression_original":null,"datetime_expression_english":null}]',
        ),
        isEmpty,
        reason: items,
      );
    }
  });

  test('products from a prompt example are detected as copied', () {
    const raw =
        '[{"intent":"shopping","title":"","items":["två paket kaffe"],'
        '"datetime_expression_original":null,"datetime_expression_english":null}]';
    expect(pipeline.copiedFromExamples(raw, 'Ring Anna'), isTrue);
    expect(pipeline.copiedFromExamples(raw, 'Köp två paket kaffe'), isFalse);
  });
}
