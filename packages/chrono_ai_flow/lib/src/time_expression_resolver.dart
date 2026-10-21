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

  static final _durationPart = RegExp(
    r'(\d+(?:\.\d+)?|an?)\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?)\b',
  );

  /// Seconds in an English duration such as "10 minutes", "1.5 hours" or
  /// "1 hour and 30 minutes". Null when there is no duration.
  int? resolveDuration(String expression) {
    final normalized = _englishNumbers(expression.toLowerCase())
        .replaceAll(RegExp(r'\bhalf an? hour\b'), '0.5 hours')
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?|an?)\s+and\s+a\s+half\s+(hour|minute)s?\b'),
          (m) => '${(double.tryParse(m[1]!) ?? 1) + 0.5} ${m[2]}s',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?|an?)\s+(hour|minute)s?\s+and\s+a\s+half\b'),
          (m) => '${(double.tryParse(m[1]!) ?? 1) + 0.5} ${m[2]}s',
        );
    var seconds = 0.0;
    for (final match in _durationPart.allMatches(normalized)) {
      final amount = double.tryParse(match[1]!) ?? 1;
      final unit = match[2]!;
      seconds +=
          amount *
          (unit.startsWith('h')
              ? 3600
              : unit.startsWith('m')
              ? 60
              : 1);
    }
    return seconds > 0 ? seconds.round() : null;
  }

  static const _ones = [
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'thirteen',
    'fourteen',
    'fifteen',
    'sixteen',
    'seventeen',
    'eighteen',
    'nineteen',
  ];
  static const _tens = [
    'twenty',
    'thirty',
    'forty',
    'fifty',
    'sixty',
    'seventy',
    'eighty',
    'ninety',
  ];

  /// "twenty-five minutes" -> "25 minutes".
  static String _englishNumbers(String text) => text.replaceAllMapped(
    RegExp(
      '\\b(?:(${_tens.join('|')})(?:[\\s-]+(${_ones.sublist(1, 10).join('|')}))?'
      '|(${_ones.join('|')}))\\b',
    ),
    (m) => m[3] != null
        ? '${_ones.indexOf(m[3]!)}'
        : '${(_tens.indexOf(m[1]!) + 2) * 10 + (m[2] == null ? 0 : _ones.indexOf(m[2]!))}',
  );

  /// [assumeDaytime]: a clock time from 1 to 7 without am/pm is in the
  /// afternoon ("at 3" is rarely 3 am). Not for alarms.
  ResolvedTime? resolve(
    String expression, {
    DateTime? referenceDate,
    bool assumeDaytime = false,
  }) {
    if (expression.trim().isEmpty) return null;

    final ref = referenceDate ?? DateTime.now();
    var normalized = _normalize(expression);
    if (assumeDaytime && !_dayPart.hasMatch(normalized)) {
      final onlyClock = RegExp(
        r'^(?:today\s+)?at\s+\d{1,2}(?::\d{2})?$',
      ).hasMatch(normalized);
      normalized = normalized.replaceAllMapped(_bareClock, (m) {
        final hour = int.parse(m[2]!);
        // A time-only "at 8" said at 10:15 means tonight, not tomorrow.
        final laterToday =
            onlyClock && hour < 12 && hour <= ref.hour && hour + 12 > ref.hour;
        return (hour >= 1 && hour <= 7) || laterToday ? '${m[0]} pm' : m[0]!;
      });
    }

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

  static final _dayPart = RegExp(
    r'\b(am|pm|a\.m\.|p\.m\.|morning|noon|midnight|night|evening|afternoon|tonight)\b',
  );

  /// "at 3", "at 4:30" or "4:30", not followed by am/pm.
  static final _bareClock = RegExp(
    r'(\bat\s+|\b(?=\d{1,2}:\d{2}))(\d{1,2})(:\d{2})?\b(?!\s*(?:am|pm|a\.m|p\.m|[:.]\d))',
  );

  String _normalize(String expression) {
    var s = _englishNumbers(expression.trim().toLowerCase())
        .replaceAllMapped(
          RegExp(r'\bhalf past (\d{1,2})\b'),
          (m) => '${m[1]}:30',
        )
        .replaceAllMapped(
          RegExp(r'\bquarter past (\d{1,2})\b'),
          (m) => '${m[1]}:15',
        )
        .replaceAllMapped(
          RegExp(r'\bquarter to (\d{1,2})\b'),
          (m) => '${(int.parse(m[1]!) + 10) % 12 + 1}:45',
        )
        .replaceAll(RegExp(r"\s*o'clock\b"), '');
    if (RegExp(r'^\d{1,2}(:\d{2})?$').hasMatch(s)) s = 'at $s';

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
