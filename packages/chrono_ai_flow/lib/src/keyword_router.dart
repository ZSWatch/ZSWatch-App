/// Handles memos that clearly ask for a timer or alarm without trusting the LLM.
///
/// Small models misroute non-English timers to "voice_memo", where the
/// classify prompt has no timer type and they become reminders. They also
/// return "[]" or copy example durations for "tio minuter".
class KeywordRouter {
  static final _timer = RegExp(
    r'\b(timer|timern|nedräkning|countdown)\b',
    caseSensitive: false,
    unicode: true,
  );

  static final _alarm = RegExp(
    r'\b(alarm|alarmet|larm|larmet|väckarklocka|väck mig|wake me)\b',
    caseSensitive: false,
    unicode: true,
  );

  // Asking to be reminded of something is a reminder, even with a duration.
  // "och"/"and" adds a second item, except inside a duration.
  static final _task = RegExp(
    r'\b(remind|reminder|påminn|påminnelse|påminna)\b|'
    r'\b(och|and)\b(?!\s+(en|a)\s+(halv|half)\b)'
    r'(?!\s+\S+\s+(sekund|minut|timm|second|minute|hour))',
    caseSensitive: false,
    unicode: true,
  );

  /// "timer_alarm" when the memo is clearly only a timer or alarm, else null.
  static String? route(String transcript) {
    if (!_timer.hasMatch(transcript) && !_alarm.hasMatch(transcript)) {
      return null;
    }
    if (_task.hasMatch(transcript)) return null;
    return 'timer_alarm';
  }

  /// Duration of a memo that only sets a timer, e.g. "Sätt en timer på tio
  /// minuter" = 600. Null when it is not such a memo or has no duration.
  static int? timerSeconds(String transcript) {
    if (route(transcript) == null || !_timer.hasMatch(transcript)) return null;
    if (_alarm.hasMatch(transcript)) return null;
    final words = transcript
        .toLowerCase()
        .replaceAllMapped(RegExp(r'(\d)([^\d\s.,])'), (m) => '${m[1]} ${m[2]}')
        .split(RegExp(r'[^\p{L}\d.,]+', unicode: true))
        .map((w) => w.replaceAll(RegExp(r'[.,]$'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    double? pending;
    var total = 0.0;
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final unit = _units[word];
      final number = _number(word);
      if (unit != null) {
        if (pending != null || unit >= 900) total += (pending ?? 1) * unit;
        pending = null;
      } else if (number != null) {
        // "twenty five" and "tjugo fem".
        pending =
            pending != null && pending % 10 == 0 && pending >= 20 && number < 10
            ? pending + number
            : number;
      } else if ((word == 'och' || word == 'and') &&
          i + 2 < words.length &&
          (words[i + 2] == 'halv' || words[i + 2] == 'half')) {
        pending = (pending ?? 0) + 0.5;
        i += 2;
      } else if (word == 'halv' || word == 'half') {
        pending = (pending ?? 1) * 0.5;
        if (i + 1 < words.length &&
            (words[i + 1] == 'an' || words[i + 1] == 'a'))
          i++;
      } else {
        pending = null;
      }
    }
    final seconds = total.round();
    return seconds > 0 ? seconds : null;
  }

  static const _units = {
    'sekund': 1,
    'sekunder': 1,
    'sekunden': 1,
    'second': 1,
    'seconds': 1,
    'sec': 1,
    'secs': 1,
    's': 1,
    'minut': 60,
    'minuter': 60,
    'minuten': 60,
    'minute': 60,
    'minutes': 60,
    'min': 60,
    'mins': 60,
    'm': 60,
    'timme': 3600,
    'timmar': 3600,
    'timma': 3600,
    'timmen': 3600,
    'tim': 3600,
    'hour': 3600,
    'hours': 3600,
    'h': 3600,
    'kvart': 900,
    'halvtimme': 1800,
    'halvtimma': 1800,
  };

  static const _ones = {
    'en': 1,
    'ett': 1,
    'två': 2,
    'tre': 3,
    'fyra': 4,
    'fem': 5,
    'sex': 6,
    'sju': 7,
    'åtta': 8,
    'nio': 9,
    'tio': 10,
    'elva': 11,
    'tolv': 12,
    'tretton': 13,
    'fjorton': 14,
    'femton': 15,
    'sexton': 16,
    'sjutton': 17,
    'arton': 18,
    'nitton': 19,
    'a': 1,
    'an': 1,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
  };

  static const _tens = {
    'tjugo': 20,
    'trettio': 30,
    'fyrtio': 40,
    'femtio': 50,
    'sextio': 60,
    'sjuttio': 70,
    'åttio': 80,
    'nittio': 90,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  static double? _number(String word) {
    final digits = double.tryParse(word.replaceAll(',', '.'));
    if (digits != null) return digits;
    final one = _ones[word] ?? _tens[word];
    if (one != null) return one.toDouble();
    // "tjugofem"
    for (final MapEntry(key: tens, value: value) in _tens.entries) {
      final rest = word.startsWith(tens)
          ? _ones[word.substring(tens.length)]
          : null;
      if (rest != null && rest < 10) return (value + rest).toDouble();
    }
    return null;
  }
}
