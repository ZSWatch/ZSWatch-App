import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:chrono_dart/chrono_dart.dart';

void main() {
  final r = TimeExpressionResolver();
  final ref = DateTime(2026, 3, 11, 10, 0);

  // Direct chrono test
  final chronoResult = Chrono.parse(
    'next friday at 5 pm',
    ref: ref,
    option: ParsingOption(forwardDate: true),
  );
  if (chronoResult.isNotEmpty) {
    final d = chronoResult.first.date();
    print(
      'chrono raw: $d weekday=${d.weekday} daysFromRef=${d.difference(ref).inDays}',
    );
  }

  final cases = [
    'next Friday at 5 PM',
    'next Tuesday at 2 pm',
    'next Monday at 10 am',
    'next Wednesday at 12 pm',
    'tomorrow at 3 pm',
    'klockan 15',
  ];

  for (final expr in cases) {
    final res = r.resolve(expr, referenceDate: ref);
    print('$expr -> ${res?.dateTime} (method: ${res?.method})');
  }
}
