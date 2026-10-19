import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/voice_memo/transcription_engine.dart';

void main() {
  test(
    'compact bilingual model uses multilingual weights and auto language',
    () {
      final info = TranscriptionModelCatalog.info(
        TranscriptionEngineType.whisperSmallMultilingualQ5,
      );
      expect(info.language, 'auto');
      expect(info.fileName, 'ggml-small-q5_1.bin');
      expect(Uri.parse(info.sourceUrl).pathSegments.last, info.fileName);
      expect(info.sourceUrl, contains('/ggerganov/whisper.cpp/'));
      expect(info.expectedSizeBytes, lessThan(200 * 1000 * 1000));
      // A distinct file/preference preserves downloaded English/German weights
      // and the language settings captured by existing immutable voice jobs.
      for (final type in [
        TranscriptionEngineType.whisperSmallEn,
        TranscriptionEngineType.whisperSmallMultiDe,
      ]) {
        final prior = TranscriptionModelCatalog.info(type);
        expect(prior.fileName, isNot(info.fileName));
        expect(prior.language, isNot('auto'));
      }
    },
  );

  test('every persisted model choice resolves to one catalog entry', () {
    expect(
      TranscriptionModelCatalog.all.map((info) => info.type).toSet(),
      TranscriptionEngineType.values.toSet(),
    );
    expect(
      TranscriptionModelCatalog.all.map((info) => info.fileName).toSet().length,
      TranscriptionEngineType.values.length,
    );
  });
}
