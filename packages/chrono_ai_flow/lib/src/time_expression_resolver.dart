import 'package:chrono_dart/chrono_dart.dart';

import 'models.dart';

class TimeExpressionResolver {
  static final _weekdayNames = RegExp(
    r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
  );

  static const _weekdayMap = {
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  ResolvedTime? resolve(String expression, {DateTime? referenceDate}) {
    if (expression.trim().isEmpty) return null;

    final ref = referenceDate ?? DateTime.now();
    final normalized = _normalize(expression);

    final specific = _specificPatterns(normalized, ref);
    if (specific != null) {
      return ResolvedTime(dateTime: specific, method: 'regex');
    }

    try {
      final results = Chrono.parse(
        normalized,
        ref: ref,
        option: ParsingOption(forwardDate: true),
      );
      if (results.isNotEmpty) {
        var resolved = results.first.date();
        if (resolved.isUtc) resolved = resolved.toLocal();

        final weekdayMatch = _weekdayNames.firstMatch(normalized);
        if (weekdayMatch != null) {
          final mentionedDay = _weekdayMap[weekdayMatch.group(1)!]!;

          if (resolved.weekday != mentionedDay) {
            var daysUntil = mentionedDay - ref.weekday;
            if (daysUntil <= 0) daysUntil += 7;
            resolved = DateTime(
              ref.year,
              ref.month,
              ref.day + daysUntil,
              resolved.hour,
              resolved.minute,
              resolved.second,
            );
            return ResolvedTime(dateTime: resolved, method: 'chrono+adjusted');
          }

          if (resolved.isBefore(ref)) {
            resolved = resolved.add(const Duration(days: 7));
            return ResolvedTime(dateTime: resolved, method: 'chrono+adjusted');
          }

          // "on Wednesday" spoken on a Wednesday → chrono gives today,
          // but the user likely means next week's occurrence.
          if (mentionedDay == ref.weekday &&
              resolved.year == ref.year &&
              resolved.month == ref.month &&
              resolved.day == ref.day &&
              !normalized.contains('today') &&
              !normalized.contains('this')) {
            resolved = resolved.add(const Duration(days: 7));
            return ResolvedTime(dateTime: resolved, method: 'chrono+adjusted');
          }

          if (normalized.contains('next')) {
            final daysFromRef = resolved.difference(ref).inDays;
            // "next <weekday>" means the occurrence in the following
            // week. Days that haven't happened yet this week are
            // "ahead" — chrono may resolve them to this-week's date.
            final dayIsAheadInWeek = mentionedDay > ref.weekday;
            if (dayIsAheadInWeek && daysFromRef < 7) {
              // Chrono gave this week's occurrence — push to next week.
              resolved = resolved.add(const Duration(days: 7));
              return ResolvedTime(
                dateTime: resolved,
                method: 'chrono+adjusted',
              );
            }
            if (daysFromRef > 13) {
              // Chrono jumped too far — pull back one week.
              resolved = resolved.subtract(const Duration(days: 7));
              return ResolvedTime(
                dateTime: resolved,
                method: 'chrono+adjusted',
              );
            }
          }
        }

        return ResolvedTime(dateTime: resolved, method: 'chrono');
      }
    } catch (_) {
      // Ignore and continue to regex fallbacks.
    }

    final regexResult = _generalRegex(normalized, ref);
    if (regexResult != null) {
      return ResolvedTime(dateTime: regexResult, method: 'regex');
    }

    return null;
  }

  String _normalize(String expression) {
    var s = expression.trim().toLowerCase();

    const numberWords = {
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
      'eleven': '11',
      'twelve': '12',
      'thirteen': '13',
      'fourteen': '14',
      'fifteen': '15',
      'twenty': '20',
      'thirty': '30',
      'forty': '40',
      'fifty': '50',
    };

    for (final entry in numberWords.entries) {
      s = s.replaceAllMapped(RegExp('\\b${entry.key}\\b'), (_) => entry.value);
    }

    return s;
  }

  DateTime? _specificPatterns(String expr, DateTime ref) {
    final dayAfterTomorrow = RegExp(
      r'\bday\s+after\s+tomorrow\b'
      r'(?:\s+(?:morning|afternoon|evening))?'
      r'(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?',
    ).firstMatch(expr);
    if (dayAfterTomorrow != null) {
      var hour = int.tryParse(dayAfterTomorrow.group(1) ?? '') ?? 9;
      final minute = int.tryParse(dayAfterTomorrow.group(2) ?? '') ?? 0;
      final ampm = dayAfterTomorrow.group(3);
      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;
      if (expr.contains('morning') && dayAfterTomorrow.group(1) == null) {
        hour = 8;
      }
      return DateTime(ref.year, ref.month, ref.day + 2, hour, minute);
    }

    final tonight = RegExp(
      r'\btonight\b(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?',
    ).firstMatch(expr);
    if (tonight != null) {
      var hour = int.tryParse(tonight.group(1) ?? '') ?? 20;
      final minute = int.tryParse(tonight.group(2) ?? '') ?? 0;
      final ampm = tonight.group(3);
      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == null && hour < 12) hour += 12;
      return DateTime(ref.year, ref.month, ref.day, hour, minute);
    }

    final thisAfternoon = RegExp(
      r'\bthis\s+afternoon\b(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(pm)?)?',
    ).firstMatch(expr);
    if (thisAfternoon != null) {
      var hour = int.tryParse(thisAfternoon.group(1) ?? '') ?? 14;
      final minute = int.tryParse(thisAfternoon.group(2) ?? '') ?? 0;
      if (hour < 12) hour += 12;
      return DateTime(ref.year, ref.month, ref.day, hour, minute);
    }

    return null;
  }

  DateTime? _generalRegex(String expr, DateTime ref) {
    final inMinutes = RegExp(r'\bin\s+(\d+)\s+minutes?\b').firstMatch(expr);
    if (inMinutes != null) {
      final minutes = int.tryParse(inMinutes.group(1)!);
      if (minutes != null) return ref.add(Duration(minutes: minutes));
    }

    final inHours = RegExp(r'\bin\s+(\d+)\s+hours?\b').firstMatch(expr);
    if (inHours != null) {
      final hours = int.tryParse(inHours.group(1)!);
      if (hours != null) return ref.add(Duration(hours: hours));
    }

    final inDays = RegExp(r'\bin\s+(\d+)\s+days?\b').firstMatch(expr);
    if (inDays != null) {
      final days = int.tryParse(inDays.group(1)!);
      if (days != null) return ref.add(Duration(days: days));
    }

    if (RegExp(r'\bin\s+half\s+an?\s+hour\b').hasMatch(expr)) {
      return ref.add(const Duration(minutes: 30));
    }

    if (RegExp(r'\btomorrow\b').hasMatch(expr) &&
        !RegExp(r'\bat\b|\d+\s*(am|pm|:\d)').hasMatch(expr)) {
      return DateTime(ref.year, ref.month, ref.day + 1, 9, 0);
    }

    return null;
  }
}
