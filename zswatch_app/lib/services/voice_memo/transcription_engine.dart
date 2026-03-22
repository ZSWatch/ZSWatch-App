import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

/// Discriminates between available offline transcription engine variants.
///
/// Persisted in SharedPreferences so the user's choice survives restarts.
enum TranscriptionEngineType {
  /// Tiny English-only Whisper model (~75 MB). Downloaded from whisper.cpp CDN.
  whisperTinyEn,

  /// Base English-only Whisper model (~142 MB). Noticeably better than Tiny.
  whisperBaseEn,

  /// Small English-only Whisper model (~466 MB). Highest-fidelity English
  /// model at a manageable size. ~800 MB RAM needed.
  whisperSmallEn,

  /// KB-Whisper Base fine-tuned on 50 k+ hours of Swedish speech (~147 MB,
  /// q5_0 quantised). Downloaded from HuggingFace on first use.
  kbWhisperBase,

  /// KB-Whisper Small q5_0 quantised (~175 MB). Massive accuracy improvement
  /// over Base for Swedish at nearly the same size. ~500 MB RAM needed.
  kbWhisperSmallQ5,

  /// KB-Whisper Small full GGML checkpoint (~488 MB). Highest fidelity
  /// available from the upstream GGML release. ~1 GB RAM needed.
  kbWhisperSmallQ8,

  /// Whisper Base multilingual model forced to German (~142 MB).
  /// Solid German accuracy at a compact size.
  whisperBaseMultiDe,

  /// Whisper Small multilingual model forced to German (~244 MB).
  /// Higher-fidelity German, noticeably better than Base. ~500 MB RAM.
  whisperSmallMultiDe,

  /// Whisper Large-v3-Turbo q5_0 quantised (~547 MB). Near cloud-level
  /// accuracy, optimised for speed. Needs ~1 GB RAM — modern flagships only.
  whisperLargeV3TurboQ5,
}

/// Static metadata for a selectable transcription model.
class TranscriptionModelInfo {
  final TranscriptionEngineType type;
  final String name;
  final String language;
  final String sourceUrl;
  final String fileName;
  final int expectedSizeBytes;
  final String description;

  const TranscriptionModelInfo({
    required this.type,
    required this.name,
    required this.language,
    required this.sourceUrl,
    required this.fileName,
    required this.expectedSizeBytes,
    required this.description,
  });
}

/// Catalog of selectable offline models shown in settings.
abstract final class TranscriptionModelCatalog {
  static const _tinyEn = TranscriptionModelInfo(
    type: TranscriptionEngineType.whisperTinyEn,
    name: 'Whisper Tiny (English)',
    language: 'en',
    sourceUrl:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
    fileName: 'ggml-tiny.en.bin',
    expectedSizeBytes: 75 * 1024 * 1024,
    description:
        'Good English (75 MB, fast) — smallest download, lowest accuracy, best for short clear speech.',
  );

  static const _baseEn = TranscriptionModelInfo(
    type: TranscriptionEngineType.whisperBaseEn,
    name: 'Whisper Base (English)',
    language: 'en',
    sourceUrl:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin',
    fileName: 'ggml-base.en.bin',
    expectedSizeBytes: 142 * 1024 * 1024,
    description:
        'Better English (142 MB) — noticeably more accurate than Tiny, still compact.',
  );

  static const _smallEn = TranscriptionModelInfo(
    type: TranscriptionEngineType.whisperSmallEn,
    name: 'Whisper Small (English)',
    language: 'en',
    sourceUrl:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin',
    fileName: 'ggml-small.en.bin',
    expectedSizeBytes: 466 * 1024 * 1024,
    description:
        'Best English (466 MB, slow) — highest-fidelity English, significant accuracy boost over Base. ~800 MB RAM.',
  );

