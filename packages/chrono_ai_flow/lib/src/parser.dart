import 'dart:convert';

import 'models.dart';

class ChronoLlmParser {
  const ChronoLlmParser();

  ChronoLlmParseResult parse(String raw) {
    final cleaned = sanitizeModelOutput(raw);

    // Try array first (new format), then fall back to single object
    final arrayStr = extractFirstJsonArray(cleaned);
    if (arrayStr != null) {
      try {
        final list = jsonDecode(arrayStr) as List<dynamic>;
        final extractions = <ChronoLlmExtraction>[];
        for (final item in list.whereType<Map<String, dynamic>>()) {
          final extraction = _parseOneObject(item);
          if (extraction != null) {
            extractions.add(extraction);
          }
        }
        if (extractions.isNotEmpty) {
          return ChronoLlmParseResult(
            rawOutput: cleaned,
            parsedJson: arrayStr,
            extraction: extractions.first,
            extractions: extractions,
          );
        }
      } catch (_) {
        // Fall through to single-object parsing
      }
    }

    final jsonStr = extractFirstJsonObject(cleaned);
    if (jsonStr == null) {
      return ChronoLlmParseResult(rawOutput: cleaned);
    }

    try {
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final extraction = _parseOneObject(parsed);
      if (extraction == null) {
        return ChronoLlmParseResult(rawOutput: cleaned, parsedJson: jsonStr);
      }

      return ChronoLlmParseResult(
        rawOutput: cleaned,
        parsedJson: jsonStr,
        extraction: extraction,
        extractions: [extraction],
      );
    } catch (_) {
      return ChronoLlmParseResult(rawOutput: cleaned, parsedJson: jsonStr);
    }
  }

  ChronoLlmExtraction? _parseOneObject(Map<String, dynamic> parsed) {
    if (!parsed.containsKey('intent')) {
      return null;
    }

    final intent = _normalizeIntent(parsed['intent'] as String?);
    final title =
        ((parsed['title'] ?? parsed['summary']) as String?)?.trim() ?? '';
    final datetimeOriginal =
        (parsed['datetime_expression_original'] as String?)?.trim();
    final datetimeEnglish =
        (parsed['datetime_expression_english'] as String?)?.trim();

    return ChronoLlmExtraction(
      intent: intent,
      title: title,
      datetimeExpressionOriginal:
          (datetimeOriginal?.isNotEmpty ?? false) ? datetimeOriginal : null,
      datetimeExpressionEnglish:
          (datetimeEnglish?.isNotEmpty ?? false) ? datetimeEnglish : null,
    );
  }

  String sanitizeModelOutput(String raw) {
    return raw
        .replaceAll('<|im_end|>', '')
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .replaceAll(RegExp(r'<think>.*', dotAll: true), '')
        .trim();
  }

  String? extractFirstJsonArray(String raw) {
    final cleaned = sanitizeModelOutput(raw);
    final start = cleaned.indexOf('[');
    if (start == -1) {
      return null;
    }
    return _extractBalanced(cleaned, start, '[', ']');
  }

  String? extractFirstJsonObject(String raw) {
    final cleaned = sanitizeModelOutput(raw);
    final start = cleaned.indexOf('{');
    if (start == -1) {
      return null;
    }
    return _extractBalanced(cleaned, start, '{', '}');
  }

  String? _extractBalanced(String text, int start, String open, String close) {
    var depth = 0;
    var inString = false;
    var escaping = false;

    for (var i = start; i < text.length; i++) {
      final char = text[i];

      if (escaping) {
        escaping = false;
        continue;
      }

      if (char == '\\' && inString) {
        escaping = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        continue;
      }

      if (inString) {
        continue;
      }

      if (char == open) {
        depth++;
      } else if (char == close) {
        depth--;
        if (depth == 0) {
          return text.substring(start, i + 1);
        }
      }
    }

    return null;
  }

  String normalizeIntent(String? rawIntent) => _normalizeIntent(rawIntent);

  bool shouldRetryInvalidChronoOutput(String raw) {
    final parsed = parse(raw);
    if (parsed.parsedJson == null) {
      return true;
    }
    if (parsed.extractions.isEmpty) {
      return true;
    }
    if (parsed.extractions.first.intent.trim().isEmpty) {
      return true;
    }
    return false;
  }

  String _normalizeIntent(String? rawIntent) {
    switch ((rawIntent ?? '').trim().toLowerCase()) {
      case 'event':
      case 'meeting':
      case 'calendar_event':
        return 'event';
      case 'reminder':
      case 'task':
      case 'todo':
        return 'reminder';
      default:
        return 'note';
    }
  }
}
