import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/ai/companion_voice_processor.dart';

void main() {
  test('headless processing uses the existing no-speech policy', () {
    for (final text in [
      '',
      '  ',
      '<|nospeech|> <|nospeech|>',
      '[Music]',
      '...',
    ]) {
      expect(
        () => requireCompanionSpeech(text),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'NO_SPEECH'),
        ),
      );
    }
    requireCompanionSpeech('Påminn mig att köpa mjölk i morgon.');
    requireCompanionSpeech('Start a timer for three minutes.');
  });
}