  static const _kbWhisperBase = TranscriptionModelInfo(
    type: TranscriptionEngineType.kbWhisperBase,
    name: 'KB-Whisper Base (Swedish)',
    language: 'sv',
    sourceUrl:
        'https://huggingface.co/KBLab/kb-whisper-base/resolve/main/ggml-model-q5_0.bin',
    fileName: 'ggml-kb-whisper-base-q5_0.bin',
    expectedSizeBytes: 147 * 1024 * 1024,
    description:
        'Good (147 MB) — solid Swedish accuracy, fine-tuned on 50k+ hours of speech.',
  );

  static const _kbWhisperSmallQ5 = TranscriptionModelInfo(
    type: TranscriptionEngineType.kbWhisperSmallQ5,
    name: 'KB-Whisper Small · Q5_0 (Swedish)',
    language: 'sv',
    sourceUrl:
        'https://huggingface.co/KBLab/kb-whisper-small/resolve/main/ggml-model-q5_0.bin',
    fileName: 'ggml-kb-whisper-small-q5_0.bin',
    expectedSizeBytes: 175 * 1024 * 1024,
    description:
        'Better (175 MB) — noticeably better Swedish than Good at nearly the same size. ~500 MB RAM.',
  );

  static const _kbWhisperSmallQ8 = TranscriptionModelInfo(
    type: TranscriptionEngineType.kbWhisperSmallQ8,
    name: 'KB-Whisper Small · Full (Swedish)',
    language: 'sv',
    sourceUrl:
        'https://huggingface.co/KBLab/kb-whisper-small/resolve/main/ggml-model.bin',
    fileName: 'ggml-kb-whisper-small.bin',
    expectedSizeBytes: 488 * 1024 * 1024,
    description:
        'Best (488 MB, slow) — highest-fidelity Swedish, full-precision model. Needs ~1 GB RAM.',
  );

  static const _baseMultiDe = TranscriptionModelInfo(
    type: TranscriptionEngineType.whisperBaseMultiDe,
    name: 'Whisper Base (German)',
    language: 'de',
    sourceUrl:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
    fileName: 'ggml-base-multi-de.bin',
    expectedSizeBytes: 142 * 1024 * 1024,
    description:
        'Good German (142 MB) — multilingual Whisper forced to German, solid accuracy.',
  );

  static const _smallMultiDe = TranscriptionModelInfo(
    type: TranscriptionEngineType.whisperSmallMultiDe,
    name: 'Whisper Small (German)',
    language: 'de',
    sourceUrl:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
    fileName: 'ggml-small-multi-de.bin',
    expectedSizeBytes: 244 * 1024 * 1024,
    description:
        'Better German (244 MB) — higher-fidelity German, noticeably better than Base. ~500 MB RAM.',
  );

  static const _whisperLargeV3TurboQ5 = TranscriptionModelInfo(
    type: TranscriptionEngineType.whisperLargeV3TurboQ5,
    name: 'Whisper Large-v3-Turbo · Q5_0 (Multilingual)',
    language: 'auto',
    sourceUrl:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin',
    fileName: 'ggml-large-v3-turbo-q5_0.bin',
    expectedSizeBytes: 547 * 1024 * 1024,
    description:
        'Multilingual (547 MB, slow) — near cloud-level accuracy for any language. Needs ~1 GB RAM.',
  );

  // Models grouped by language: English → Swedish → German → Multilingual,
  // ordered best→worst within each group.
  static const List<TranscriptionModelInfo> all = [
    _smallEn,
    _baseEn,
    _tinyEn,
    _kbWhisperSmallQ8,
    _kbWhisperSmallQ5,
    _kbWhisperBase,
    _smallMultiDe,
    _baseMultiDe,
    _whisperLargeV3TurboQ5,
  ];

