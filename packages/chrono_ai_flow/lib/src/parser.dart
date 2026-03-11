import 'dart:convert';

import 'models.dart';

class ChronoLlmParser {
  const ChronoLlmParser();

  ChronoLlmParseResult parse(String raw) {
    final cleaned = sanitizeModelOutput(raw);
    final jsonStr = extractFirstJsonObject(cleaned);
    if (jsonStr == null) {
      return ChronoLlmParseResult(rawOutput: cleaned);
    }

    try {
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!parsed.containsKey('intent')) {
        return ChronoLlmParseResult(rawOutput: cleaned, parsedJson: jsonStr);
      }

      final intent = _normalizeIntent(parsed['intent'] as String?);
      final title = ((parsed['title'] ?? parsed['summary']) as String?)?.trim() ??
          '';
      final datetimeOriginal =
          (parsed['datetime_expression_original'] as String?)?.trim();
      final datetimeEnglish =
          (parsed['datetime_expression_english'] as String?)?.trim();

      return ChronoLlmParseResult(
        rawOutput: cleaned,
        parsedJson: jsonStr,
        extraction: ChronoLlmExtraction(
          intent: intent,
          title: title,
          datetimeExpressionOriginal:
              (datetimeOriginal?.isNotEmpty ?? false) ? datetimeOriginal : null,
          datetimeExpressionEnglish:
              (datetimeEnglish?.isNotEmpty ?? false) ? datetimeEnglish : null,
        ),
      );
    } catch (_) {
      return ChronoLlmParseResult(rawOutput: cleaned, parsedJson: jsonStr);
    }
  }

  String sanitizeModelOutput(String raw) {
    return raw
        .replaceAll('<|im_end|>', '')
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .replaceAll(RegExp(r'<think>.*', dotAll: true), '')
        .trim();
  }

  String? extractFirstJsonObject(String raw) {
    final cleaned = sanitizeModelOutput(raw);
    final start = cleaned.indexOf('{');
    if (start == -1) {
      return null;
    }

    var depth = 0;
    var inString = false;
    var escaping = false;

    for (var i = start; i < cleaned.length; i++) {
      final char = cleaned[i];

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

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return cleaned.substring(start, i + 1);
        }
      }
    }

    return null;
  }

  String normalizeIntent(String? rawIntent) => _normalizeIntent(rawIntent);

  bool shouldRetryInvalidChronoOutput(String raw) {
    final parsed = parse(raw);
    final extraction = parsed.extraction;
    if (parsed.parsedJson == null) {
      return true;
    }
    if (extraction == null) {
      return true;
    }
    if (extraction.intent.trim().isEmpty) {
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
