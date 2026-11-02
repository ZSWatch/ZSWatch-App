import 'dart:convert';

import 'package:llm_integrations/llm_integrations.dart';
import 'package:test/test.dart';

void main() {
  const extractor = ShoppingExtraction();
  const transcript = 'Lägg två liter havremjölk och 6 ägg på listan Stugan.';
  const raw =
      '[{"list_name":"Stugan","items":["två liter havremjölk","6 ägg"]}]';

  test('keeps quantities, units, language and explicit target for review', () {
    final result = extractor.parse(raw, transcript: transcript);
    expect(result.isValid, isTrue);
    expect(result.drafts.single.listName, 'Stugan');
    expect(result.drafts.single.items, ['två liter havremjölk', '6 ägg']);
    expect(result.drafts.single.toJson(), jsonDecode(raw)[0]);
    expect(
      () => result.drafts.single.items.add('mjölk'),
      throwsUnsupportedError,
    );
  });

  test('accepts complete code fences and harmless whitespace differences', () {
    final result = extractor.parse(
      '```json\n$raw\n```',
      transcript: transcript.replaceFirst('två liter', 'två\n liter'),
    );
    expect(result.isValid, isTrue);
  });

  test('an empty suggestion differs from a failed extraction', () {
    final empty = extractor.parse('[]', transcript: 'Ring Anna.');
    final broken = extractor.parse('[', transcript: 'Ring Anna.');
    expect(empty.isValid, isTrue);
    expect(empty.drafts, isEmpty);
    expect(broken.isValid, isFalse);
    expect(broken.drafts, isEmpty);
  });

  test('does not salvage truncated JSON, trailing text or a single object', () {
    for (final broken in [
      raw.substring(0, raw.length - 1),
      '$raw do this',
      '{}',
    ]) {
      expect(extractor.parse(broken, transcript: transcript).isValid, isFalse);
    }
  });

  test('rejects invented products and a shortened compound product', () {
    for (final item in ['mjölk', 'bananer', '2 liter havremjölk']) {
      final result = extractor.parse(
        jsonEncode([
          {
            'list_name': null,
            'items': [item],
          },
        ]),
        transcript: transcript,
      );
      expect(result.isValid, isFalse, reason: item);
    }
  });

  test('rejects invented list names, IDs and executable extra fields', () {
    for (final group in [
      {
        'list_name': 'Hemma',
        'items': ['6 ägg'],
      },
      {
        'list_name': 42,
        'items': ['6 ägg'],
      },
      {
        'list_name': null,
        'items': ['6 ägg'],
        'url': 'https://example.org',
      },
      {
        'list_name': null,
        'items': ['6 ägg'],
        'operation': 'delete',
      },
    ]) {
      expect(
        extractor.parse(jsonEncode([group]), transcript: transcript).isValid,
        isFalse,
      );
    }
  });

  test('malformed or mixed-validity batches expose no partial draft', () {
    for (final broken in [
      '[{"list_name":null,"items":["6 ägg"]},null]',
      '[{"list_name":null,"items":["6 ägg",1]}]',
      '[{"list_name":null,"items":[]}]',
      '[{"items":["6 ägg"]}]',
      '[{"list_name":"","items":["6 ägg"]}]',
    ]) {
      final result = extractor.parse(broken, transcript: transcript);
      expect(result.isValid, isFalse);
      expect(result.drafts, isEmpty);
    }
  });

  test('caps batch size and response size', () {
    final tooMany = jsonEncode([
      {'list_name': null, 'items': List.filled(65, '6 ägg')},
    ]);
    expect(extractor.parse(tooMany, transcript: transcript).isValid, isFalse);
    expect(
      extractor.parse(' ' * 24001, transcript: transcript).isValid,
      isFalse,
    );
  });

  test('keeps repeated products and independent named lists', () {
    final result = extractor.parse(
      '[{"list_name":"Stugan","items":["kaffe","kaffe"]},'
      '{"list_name":"Hemma","items":["te"]}]',
      transcript: 'Lägg kaffe och kaffe på Stugan och te på Hemma.',
    );
    expect(result.isValid, isTrue);
    expect(result.drafts[0].items, ['kaffe', 'kaffe']);
    expect(result.drafts[1].listName, 'Hemma');
  });

  test('validates tool calls and normalizes generic list labels', () {
    final result = extractor.parseToolCalls([
      {
        'function': {
          'name': ShoppingExtraction.toolName,
          'arguments': jsonEncode({
            'lists': [
              {
                'list_name': 'inköpslistan',
                'items': ['6 ägg'],
              },
            ],
          }),
        },
      },
    ], transcript: transcript);
    expect(result.isValid, isTrue);
    expect(result.drafts.single.listName, isNull);
    expect(result.drafts.single.items, ['6 ägg']);
  });

  test('rejects extra tool calls and invented items as an entire proposal', () {
    final call = {
      'function': {
        'name': ShoppingExtraction.toolName,
        'arguments': '{"lists":[{"list_name":null,"items":["bananer"]}]}',
      },
    };
    expect(
      extractor.parseToolCalls([call], transcript: transcript).isValid,
      isFalse,
    );
    expect(
      extractor.parseToolCalls([call, call], transcript: transcript).drafts,
      isEmpty,
    );
  });

  test(
    'model receives the full transcript as data, not a shortened title',
    () async {
      var calls = 0;
      final result = await extractor.extract(
        transcript,
        complete: (prompt) async {
          calls++;
          expect(prompt, contains(jsonEncode(transcript)));
          return raw;
        },
      );
      expect(calls, 1);
      expect(result.drafts.single.items.length, 2);
    },
  );

  test('noise skips model invocation', () async {
    for (final memo in ['', '[BLANK_AUDIO]', '[NO SPEECH DETECTED]', '...']) {
      final result = await extractor.extract(
        memo,
        complete: (_) async {
          fail('No-speech text must not invoke the model');
        },
      );
      expect(result.isValid, isTrue);
      expect(result.drafts, isEmpty);
    }
  });

  test(
    'oversize transcripts fail before inference instead of truncating items',
    () {
      expect(
        () => extractor.extract('a' * 8001, complete: (_) async => raw),
        throwsFormatException,
      );
    },
  );
}