  static TranscriptionModelInfo info(TranscriptionEngineType type) {
    switch (type) {
      case TranscriptionEngineType.whisperTinyEn:
        return _tinyEn;
      case TranscriptionEngineType.whisperBaseEn:
        return _baseEn;
      case TranscriptionEngineType.whisperSmallEn:
        return _smallEn;
      case TranscriptionEngineType.kbWhisperBase:
        return _kbWhisperBase;
      case TranscriptionEngineType.kbWhisperSmallQ5:
        return _kbWhisperSmallQ5;
      case TranscriptionEngineType.kbWhisperSmallQ8:
        return _kbWhisperSmallQ8;
      case TranscriptionEngineType.whisperBaseMultiDe:
        return _baseMultiDe;
      case TranscriptionEngineType.whisperSmallMultiDe:
        return _smallMultiDe;
      case TranscriptionEngineType.whisperLargeV3TurboQ5:
        return _whisperLargeV3TurboQ5;
    }
  }
}

TranscriptionEngine createTranscriptionEngine(TranscriptionEngineType type) {
  switch (type) {
    case TranscriptionEngineType.whisperTinyEn:
      return WhisperEngine();
    case TranscriptionEngineType.whisperBaseEn:
      return CustomGgmlWhisperEngine(
        modelUrl:
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin',
        modelFileName: 'ggml-base.en.bin',
        languageCode: 'en',
        displayName: 'Whisper Base (English)',
      );
    case TranscriptionEngineType.whisperSmallEn:
      return CustomGgmlWhisperEngine(
        modelUrl:
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin',
        modelFileName: 'ggml-small.en.bin',
        languageCode: 'en',
        displayName: 'Whisper Small (English)',
      );
    case TranscriptionEngineType.kbWhisperBase:
      return KbWhisperEngines.base();
    case TranscriptionEngineType.kbWhisperSmallQ5:
      return KbWhisperEngines.smallQ5();
    case TranscriptionEngineType.kbWhisperSmallQ8:
      return KbWhisperEngines.smallQ8();
    case TranscriptionEngineType.whisperBaseMultiDe:
      return CustomGgmlWhisperEngine(
        modelUrl:
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
        modelFileName: 'ggml-base-multi-de.bin',
        languageCode: 'de',
        displayName: 'Whisper Base (German)',
      );
    case TranscriptionEngineType.whisperSmallMultiDe:
      return CustomGgmlWhisperEngine(
        modelUrl:
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
        modelFileName: 'ggml-small-multi-de.bin',
        languageCode: 'de',
        displayName: 'Whisper Small (German)',
      );
    case TranscriptionEngineType.whisperLargeV3TurboQ5:
      return KbWhisperEngines.largeV3TurboQ5();
  }
}

/// Abstract interface for speech-to-text transcription engines
///
/// Implementations:
/// - [WhisperEngine]: Offline transcription using whisper_ggml_plus (default)
/// - [CustomGgmlWhisperEngine]: Any custom GGML model file via download URL
/// - Future: CloudSttEngine for Google Cloud STT / OpenAI Whisper API
/// - Future: PlatformSttEngine for iOS SFSpeechRecognizer
abstract class TranscriptionEngine {
  /// Transcribe audio from a file path.
  ///
  /// [audioFilePath] can be a 16 kHz 16-bit mono WAV file, or any format
  /// supported by the engine (Ogg/Opus if FFmpeg converter is registered).
  ///
  /// Returns the transcribed text, or empty string if nothing was recognized.
  /// Throws on engine errors (model not loaded, file not found, etc.).
  Future<String> transcribe(String audioFilePath);

  /// Whether this engine is currently available (model downloaded, etc.)
  Future<bool> isAvailable();

  /// Human-readable engine name for display
  String get engineName;

  /// Stream of engine status changes (model downloading, ready, etc.)
  Stream<TranscriptionEngineState> get stateStream;

  /// Current state
  TranscriptionEngineState get currentState;

  /// Ensure the engine is ready (download model if needed)
  Future<void> initialize();

  /// Clean up resources
  void dispose();

  /// URL of the model source used for downloads.
  String get modelSourceUrl;

  /// Expected model size (bytes) shown in setup UI.
  int get expectedModelSizeBytes;

  /// Local path to the model file.
  Future<String> modelFilePath();

  /// Delete local model file if present.
  Future<void> deleteModel();
}

/// State of a transcription engine
enum TranscriptionEngineStatus {
  /// Not initialized yet
  uninitialized,

