import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

/// Target audio format expected by the watch speaker manager (48 kHz, stereo, 16-bit PCM WAV).
const int _watchSampleRate = 48000;
const int _watchChannels = 2;

/// TTS engine state
enum TtsStatus {
  idle,
  synthesizing,
  speaking,
  error,
}

/// TTS service wrapping platform TTS for chat reply synthesis.
///
/// Synthesizes text to a WAV file and resamples it to the format expected by
/// the watch speaker manager: 48 kHz, 16-bit, stereo PCM WAV.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  final _statusController = BehaviorSubject<TtsStatus>.seeded(TtsStatus.idle);
  Stream<TtsStatus> get statusStream => _statusController.stream;
  TtsStatus get status => _statusController.value;

  bool _initialized = false;
  Completer<void>? _synthesisCompleter;

  /// Detect the most likely BCP-47 language tag for [text] using character-set heuristics.
  ///
  /// Checks Unicode block membership and language-specific diacritics:
  /// - å/Å only occur in Swedish/Norwegian/Danish → sv-SE
  /// - ü/ß uniquely mark German (when no å) → de-DE
  /// - Cyrillic-dominant → ru-RU
  /// - CJK/Hiragana/Katakana → zh-CN / ja-JP
  /// - Hangul → ko-KR
  /// - French accent clusters → fr-FR
  /// - ñ/¡/¿ → es-ES
  /// - Fallback → en-US
  static String detectLanguage(String text) {
    int cyrillicCount = 0, cjkCount = 0, kanaCount = 0, hangulCount = 0;
    int sweScore = 0, deScore = 0, frScore = 0, esScore = 0;
    int latinCount = 0;

    for (final r in text.runes) {
      if (r >= 0x0400 && r <= 0x04FF) cyrillicCount++;
      if (r >= 0x4E00 && r <= 0x9FFF) cjkCount++;
      if (r >= 0x3040 && r <= 0x30FF) kanaCount++;
      if (r >= 0xAC00 && r <= 0xD7A3) hangulCount++;
      if ((r >= 0x41 && r <= 0x7A) || (r >= 0xC0 && r <= 0x17F)) latinCount++;

      // å(229) Å(197) — uniquely Nordic
      if (r == 229 || r == 197) sweScore += 3;
      // ä(228) ö(246) Ä(196) Ö(214) — Swedish/German shared, but weigh for Swedish
      if (r == 228 || r == 246 || r == 196 || r == 214) sweScore++;
      // ü(252) Ü(220) ß(223) — German-specific
      if (r == 252 || r == 220 || r == 223) deScore += 2;
      // é(233) è(232) ê(234) à(224) â(226) œ(339) ç(231) — French
      if (r == 233 || r == 232 || r == 234 || r == 224 || r == 226 || r == 339 || r == 231) frScore++;
      // ñ(241) ¡(161) ¿(191) — Spanish
      if (r == 241 || r == 161 || r == 191) esScore += 2;
    }

    final total = text.length > 1 ? text.length : 1;
    if (cyrillicCount > total * 0.25) return 'ru-RU';
    if (hangulCount > 3) return 'ko-KR';
    if (kanaCount > 3) return 'ja-JP';
    if (cjkCount > 5) return 'zh-CN';

    // å/Å uniquely identifies Nordic; Swedish is the default for that set
    if (sweScore >= 3) return 'sv-SE';
    if (deScore > 0 && deScore >= sweScore) return 'de-DE';
    if (frScore > latinCount * 0.04) return 'fr-FR';
    if (esScore > 0) return 'es-ES';

    return 'en-US';
  }

  /// Initialize the TTS engine.
  Future<void> initialize() async {
    if (_initialized) return;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _synthesisCompleter?.complete();
      _synthesisCompleter = null;
      _statusController.add(TtsStatus.idle);
    });

    _tts.setErrorHandler((message) {
      debugPrint('[TtsService] Error: $message');
      _synthesisCompleter?.complete();
      _synthesisCompleter = null;
      _statusController.add(TtsStatus.error);
    });

    _initialized = true;
    debugPrint('[TtsService] Initialized');
  }

  /// Synthesize [text] to a WAV file and return its path.
  ///
  /// If [language] is null the language is auto-detected from [text].
  /// The file is written to the app's temporary directory and must be
  /// uploaded to the watch before deletion.
  Future<String?> synthesizeToFile(String text, {String? language}) async {
    await initialize();

    final lang = language ?? detectLanguage(text);
    debugPrint('[TtsService] Language detected: $lang');
    await _tts.setLanguage(lang);

    _statusController.add(TtsStatus.synthesizing);

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/chat_reply.wav';

      // Remove old file if it exists
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
      }

      _synthesisCompleter?.complete();
      _synthesisCompleter = Completer<void>();

      final result = await _tts.synthesizeToFile(text, filePath, true);
      if (result == 1) {
        await _synthesisCompleter!.future.timeout(const Duration(seconds: 30));

        var exists = file.existsSync();
        for (var attempt = 0; attempt < 10 && !exists; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          exists = file.existsSync();
        }

        if (!exists) {
          debugPrint('[TtsService] Synthesized file missing: $filePath');
          _statusController.add(TtsStatus.error);
          return null;
        }

        debugPrint('[TtsService] Synthesized to: $filePath');

        // Convert to the format the watch expects: 48 kHz stereo 16-bit PCM WAV.
        final convertedPath = '${dir.path}/chat_reply_48k.wav';
        final convertedFile = File(convertedPath);
        if (convertedFile.existsSync()) {
          await convertedFile.delete();
        }

        final session = await FFmpegKit.execute(
          '-y -i $filePath -ar $_watchSampleRate -ac $_watchChannels -sample_fmt s16 $convertedPath',
        );
        final rc = await session.getReturnCode();
        if (!ReturnCode.isSuccess(rc)) {
          final logs = await session.getOutput();
          debugPrint('[TtsService] ffmpeg conversion failed: $logs');
          _statusController.add(TtsStatus.error);
          return null;
        }

        // Replace the raw TTS output with the converted file.
        await file.delete();
        await convertedFile.rename(filePath);

        debugPrint('[TtsService] Converted to 48kHz stereo: $filePath');
        _statusController.add(TtsStatus.idle);
        return filePath;
      } else {
        debugPrint('[TtsService] synthesizeToFile returned: $result');
        _statusController.add(TtsStatus.error);
        return null;
      }
    } catch (e) {
      debugPrint('[TtsService] synthesizeToFile error: $e');
      _synthesisCompleter = null;
      _statusController.add(TtsStatus.error);
      return null;
    }
  }

  /// Stop any in-progress synthesis or speech.
  Future<void> stop() async {
    await _tts.stop();
    _statusController.add(TtsStatus.idle);
  }

  void dispose() {
    _tts.stop();
    _statusController.close();
  }
}
