import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/ai/companion_voice_processor.dart';

void main() {
  test('cancellation before binding prevents work', () async {
    final cancellation = CompanionVoiceCancellation();
    await cancellation.cancel();
    expect(cancellation.isCancelled, isTrue);
    expect(
      () => cancellation.bind(() async {}),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'CANCELLED'),
      ),
    );
    // This request is intentionally invalid: cancellation must win before any
    // platform/file/model access or input validation.
    await expectLater(
      processCompanionVoiceRecording(
        {},
        cancellation: cancellation,
        saveTranscript: (_) async {},
      ),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'CANCELLED'),
      ),
    );
  });

  test(
    'cancellation signals one active abort and cannot start another phase',
    () async {
      final cancellation = CompanionVoiceCancellation();
      var calls = 0;
      cancellation.bind(() async {
        calls++;
      });
      await cancellation.cancel();
      await cancellation.cancel();
      expect(calls, 1);
      expect(
        cancellation.check,
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'CANCELLED'),
        ),
      );
    },
  );

  test('completed execution is detached before later cancellation', () async {
    final cancellation = CompanionVoiceCancellation();
    var calls = 0;
    cancellation.bind(() async {
      calls++;
    });
    cancellation.unbind();
    await cancellation.cancel();
    expect(calls, 0);
  });

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