  /// Model is being downloaded
  downloading,

  /// Ready to transcribe
  ready,

  /// An error occurred (model download failed, etc.)
  error,

  /// Currently transcribing
  transcribing,
}

/// Transcription engine state with progress info
class TranscriptionEngineState {
  final TranscriptionEngineStatus status;
  final double downloadProgress; // 0.0 - 1.0, only valid during downloading
  final String? errorMessage;

  const TranscriptionEngineState({
    this.status = TranscriptionEngineStatus.uninitialized,
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  TranscriptionEngineState copyWith({
    TranscriptionEngineStatus? status,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return TranscriptionEngineState(
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Offline Whisper engine using whisper_ggml_plus
///
/// Downloads the tiny.en model (~75 MB) on first use. Subsequent
/// transcriptions use the cached model. The WhisperController keeps
/// the model in memory for fast back-to-back transcriptions.
class WhisperEngine implements TranscriptionEngine {
  static const WhisperModel _defaultModel = WhisperModel.tinyEn;

  final WhisperController _controller = WhisperController();
  final _state = BehaviorSubject<TranscriptionEngineState>.seeded(
    const TranscriptionEngineState(),
  );

  @override
  String get engineName => 'Whisper (Offline)';

  @override
  String get modelSourceUrl => _defaultModel.modelUri.toString();

  @override
  int get expectedModelSizeBytes => TranscriptionModelCatalog.info(
    TranscriptionEngineType.whisperTinyEn,
  ).expectedSizeBytes;

  @override
  Stream<TranscriptionEngineState> get stateStream => _state.stream;

  @override
  TranscriptionEngineState get currentState => _state.value;

  @override
  Future<bool> isAvailable() async {
    try {
      final modelFile = File(await modelFilePath());
      return modelFile.existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    if (currentState.status == TranscriptionEngineStatus.downloading) return;

    try {
      final available = await isAvailable();
      if (available) {
        _state.add(
          const TranscriptionEngineState(
            status: TranscriptionEngineStatus.ready,
          ),
        );
        return;
      }

      _state.add(
        const TranscriptionEngineState(
          status: TranscriptionEngineStatus.downloading,
        ),
      );

      await _downloadModel();

      _state.add(
        const TranscriptionEngineState(status: TranscriptionEngineStatus.ready),
      );
    } catch (e) {
      _state.add(
        TranscriptionEngineState(
          status: TranscriptionEngineStatus.error,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!File(audioFilePath).existsSync()) {
      throw Exception('Audio file not found: $audioFilePath');
    }

    if (!await isAvailable()) {
      throw Exception(
        'Transcription model not downloaded. Configure in Settings > Voice Memos.',
      );
    }

    _state.add(
      const TranscriptionEngineState(
        status: TranscriptionEngineStatus.transcribing,
      ),
    );

    try {
      debugPrint('[WhisperEngine] Transcribing: $audioFilePath');

      final result = await _controller.transcribe(
        model: _defaultModel,
        audioPath: audioFilePath,
        lang: 'en',
      );

      _state.add(
        const TranscriptionEngineState(status: TranscriptionEngineStatus.ready),
      );

      if (result == null) {
        debugPrint('[WhisperEngine] Transcription returned null');
        return '';
      }

      final text = result.transcription.text.trim();
      debugPrint('[WhisperEngine] Result: $text');
      return text;
    } catch (e) {
      debugPrint('[WhisperEngine] Error: $e');
      _state.add(
        TranscriptionEngineState(
          status: TranscriptionEngineStatus.error,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<String> modelFilePath() async {
    return _controller.getPath(_defaultModel);
  }

  Future<void> _downloadModel() async {
    final filePath = await modelFilePath();
    final tmpPath = '$filePath.${DateTime.now().microsecondsSinceEpoch}.tmp';
    final tmpFile = File(tmpPath);
    final finalFile = File(filePath);

    if (!finalFile.parent.existsSync()) {
      finalFile.parent.createSync(recursive: true);
    }

    final client = http.Client();
    IOSink? sink;
    try {
      debugPrint(
        '[WhisperEngine] Downloading ${_defaultModel.modelName} from ${_defaultModel.modelUri}',
      );
      final request = http.Request('GET', _defaultModel.modelUri);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} downloading model');
      }

      final totalBytes = response.contentLength ?? 0;
      var received = 0;

      sink = tmpFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          _state.add(
            TranscriptionEngineState(
              status: TranscriptionEngineStatus.downloading,
              downloadProgress: received / totalBytes,
            ),
          );
        }
      }
      await sink.close();
      sink = null;

      if (finalFile.existsSync()) {
        await finalFile.delete();
      }

      if (tmpFile.existsSync()) {
        await tmpFile.rename(filePath);
      } else if (!finalFile.existsSync()) {
        throw Exception('Downloaded model temp file missing before finalize');
      }

      debugPrint('[WhisperEngine] Model saved to $filePath');
    } catch (e) {
      if (sink != null) {
        await sink.close();
      }
      if (tmpFile.existsSync()) {
        tmpFile.deleteSync();
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  @override
  Future<void> deleteModel() async {
    final modelFile = File(await modelFilePath());
    if (modelFile.existsSync()) {
      await modelFile.delete();
    }
    _state.add(
      const TranscriptionEngineState(
        status: TranscriptionEngineStatus.uninitialized,
      ),
    );
  }

  @override
  void dispose() {
    _state.close();
  }
}

// ---------------------------------------------------------------------------
// Generic GGML engine — downloads any .bin from a URL on first use
// ---------------------------------------------------------------------------

/// Offline Whisper engine for custom GGML models downloaded at runtime.
///
/// The model file is downloaded from [modelUrl] to app-support/whisper_models/
/// on the first call to [initialize] (or lazily on first [transcribe]).
/// Subsequent runs reuse the cached file.
///
/// Use [KbWhisperEngines] for pre-configured Swedish KB-Whisper variants.
class CustomGgmlWhisperEngine implements TranscriptionEngine {
  final String _modelUrl;
  final String _modelFileName;
  final String _languageCode;
  final String _displayName;

  final _state = BehaviorSubject<TranscriptionEngineState>.seeded(
    const TranscriptionEngineState(),
  );

  CustomGgmlWhisperEngine({
    required String modelUrl,
    required String modelFileName,
    required String languageCode,
    required String displayName,
  }) : _modelUrl = modelUrl,
       _modelFileName = modelFileName,
       _languageCode = languageCode,
       _displayName = displayName;

  @override
  String get engineName => _displayName;

  @override
  String get modelSourceUrl => _modelUrl;

  @override
  int get expectedModelSizeBytes {
    // Try to look up from the catalog by filename
    for (final info in TranscriptionModelCatalog.all) {
      if (info.fileName == _modelFileName) {
        return info.expectedSizeBytes;
      }
    }
    return 0;
  }

  @override
  Stream<TranscriptionEngineState> get stateStream => _state.stream;

  @override
  TranscriptionEngineState get currentState => _state.value;

  @override
  Future<bool> isAvailable() async {
    try {
      return File(await _modelFilePath()).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    if (currentState.status == TranscriptionEngineStatus.ready) return;
    if (currentState.status == TranscriptionEngineStatus.downloading) return;

    try {
      if (await isAvailable()) {
        _state.add(
          const TranscriptionEngineState(
            status: TranscriptionEngineStatus.ready,
          ),
        );
        return;
      }

      _state.add(
        const TranscriptionEngineState(
          status: TranscriptionEngineStatus.downloading,
        ),
      );

      await _downloadModel();

      _state.add(
        const TranscriptionEngineState(status: TranscriptionEngineStatus.ready),
      );
    } catch (e) {
      debugPrint('[CustomGgmlWhisperEngine] Download error: $e');
      _state.add(
        TranscriptionEngineState(
          status: TranscriptionEngineStatus.error,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> _downloadModel() async {
    final filePath = await _modelFilePath();
    final tmpPath = '$filePath.${DateTime.now().microsecondsSinceEpoch}.tmp';
    final tmpFile = File(tmpPath);
    final finalFile = File(filePath);

    if (finalFile.parent.existsSync() == false) {
      finalFile.parent.createSync(recursive: true);
    }

    final client = http.Client();
    try {
      debugPrint(
        '[CustomGgmlWhisperEngine] Downloading $_modelFileName from $_modelUrl',
      );
      final request = http.Request('GET', Uri.parse(_modelUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} downloading model');
      }

      final totalBytes = response.contentLength ?? 0;
      int received = 0;

      final sink = tmpFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          _state.add(
            TranscriptionEngineState(
              status: TranscriptionEngineStatus.downloading,
              downloadProgress: received / totalBytes,
            ),
          );
        }
      }
      await sink.close();

      // Atomically rename tmp → final
      if (finalFile.existsSync()) {
        await finalFile.delete();
      }

      if (tmpFile.existsSync()) {
        await tmpFile.rename(filePath);
      } else if (!finalFile.existsSync()) {
        throw Exception('Downloaded model temp file missing before finalize');
      }

      debugPrint('[CustomGgmlWhisperEngine] Model saved to $filePath');
    } catch (e) {
      // Clean up incomplete download
      if (tmpFile.existsSync()) tmpFile.deleteSync();
      rethrow;
    } finally {
      client.close();
    }
  }

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!File(audioFilePath).existsSync()) {
      throw Exception('Audio file not found: $audioFilePath');
    }

    final modelPath = await _modelFilePath();
    if (!File(modelPath).existsSync()) {
      throw Exception(
        'Transcription model not downloaded. Configure in Settings > Voice Memos.',
      );
    }

    _state.add(
      const TranscriptionEngineState(
        status: TranscriptionEngineStatus.transcribing,
      ),
    );

    String? convertedAudioPath;
    try {
      final transcriptionAudioPath = await _prepareAudioForWhisper(
        audioFilePath,
      );
      if (transcriptionAudioPath != audioFilePath) {
        convertedAudioPath = transcriptionAudioPath;
      }

      debugPrint(
        '[CustomGgmlWhisperEngine] Transcribing: $transcriptionAudioPath',
      );

      // Use Whisper directly so we can pass an arbitrary modelPath string.
      // WhisperController.transcribe() only accepts a WhisperModel enum, but
      // Whisper.transcribe() accepts any modelPath — which is what we need for
      // custom GGML models downloaded from HuggingFace.
      const whisper = Whisper(model: WhisperModel.base);
      final response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: transcriptionAudioPath,
          language: _languageCode,
        ),
        modelPath: modelPath,
      );

      _state.add(
        const TranscriptionEngineState(status: TranscriptionEngineStatus.ready),
      );

      final text = response.text.trim();
      debugPrint('[CustomGgmlWhisperEngine] Result: $text');
      return text;
    } catch (e) {
      debugPrint('[CustomGgmlWhisperEngine] Error: $e');
      _state.add(
        TranscriptionEngineState(
          status: TranscriptionEngineStatus.error,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    } finally {
      if (convertedAudioPath != null) {
        try {
          final convertedFile = File(convertedAudioPath);
          if (convertedFile.existsSync()) {
            convertedFile.deleteSync();
          }
        } catch (e) {
          debugPrint('[CustomGgmlWhisperEngine] Failed to delete temp WAV: $e');
        }
      }
    }
  }

  Future<String> _prepareAudioForWhisper(String audioFilePath) async {
    if (audioFilePath.toLowerCase().endsWith('.wav')) {
      return audioFilePath;
    }

    final input = File(audioFilePath);
    final outputPath = '${input.path}.wav';
    final output = File(outputPath);

    if (output.existsSync()) {
      output.deleteSync();
    }

    final arguments = <String>[
      '-y',
      '-i',
      '"${input.path}"',
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      '"$outputPath"',
    ];

    debugPrint(
      '[CustomGgmlWhisperEngine] Converting audio for Whisper: ${input.path} -> $outputPath',
    );

    final FFmpegSession session = await FFmpegKit.execute(arguments.join(' '));
    final ReturnCode? returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode) && output.existsSync()) {
      return outputPath;
    }

    final logs = await session.getOutput();
    throw Exception(
      'Audio conversion failed (returnCode=${returnCode?.getValue()}): ${logs ?? 'no FFmpeg logs'}',
    );
  }

  Future<String> _modelFilePath() async {
    final appDir = await getApplicationSupportDirectory();
    final modelDir = Directory('${appDir.path}/whisper_models');
    if (!modelDir.existsSync()) {
      modelDir.createSync(recursive: true);
    }
    return '${modelDir.path}/$_modelFileName';
  }

  @override
  Future<String> modelFilePath() => _modelFilePath();

  @override
  Future<void> deleteModel() async {
    final modelFile = File(await _modelFilePath());
    if (modelFile.existsSync()) {
      await modelFile.delete();
    }
    _state.add(
      const TranscriptionEngineState(
        status: TranscriptionEngineStatus.uninitialized,
      ),
    );
  }

  @override
  void dispose() {
    _state.close();
  }
}

// ---------------------------------------------------------------------------
// Pre-configured KB-Whisper engines (National Library of Sweden)
// ---------------------------------------------------------------------------

/// Factory for KBLab/KB-Whisper model variants.
///
/// KB-Whisper is trained on 50 000+ hours of Swedish speech and vastly
/// outperforms stock OpenAI Whisper on Swedish (WER: 9.1 vs 39.6 for base).
/// Apache-2.0 licensed. Models are hosted on HuggingFace.
abstract final class KbWhisperEngines {
  static const String _hfBase =
      'https://huggingface.co/KBLab/kb-whisper-base/resolve/main';
  static const String _hfSmall =
      'https://huggingface.co/KBLab/kb-whisper-small/resolve/main';
  static const String _hfWhisperCpp =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  /// Base model, q5_0 quantised (~147 MB).
  /// Recommended: good accuracy, reasonable size for mobile.
  static CustomGgmlWhisperEngine base() => CustomGgmlWhisperEngine(
    modelUrl: '$_hfBase/ggml-model-q5_0.bin',
    modelFileName: 'ggml-kb-whisper-base-q5_0.bin',
    languageCode: 'sv',
    displayName: 'KB-Whisper Base (Swedish)',
  );

  /// Small model, q5_0 quantised (~175 MB).
  /// Big accuracy leap over Base at nearly the same size. ~500 MB RAM.
  static CustomGgmlWhisperEngine smallQ5() => CustomGgmlWhisperEngine(
    modelUrl: '$_hfSmall/ggml-model-q5_0.bin',
    modelFileName: 'ggml-kb-whisper-small-q5_0.bin',
    languageCode: 'sv',
    displayName: 'KB-Whisper Small · Q5_0 (Swedish)',
  );

  /// Small model, full GGML checkpoint (~488 MB).
  /// Highest fidelity Small variant currently published for whisper.cpp.
  static CustomGgmlWhisperEngine smallQ8() => CustomGgmlWhisperEngine(
    modelUrl: '$_hfSmall/ggml-model.bin',
    modelFileName: 'ggml-kb-whisper-small.bin',
    languageCode: 'sv',
    displayName: 'KB-Whisper Small · Full GGML (Swedish)',
  );

  /// Whisper Large-v3-Turbo, q5_0 quantised (~547 MB).
  /// Near-cloud accuracy, heavily optimised. ~1 GB RAM — flagship devices.
  static CustomGgmlWhisperEngine largeV3TurboQ5() => CustomGgmlWhisperEngine(
    modelUrl: '$_hfWhisperCpp/ggml-large-v3-turbo-q5_0.bin',
    modelFileName: 'ggml-large-v3-turbo-q5_0.bin',
    languageCode: 'auto',
    displayName: 'Whisper Large-v3-Turbo · Q5_0',
  );
}
