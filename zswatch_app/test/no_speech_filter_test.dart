import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/ai/voice_note_ai_pipeline.dart';

void main() {
  group('isNoSpeechTranscript', () {
    // ── Should be detected as no-speech ───────────────────────────────

    group('detects Whisper silence markers', () {
      for (final marker in [
        '[BLANK_AUDIO]',
        '[blank_audio]',
        '[NO SPEECH]',
        '<NO SPEECH>',
        '(no speech)',
        '[silence]',
        '<|nospeech|>',
        '[music]',
        '(music)',
      ]) {
        test('"$marker"', () {
          expect(VoiceNoteAiPipeline.isNoSpeechTranscript(marker), isTrue);
        });
      }
    });

    test('detects marker embedded in text', () {
      expect(
        VoiceNoteAiPipeline.isNoSpeechTranscript(
            'some text [BLANK_AUDIO] more'),
        isTrue,
      );
    });

    group('detects pure punctuation / symbols', () {
      for (final input in [
        '...',
        '. . .',
        '♪ ♪ ♪',
        '♪♪♪',
        ', , ,',
        '---',
        '  ...  ',
      ]) {
        test('"$input"', () {
          expect(VoiceNoteAiPipeline.isNoSpeechTranscript(input), isTrue);
        });
      }
    });

    test('detects whitespace-only', () {
      expect(VoiceNoteAiPipeline.isNoSpeechTranscript('   '), isTrue);
    });

    // ── Should NOT be detected as no-speech ──────────────────────────

    group('allows valid transcripts through', () {
      for (final input in [
        'Remind me to buy milk',
        'Set a timer for 5 minutes',
        'köp bröd',
        'Wecker auf 7 Uhr',
        'Meeting tomorrow at 10',
        'hmm I need to call the dentist',
        'ok',
        'yes',
        'Buy milk and eggs and bread',
        'Thank you for helping me with this project',
      ]) {
        test('"$input"', () {
          expect(VoiceNoteAiPipeline.isNoSpeechTranscript(input), isFalse);
        });
      }
    });
  });
}
