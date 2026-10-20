import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:test/test.dart';

void main() {
  test('timers and alarms route without the LLM', () {
    for (final memo in [
      'Sätt en timer på tio minuter.',
      'sätt en timer på 10 minuter',
      'Set a timer for 5 minutes',
      'Timer 3 minuter',
      'Väck mig klockan sju',
      'Set an alarm for 6:30',
      'Ställ larmet på sex',
      'Timer på en timme och trettio minuter',
    ]) {
      expect(KeywordRouter.route(memo), 'timer_alarm', reason: memo);
    }
  });

  test('reminders and mixed memos go to the LLM router', () {
    for (final memo in [
      'Påminn mig om 10 minuter att jag ska gå ut',
      'Remind me to check the timer',
      'Set a timer for 5 minutes and buy milk',
      'Köp mjölk',
      'Timeren på ugnen är trasig och måste lagas',
    ]) {
      expect(KeywordRouter.route(memo), isNull, reason: memo);
    }
  });

  test('timer durations', () {
    const cases = {
      'Sätt en timer på tio minuter.': 600,
      'sätt en timer på 10 minuter': 600,
      'Timer 10min': 600,
      'Sätt en timer på tjugofem minuter': 1500,
      'Timer på en och en halv timme': 5400,
      'Timer på en timme och trettio minuter': 5400,
      'Sätt en timer på en kvart': 900,
      'Timer en halvtimme': 1800,
      'Starta en nedräkning på 90 sekunder': 90,
      'Set a timer for 5 minutes': 300,
      'Set a timer for twenty five minutes': 1500,
      'Set a timer for half an hour': 1800,
      'Set a timer for one and a half hours': 5400,
      'Set a timer for 1.5 hours': 5400,
    };
    cases.forEach((memo, seconds) {
      expect(KeywordRouter.timerSeconds(memo), seconds, reason: memo);
    });
  });

  test('no timer duration for alarms, reminders or missing durations', () {
    for (final memo in [
      'Väck mig klockan sju',
      'Påminn mig om 10 minuter att gå ut',
      'Sätt en timer',
      'Set a timer for 5 minutes and buy milk',
    ]) {
      expect(KeywordRouter.timerSeconds(memo), isNull, reason: memo);
    }
  });
}
