import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:fllama/fllama.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'ai_debug_info.dart';
import 'litert_lm_service.dart';
import 'llm_compute_service.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

class LlmModelInfo {
  final String id;
  final String displayName;
  final String family;
  final String filename;
  final String? downloadUrl;
  final int? expectedSizeBytes;
  final bool userProvided;

  /// Per-model context size override. When non-null the inference engine will
  /// use this instead of the global [LlmService.nCtx]. Useful for memory-
  /// hungry architectures (e.g. Qwen3.5 with gated attention).
  final int? contextSize;

  /// Benchmark score from ai_testbench (passed cases out of [benchmarkTotal]).
  /// Shown in the model picker so users can compare accuracy.
  final int? benchmarkScore;
  final int? benchmarkTotal;

  /// True for models that use Google LiteRT-LM runtime (.litertlm format)
  /// instead of llama.cpp (.gguf format).
  final bool isLiteRtLm;

  const LlmModelInfo({
    required this.id,
    required this.displayName,
    required this.family,
    required this.filename,
    this.downloadUrl,
    this.expectedSizeBytes,
    this.userProvided = false,
    this.contextSize,
    this.benchmarkScore,
    this.benchmarkTotal,
    this.isLiteRtLm = false,
  });

  bool get isDownloadable => downloadUrl != null;

  String get shortSourceLabel => userProvided ? 'Imported' : 'Catalog';
}

/// Status of the LLM service.
enum LlmServiceStatus { idle, downloading, processing, ready, error }

/// How well a model fits into available device memory.
enum ModelMemoryFit {
  /// Plenty of headroom — full context.
  comfortable,

  /// Moderate — full context but tighter memory.
  reduced,

  /// Very tight — reduced context fallback.
  cpuFallback,
}

/// Result of [LlmService.checkModelFit] for a specific model on this device.
class ModelFitResult {
  final ModelMemoryFit fit;
  final int contextSize;
  final int deviceMemoryMB;
  final int modelSizeMB;
  final int headroomMB;

  const ModelFitResult({
    required this.fit,
    required this.contextSize,
    required this.deviceMemoryMB,
    required this.modelSizeMB,
    required this.headroomMB,
  });

  /// Human-readable summary for the UI.
  String get summary {
    switch (fit) {
      case ModelMemoryFit.comfortable:
        return 'Fits well — full prompt should be available';
      case ModelMemoryFit.reduced:
        return 'Tight fit — may switch to a shorter prompt';
      case ModelMemoryFit.cpuFallback:
        return 'Low memory — may fall back to the smallest prompt';
    }
  }
}

/// Observable state of the service (for the settings UI).
class LlmServiceState {
  final LlmServiceStatus status;
  final double downloadProgress;
  final String? error;

  const LlmServiceState({
    this.status = LlmServiceStatus.idle,
    this.downloadProgress = 0.0,
    this.error,
  });

  LlmServiceState copyWith({
    LlmServiceStatus? status,
    double? downloadProgress,
    String? error,
  }) => LlmServiceState(
    status: status ?? this.status,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    error: error ?? this.error,
  );
}

/// One extracted action from the LLM output.
class ExtractedActionResult {
  final String type; // "task", "calendar_event", "reminder", "timer", "alarm"
  final String title;
  final String? notes;
  final String? dueDate;
  final String? startTime;
  final String? location;

  /// Duration in seconds for timer intents.
  final int? durationSeconds;

  const ExtractedActionResult({
    required this.type,
    required this.title,
    this.notes,
    this.dueDate,
    this.startTime,
    this.location,
    this.durationSeconds,
  });
}

/// Performance metrics from a single LLM inference run.
class LlmInferenceMetrics {
  final String modelName;
  final String rawPrompt;
  final String rawResponse;
  final String? parsedJson;
  final Duration wallTime;
  final int promptTokens;
  final int completionTokens;
  final double tokensPerSecond;
  final int attempts;
  final String? promptStrategy;
  final bool retryEnabled;

  const LlmInferenceMetrics({
    required this.modelName,
    required this.rawPrompt,
    required this.rawResponse,
    this.parsedJson,
    required this.wallTime,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.tokensPerSecond = 0.0,
    this.attempts = 1,
    this.promptStrategy,
    this.retryEnabled = false,
  });

  LlmInferenceMetrics copyWithParsedJson(String? json) => LlmInferenceMetrics(
    modelName: modelName,
    rawPrompt: rawPrompt,
    rawResponse: rawResponse,
    parsedJson: json ?? parsedJson,
    wallTime: wallTime,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    tokensPerSecond: tokensPerSecond,
    attempts: attempts,
    promptStrategy: promptStrategy,
    retryEnabled: retryEnabled,
  );
}

/// Result of processTranscript().
class TranscriptResult {
  final String summary;
  final String category;
  final List<ExtractedActionResult> actions;
  final String? extractedIntent;
  final String? extractedTitle;
  final String? datetimeExpressionOriginal;
  final String? datetimeExpressionEnglish;
  final String? resolvedDateTime;
  final String? resolverMethod;
  final String? originalTranscription;
  final String? correctedTranscription;
  final LlmInferenceMetrics? correctionMetrics;
  final LlmInferenceMetrics? classifyMetrics;

  /// Per-action chrono extraction details for debug display.
  final List<ActionChronoDebug> actionChronoDetails;

  const TranscriptResult({
    required this.summary,
    required this.category,
    this.actions = const [],
    this.extractedIntent,
    this.extractedTitle,
    this.datetimeExpressionOriginal,
    this.datetimeExpressionEnglish,
    this.resolvedDateTime,
    this.resolverMethod,
    this.originalTranscription,
    this.correctedTranscription,
    this.correctionMetrics,
    this.classifyMetrics,
    this.actionChronoDetails = const [],
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Local LLM inference service backed by fllama (llama.cpp).
///
/// Usage flow:
///   1. [downloadModel] to fetch the GGUF file (one-time).
///   2. [processTranscript] to run classification/summarisation.
///
/// The model loads lazily on first inference and stays cached in-process.
class LlmService {
  static const int defaultTargetContextSize = 3072;
  static const int reducedContextSize = 2048;
  static const int minimumContextSize = 1024;

  static const int _maxStructuredOutputAttempts = 2;
  static const String promptPlaceholderCurrentLocalDateTime =
      ChronoPromptTemplate.promptPlaceholderCurrentLocalDateTime;
  static const String promptPlaceholderCurrentLocalDateTimeCompact =
      ChronoPromptTemplate.promptPlaceholderCurrentLocalDateTimeCompact;
  static const String promptPlaceholderWeekday =
      ChronoPromptTemplate.promptPlaceholderWeekday;
  static const String promptPlaceholderTimezoneOffset =
      ChronoPromptTemplate.promptPlaceholderTimezoneOffset;
  static const String promptPlaceholderTranscript =
      ChronoPromptTemplate.promptPlaceholderTranscript;

  static String get defaultBenchmarkPromptTemplate =>
      ChronoPromptTemplate.defaultTemplate;

  static String get defaultClassifyPromptTemplate =>
      defaultBenchmarkPromptTemplate;

  final TimeExpressionResolver _timeExpressionResolver =
      TimeExpressionResolver();
  final ChronoLlmParser _chronoLlmParser = const ChronoLlmParser();

  static const String defaultModelId = 'qwen25_1_5b_q4_k_m';
  // Models ordered by benchmark score (best first).
  // Worst 3 removed: SmolLM3 (1/40), Llama-3.2-3B (25/40), Qwen3-1.7B (26/40).
  static const List<LlmModelInfo> catalogModels = [
    LlmModelInfo(
      id: 'gemma4_e2b_litertlm',
      displayName: 'Gemma 4 E2B · LiteRT-LM',
      family: 'Gemma-4-E2B',
      filename: 'gemma-4-E2B-it.litertlm',
      expectedSizeBytes: 2900 * 1024 * 1024,
      isLiteRtLm: true,
      benchmarkScore: 46,
      benchmarkTotal: 49,
    ),
    LlmModelInfo(
      id: 'qwen35_2b_q4_k_m',
      displayName: 'Qwen3.5 2B Instruct · Q4_K_M',
      family: 'Qwen3.5-2B',
      filename: 'Qwen3.5-2B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
      expectedSizeBytes: 1222 * 1024 * 1024,
      benchmarkScore: 35,
      benchmarkTotal: 40,
    ),
    LlmModelInfo(
      id: 'qwen25_1_5b_q8_0',
      displayName: 'Qwen2.5 1.5B Instruct · Q8_0',
      family: 'Qwen2.5-1.5B-Instruct',
      filename: 'qwen2.5-1.5b-instruct-q8_0.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf',
      expectedSizeBytes: 1890 * 1024 * 1024,
      benchmarkScore: 35,
      benchmarkTotal: 40,
    ),
    LlmModelInfo(
      id: 'qwen25_1_5b_q5_k_m',
      displayName: 'Qwen2.5 1.5B Instruct · Q5_K_M',
      family: 'Qwen2.5-1.5B-Instruct',
      filename: 'qwen2.5-1.5b-instruct-q5_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q5_k_m.gguf',
      expectedSizeBytes: 1290 * 1024 * 1024,
      benchmarkScore: 34,
      benchmarkTotal: 40,
    ),
    LlmModelInfo(
      id: defaultModelId,
      displayName: 'Qwen2.5 1.5B Instruct · Q4_K_M',
      family: 'Qwen2.5-1.5B-Instruct',
      filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      expectedSizeBytes: 1120 * 1024 * 1024,
      benchmarkScore: 31,
      benchmarkTotal: 40,
    ),
  ];

  String _selectedModelId = defaultModelId;
  String _selectedModelName = 'Qwen2.5 1.5B Instruct · Q4_K_M';

  /// Human-readable name shown in the UI / persisted alongside AI results.
  String get modelName => _selectedModelName;
  String get selectedModelId => _selectedModelId;

  static bool usesFullPrompt(int contextSize) =>
      contextSize >= defaultTargetContextSize;

  static bool usesEmergencyCompactPrompt(int contextSize) =>
      contextSize <= minimumContextSize;

  // ---- Tunables ----
  int nCtx = defaultTargetContextSize;

  /// Compute a portable thread count for on-device inference.
  /// Uses half the reported cores (targets performance/big cores on
  /// big.LITTLE), clamped to [2, 6].  iOS with Metal doesn't benefit
  /// from extra CPU threads; Android CPU-only benefits from ~4.
  static int get _platformThreadCount {
    final total = Platform.numberOfProcessors;
    return (total ~/ 2).clamp(2, 6);
  }

  int nThreads = _platformThreadCount;
  int maxTokens = 512;
  // Qwen3.5 recommended sampling for non-thinking text tasks.
  double temperature = 0.3;
  double topP = 1.0;
  double presencePenalty = 2.0;

  // ---- Internal state ----
  String? _modelPath;
  int _runningRequestId = -1;
  int? _deviceMemoryMB;

  /// Serializes LiteRT-LM inference calls so only one runs at a time.
  /// Concurrent callers will queue and wait for the previous call to finish.
  Completer<void>? _liteRtLmLock;

  final LiteRtLmService _liteRtLmService = LiteRtLmService();

  /// Whether the currently selected model uses LiteRT-LM.
  bool get _isCurrentModelLiteRtLm {
    final model = catalogModels.where((m) => m.id == _selectedModelId).firstOrNull;
    return model?.isLiteRtLm ?? false;
  }

  final _stateSubject = BehaviorSubject<LlmServiceState>.seeded(
    const LlmServiceState(),
  );

  /// Observable service state (for UI bindings).
  Stream<LlmServiceState> get stateStream => _stateSubject.stream;
  LlmServiceState get currentState => _stateSubject.value;

  /// Check how well [modelInfo] fits on this device. Call from the UI when the
  /// user selects a model to show a warning banner if limits will be applied.
  Future<ModelFitResult> checkModelFit(LlmModelInfo modelInfo) async {
    final params = await _computeInferenceParams(modelInfo);
    final deviceMB = _deviceMemoryMB ?? 4096;
    final modelMB = (modelInfo.expectedSizeBytes ?? 0) ~/ (1024 * 1024);
    final usableMB = (deviceMB * 0.55).round();
    final headroomMB = usableMB - modelMB;

    // Base fit on actual memory headroom.
    ModelMemoryFit fit;
    if (headroomMB < 100) {
      fit = ModelMemoryFit.cpuFallback;
    } else if (params.contextSize < nCtx) {
      fit = ModelMemoryFit.reduced;
    } else {
      fit = ModelMemoryFit.comfortable;
    }

    return ModelFitResult(
      fit: fit,
      contextSize: params.contextSize,
      deviceMemoryMB: deviceMB,
      modelSizeMB: modelMB,
      headroomMB: headroomMB,
    );
  }

  // ---- Helpers ----

  Future<String> _modelDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/llm_models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<String> _importedModelDir() async {
    final dir = Directory('${await _modelDir()}/imported');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  static String customModelIdForFilename(String filename) =>
      'custom::$filename';

  static bool _isCustomModelId(String id) => id.startsWith('custom::');

  Future<List<LlmModelInfo>> availableModels() async {
    final importedDir = Directory(await _importedModelDir());
    final imported = <LlmModelInfo>[];

    if (importedDir.existsSync()) {
      for (final entity in importedDir.listSync()) {
        if (entity is! File) continue;
        final lowerPath = entity.path.toLowerCase();
        if (!lowerPath.endsWith('.gguf') &&
            !lowerPath.endsWith('.litertlm')) {
          continue;
        }

        final filename = p.basename(entity.path);
        imported.add(
          LlmModelInfo(
            id: customModelIdForFilename(filename),
            displayName: 'Imported · $filename',
            family: 'Imported',
            filename: filename,
            expectedSizeBytes: entity.lengthSync(),
            userProvided: true,
            isLiteRtLm: lowerPath.endsWith('.litertlm'),
          ),
        );
      }
    }

    imported.sort((a, b) => a.displayName.compareTo(b.displayName));
    return [...catalogModels, ...imported];
  }

  void selectModel(String modelId) {
    debugPrint('[LlmService] selectModel($modelId) called (was: $_selectedModelId)');
    _selectedModelId = modelId;
    final builtIn = catalogModels.where((m) => m.id == modelId).firstOrNull;
    _selectedModelName =
        builtIn?.displayName ??
        (_isCustomModelId(modelId)
            ? modelId.replaceFirst('custom::', '')
            : catalogModels.first.displayName);
    _modelPath = null;
    // Dispose previous LiteRT-LM engine when switching models.
    if (_liteRtLmService.isLoaded) {
      _liteRtLmService.dispose();
    }
  }

  Future<LlmModelInfo> currentModelInfo() async {
    final resolved = await _resolveModelById(_selectedModelId);
    return resolved ?? catalogModels.first;
  }

  Future<LlmModelInfo?> _resolveModelById(String modelId) async {
    for (final model in catalogModels) {
      if (model.id == modelId) {
        return model;
      }
    }

    final allModels = await availableModels();
    for (final model in allModels) {
      if (model.id == modelId) {
        return model;
      }
    }

    return null;
  }

  Future<String> _modelFilePathFor(LlmModelInfo model) async {
    if (model.userProvided) {
      return '${await _importedModelDir()}/${model.filename}';
    }
    return '${await _modelDir()}/${model.filename}';
  }

  /// Whether the model file is present on disk.
  Future<bool> isModelDownloaded({String? modelId}) async {
    final model =
        await _resolveModelById(modelId ?? _selectedModelId) ??
        catalogModels.first;
    return File(await _modelFilePathFor(model)).existsSync();
  }

  /// Size of the local model file in bytes, or null if not downloaded.
  Future<int?> modelFileSize({String? modelId}) async {
    final model =
        await _resolveModelById(modelId ?? _selectedModelId) ??
        catalogModels.first;
    final f = File(await _modelFilePathFor(model));
    return f.existsSync() ? f.lengthSync() : null;
  }

  // ---- Model management ----

  /// Download the GGUF model from HuggingFace.
  Future<void> downloadModel({String? modelId}) async {
    final model =
        await _resolveModelById(modelId ?? _selectedModelId) ??
        catalogModels.first;

    if (!model.isDownloadable) {
      throw StateError('Selected model is imported and cannot be downloaded.');
    }

    if (await isModelDownloaded(modelId: model.id)) {
      debugPrint('[LlmService] Model already downloaded');
      return;
    }

    _stateSubject.add(
      _stateSubject.value.copyWith(
        status: LlmServiceStatus.downloading,
        downloadProgress: 0.0,
      ),
    );

    try {
      final destPath = await _modelFilePathFor(model);
      final tmpPath = '$destPath.tmp';
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(model.downloadUrl!));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final sink = File(tmpPath).openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          _stateSubject.add(
            _stateSubject.value.copyWith(
              downloadProgress: received / contentLength,
            ),
          );
        }
      }

      await sink.close();
      client.close();

      // Atomic rename
      File(tmpPath).renameSync(destPath);

      _stateSubject.add(
        _stateSubject.value.copyWith(
          status: LlmServiceStatus.ready,
          downloadProgress: 1.0,
        ),
      );

      _selectedModelName = model.displayName;
      debugPrint('[LlmService] Model downloaded to $destPath');
    } catch (e) {
      _stateSubject.add(
        _stateSubject.value.copyWith(
          status: LlmServiceStatus.error,
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Delete the local model file.
  Future<void> deleteModel({String? modelId}) async {
    final model =
        await _resolveModelById(modelId ?? _selectedModelId) ??
        catalogModels.first;
    final f = File(await _modelFilePathFor(model));
    if (f.existsSync()) {
      f.deleteSync();
    }
    if ((modelId ?? _selectedModelId) == _selectedModelId) {
      _modelPath = null;
    }
    _stateSubject.add(const LlmServiceState());
    debugPrint('[LlmService] Model deleted');
  }

  Future<LlmModelInfo> importModel(String sourcePath) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw ArgumentError('Model file not found: $sourcePath');
    }
    if (!source.path.toLowerCase().endsWith('.gguf') &&
        !source.path.toLowerCase().endsWith('.litertlm')) {
      throw ArgumentError('Only .gguf or .litertlm models can be imported.');
    }

    final importedDir = await _importedModelDir();
    final baseName = p.basename(source.path);
    var candidateName = baseName;
    var counter = 1;
    while (File('$importedDir/$candidateName').existsSync()) {
      final stem = p.basenameWithoutExtension(baseName);
      final ext = p.extension(baseName);
      candidateName = '${stem}_$counter$ext';
      counter++;
    }

    final destination = File('$importedDir/$candidateName');
    await source.copy(destination.path);

    final importedModel = LlmModelInfo(
      id: customModelIdForFilename(candidateName),
      displayName: 'Imported · $candidateName',
      family: 'Imported',
      filename: candidateName,
      expectedSizeBytes: destination.lengthSync(),
      userProvided: true,
      isLiteRtLm: candidateName.toLowerCase().endsWith('.litertlm'),
    );

    selectModel(importedModel.id);
    return importedModel;
  }

  // ---- Inference ----

  /// Override the model file path directly (for testing with external storage).
  void overrideModelPath(String path) {
    _modelPath = path;
  }

  /// Ensure _modelPath is set (lazy init).
  /// For LiteRT-LM models, also calls [LiteRtLmService.loadModel].
  /// Returns the resolved [LlmModelInfo] so callers can use it without
  /// a second async call (which would be vulnerable to provider races).
  Future<LlmModelInfo> _ensureModel() async {
    if (_modelPath != null) {
      // Model path already set — resolve the info for consistency.
      final model = await currentModelInfo();
      return model;
    }
    final model = await currentModelInfo();
    final path = await _modelFilePathFor(model);
    if (!File(path).existsSync()) {
      throw StateError(
        'Selected model is not available locally. Download or import it first.',
      );
    }
    _selectedModelName = model.displayName;
    _modelPath = path;

    // LiteRT-LM models need to initialise the native engine.
    if (model.isLiteRtLm && !_liteRtLmService.isLoaded) {
      await _liteRtLmService.loadModel(path, backend: 'cpu');
    }
    return model;
  }

  // ---- Memory-aware tunables ----

  static const MethodChannel _deviceChannel = MethodChannel(
    'dev.zswatch.app/productivity',
  );

  /// Snapshot of memory state from the most recent `_computeInferenceParams`
  /// call. Exposed so callers (e.g. the AI pipeline) can surface this in the
  /// debug UI.
  ({
    int deviceMB,
    int availableMB,
    int modelMB,
    int headroomMB,
    int requestedContextSize,
    int contextSize,
    int? maxTokensCap,
  })?
  get lastInferenceMemoryInfo => _lastInferenceMemoryInfo;
  ({
    int deviceMB,
    int availableMB,
    int modelMB,
    int headroomMB,
    int requestedContextSize,
    int contextSize,
    int? maxTokensCap,
  })?
  _lastInferenceMemoryInfo;

  /// Query device physical RAM (MB), cached after first call.
  Future<int> _queryDeviceMemoryMB() async {
    if (_deviceMemoryMB != null) return _deviceMemoryMB!;
    try {
      final mb = await _deviceChannel.invokeMethod<int>('getDeviceMemoryMB');
      _deviceMemoryMB = mb ?? 4096; // conservative fallback
    } on MissingPluginException {
      _deviceMemoryMB = 4096;
    } catch (e) {
      debugPrint('[LlmService] Failed to query device memory: $e');
      _deviceMemoryMB = 4096;
    }
    debugPrint('[LlmService] Device physical RAM: ${_deviceMemoryMB}MB');
    return _deviceMemoryMB!;
  }

  /// Query currently available free RAM (MB) at inference time.
  /// This is more accurate than using cached total, since it accounts for
  /// memory used by other processes and the OS.
  Future<int> _queryAvailableMemoryMB() async {
    try {
      final mb = await _deviceChannel.invokeMethod<int>('getAvailableMemoryMB');
      return mb ?? 512; // conservative fallback if platform returns null
    } on MissingPluginException {
      // Fallback: estimate 50% of total is available (conservative)
      final total = await _queryDeviceMemoryMB();
      return (total * 0.5).toInt();
    } catch (e) {
      debugPrint('[LlmService] Failed to query available memory: $e');
      return 512; // very conservative fallback
    }
  }

  /// Compute context size and max output tokens dynamically based on
  /// real-time available RAM and model size. GPU is always off (CPU-only).
  ///
  /// Uses [LlmModelInfo.contextSize] if explicitly set, otherwise scales
  /// down when the model weight file would leave too little headroom for the
  /// KV cache + compute buffers.
  ///
  /// IMPORTANT: This method runs AFTER `_ensureModel()` has loaded the model,
  /// so `os_proc_available_memory()` already reflects the model's RAM usage.
  /// We do NOT subtract model size again — that would double-count.
  /// The available memory IS the headroom for KV cache + compute buffers.
  ///
  /// Larger context windows need a larger KV cache and more scratch space.
  /// The thresholds below prefer a smaller configuration over a crash when
  /// free RAM is tight:
  ///
  ///   available ≥  800 MB → target nCtx, maxTokens unchanged
  ///   available ≥  400 MB → nCtx 2048, maxTokens unchanged (shorter prompt)
  ///   available ≥  100 MB → nCtx 1024, maxTokens unchanged (compact prompt)
  ///   available <  100 MB → nCtx 1024, maxTokens capped at 256 (compact prompt)
  Future<({int contextSize, int? maxTokensCap})> _computeInferenceParams(
    LlmModelInfo modelInfo,
  ) async {
    // Explicit per-model context override wins.
    final explicitCtx = modelInfo.contextSize;
    if (explicitCtx != null) {
      return (contextSize: explicitCtx, maxTokensCap: null);
    }

    final deviceMB = await _queryDeviceMemoryMB();
    final availableMB = await _queryAvailableMemoryMB();
    final modelMB = (modelInfo.expectedSizeBytes ?? 0) ~/ (1024 * 1024);

    // The model is already loaded by `_ensureModel()` before this method runs,
    // so `availableMB` already reflects the model's memory footprint.
    // availableMB IS the headroom for KV cache + compute buffers — do NOT
    // subtract modelMB again (that would double-count and go negative).
    final headroomMB = availableMB;

    debugPrint(
      '[LlmService] Memory check: available=${availableMB}MB '
      'model=${modelMB}MB (already loaded) headroom=${headroomMB}MB '
      'deviceTotal=${deviceMB}MB',
    );

    int ctx;
    int? tokensCap; // null = use default maxTokens

    if (headroomMB >= 800) {
      ctx = nCtx;
    } else if (headroomMB >= 400) {
      // Low — shorter prompt and reduced context.
      ctx = reducedContextSize;
      debugPrint(
        '[LlmService] Low memory (${headroomMB}MB). '
        'Using shorter prompt context ($ctx).',
      );
    } else if (headroomMB >= 100) {
      ctx = minimumContextSize;
      debugPrint(
        '[LlmService] WARNING: Very low memory (${headroomMB}MB). '
        'Using emergency compact prompt ($ctx). '
        'Model ${modelInfo.id} ($modelMB MB), '
        'available=${availableMB}MB.',
      );
    } else {
      // Critically low — minimum settings with compact prompt.
      ctx = minimumContextSize;
      tokensCap = 256;
      debugPrint(
        '[LlmService] CRITICAL: Extremely low memory (${headroomMB}MB). '
        'Using minimum settings: compact prompt ($ctx), maxTokens=256. '
        'Model ${modelInfo.id} ($modelMB MB), '
        'available=${availableMB}MB, device=${deviceMB}MB.',
      );
    }

    // Store memory snapshot for debug UI.
    _lastInferenceMemoryInfo = (
      deviceMB: deviceMB,
      availableMB: availableMB,
      modelMB: modelMB,
      headroomMB: headroomMB,
      requestedContextSize: nCtx,
      contextSize: ctx,
      maxTokensCap: tokensCap,
    );

    return (contextSize: ctx, maxTokensCap: tokensCap);
  }

  static void _logFilter(String log) {
    if (log.contains('[fllama]') ||
        log.contains('loaded') ||
        log.contains('error') ||
        log.contains('Error') ||
        log.contains('token') ||
        log.contains('speed') ||
        log.contains('FAILED') ||
        log.contains('Model loaded') ||
        log.contains('BATCH') ||
        log.contains('Initialized')) {
      debugPrint('[llama.cpp] $log');
    }
  }

  /// Low-level chat completion. Returns the raw text output and metrics.
  ///
  /// If [onPartialResponse] is provided, it is called after every token with
  /// the accumulated response so far and the current token count.
  Future<({String text, LlmInferenceMetrics metrics})> _generate(
    String prompt, {
    int? overrideMaxTokens,
    void Function(String partial, int tokens)? onPartialResponse,
  }) async {
    // Cancel any still-running inference (e.g. leftover from hot-restart or
    // a previous phase) before starting a new one.  This reduces the window
    // for the "Callback invoked after it has been deleted" crash.
    cancelInference();
    debugPrint('[LlmService] _generate: _selectedModelId=$_selectedModelId _modelPath=$_modelPath');
    final modelInfo = await _ensureModel();
    debugPrint('[LlmService] _generate: after ensureModel _selectedModelId=$_selectedModelId modelInfo.id=${modelInfo.id} isLiteRtLm=${modelInfo.isLiteRtLm}');

    // Keep CPU at full speed during inference (Android foreground service).
    await LlmComputeService.instance.start();

    final stopwatch = Stopwatch()..start();

    final params = await _computeInferenceParams(modelInfo);

    // Apply maxTokens cap from memory check. The cap is the hard ceiling;
    // the caller's overrideMaxTokens or default maxTokens is also respected
    // by taking the minimum.
    int effectiveMaxTokens = overrideMaxTokens ?? maxTokens;
    if (params.maxTokensCap != null &&
        effectiveMaxTokens > params.maxTokensCap!) {
      debugPrint(
        '[LlmService] Capping maxTokens from $effectiveMaxTokens '
        'to ${params.maxTokensCap} due to low memory.',
      );
      effectiveMaxTokens = params.maxTokensCap!;
    }

    debugPrint(
      '[LlmService] Inference: model=${modelInfo.id} nCtx=${params.contextSize} '
      'maxTokens=$effectiveMaxTokens '
      'threads=$nThreads deviceRAM=${_deviceMemoryMB ?? "?"}MB',
    );

    String text;
    int tokenCount;

    if (modelInfo.isLiteRtLm) {
      // ---- LiteRT-LM path (Gemma 4 etc.) ----
      // Serialize access: wait for any in-flight LiteRT-LM call to finish.
      // The native engine crashes (SIGSEGV) if two generate calls overlap.
      while (_liteRtLmLock != null) {
        debugPrint('[LlmService] LiteRT-LM busy, waiting for previous call...');
        await _liteRtLmLock!.future;
      }
      _liteRtLmLock = Completer<void>();
      try {
      debugPrint(
        '[LlmService] LiteRT-LM generate: prompt length=${prompt.length}, '
        'first 200 chars: ${prompt.substring(0, prompt.length > 200 ? 200 : prompt.length)}',
      );
      final result = await _liteRtLmService.generate(
        prompt,
        temperature: temperature,
        topK: 40,
        topP: topP,
        onToken: (partial, tokens) {
          debugPrint(
            '[LlmService] LiteRT-LM onToken: tokens=$tokens, '
            'partial length=${partial.length}, first 200: ${partial.substring(0, partial.length > 200 ? 200 : partial.length)}',
          );
          onPartialResponse?.call(partial, tokens);
        },
      );
      debugPrint(
        '[LlmService] LiteRT-LM result: text="${result.text.substring(0, result.text.length > 500 ? 500 : result.text.length)}" '
        'tokens=${result.tokenCount} elapsed=${result.elapsedMs}ms cancelled=${result.cancelled}',
      );
      text = result.text.trim();
      tokenCount = result.tokenCount;
      } finally {
        _liteRtLmLock!.complete();
        _liteRtLmLock = null;
      }
    } else {
      // ---- fllama / llama.cpp path ----
      final completer = Completer<String>();
      tokenCount = 0;

      final request = OpenAiRequest(
        messages: [Message(Role.user, prompt)],
        modelPath: _modelPath!,
        maxTokens: effectiveMaxTokens,
        numGpuLayers: 0,
        numThreads: nThreads,
        temperature: temperature,
        topP: topP,
        frequencyPenalty: 0.0,
        presencePenalty: presencePenalty,
        contextSize: params.contextSize,
        logger: _logFilter,
        enableThinking: false,
      );

      _runningRequestId = await fllamaChat(request, (
        String response,
        String responseJson,
        bool done,
      ) {
        tokenCount++;
        onPartialResponse?.call(response, tokenCount);
        if (done && !completer.isCompleted) {
          completer.complete(response);
        }
      });

      text = (await completer.future).trim();
    }
    stopwatch.stop();

    // Release the foreground service + wake lock.
    await LlmComputeService.instance.stop();

    final wallTime = stopwatch.elapsed;
    final tokPerSec = wallTime.inMilliseconds > 0
        ? (tokenCount / (wallTime.inMilliseconds / 1000.0))
        : 0.0;

    final metrics = LlmInferenceMetrics(
      modelName: _selectedModelName,
      rawPrompt: prompt,
      rawResponse: text,
      wallTime: wallTime,
      completionTokens: tokenCount,
      tokensPerSecond: tokPerSec,
    );

    return (text: text, metrics: metrics);
  }

  /// Process a voice memo transcript: optionally correct transcription errors,
  /// then classify + summarise in a single LLM pass, and parse the structured
  /// JSON output.
  ///
  /// This is the main entry-point used by [VoiceNoteAiPipeline].
  Future<TranscriptResult> processTranscript(
    String transcript, {
    bool correctTranscription = true,
    String? classifyPromptOverride,
    String? promptStrategyOverride,
    void Function(String phase, String partialResponse, int tokens)? onProgress,
  }) async {
    _stateSubject.add(
      _stateSubject.value.copyWith(status: LlmServiceStatus.processing),
    );

    try {
      final totalStopwatch = Stopwatch()..start();
      debugPrint(
        '[LlmService] Processing transcript (${transcript.length} chars)',
      );

      // Pre-compute effective context size so we can select the right prompt.
      final modelInfo = await _ensureModel();
      final preParams = await _computeInferenceParams(modelInfo);
      final effectiveCtx = preParams.contextSize;

      String effectiveTranscript = transcript;
      LlmInferenceMetrics? correctionMetrics;
      String? correctedTranscription;

      // --- Step 1: Correct transcription errors if enabled ---
      if (correctTranscription) {
        final correctionPrompt = _buildCorrectionPrompt(transcript);
        final correctionMaxTokens = CorrectionPromptTemplate.estimateMaxTokens(
          transcript,
        );
        final correctionResult = await _generate(
          correctionPrompt,
          overrideMaxTokens: correctionMaxTokens,
          onPartialResponse: onProgress == null
              ? null
              : (partial, tokens) => onProgress('correcting', partial, tokens),
        );
        final corrected = correctionResult.text.trim();
        correctionMetrics = correctionResult.metrics;

        // Only use the correction if it looks like actual text (not JSON/noise)
        if (corrected.isNotEmpty &&
            !corrected.startsWith('{') &&
            corrected.length > 5) {
          correctedTranscription = corrected;
          effectiveTranscript = corrected;
          debugPrint('[LlmService] Corrected transcription: $corrected');
        } else {
          debugPrint(
            '[LlmService] Correction output not usable, using original',
          );
        }
      }

      // Brief pause between inference calls to let the native (C++) side
      // finish any post-done logging from the previous request. Without this,
      // the next fllamaChat call triggers cleanup of the previous logger
      // NativeCallable while C++ may still be invoking it, causing a fatal
      // "Callback invoked after it has been deleted" crash.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // --- Step 2: Route via lightweight pre-classifier ---
      final promptTemplate = classifyPromptOverride?.trim();
      String? routeResult;

      if (promptTemplate == null || promptTemplate.isEmpty) {
        // Run the router prompt to decide timer_alarm vs voice_memo
        final routerPrompt = ChronoPromptTemplate.render(
          ChronoPromptTemplate.routerTemplate,
          transcript: effectiveTranscript,
        );
        final routerGen = await _generate(
          routerPrompt,
          overrideMaxTokens: 32,
          onPartialResponse: onProgress == null
              ? null
              : (partial, tokens) => onProgress('routing', partial, tokens),
        );
        routeResult = _parseRouterOutput(_sanitizeModelOutput(routerGen.text));
        debugPrint(
          '[LlmService] Router: route=$routeResult '
          '(${routerGen.metrics.wallTime.inMilliseconds}ms)',
        );

        // Brief pause between inference calls
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Router detected no meaningful speech — return empty result.
        if (routeResult == 'none') {
          debugPrint(
            '[LlmService] Router returned "none" — no speech detected',
          );
          _stateSubject.add(
            _stateSubject.value.copyWith(status: LlmServiceStatus.ready),
          );
          return TranscriptResult(
            summary: '',
            category: 'note',
            actions: [],
            originalTranscription: transcript,
            correctedTranscription: correctedTranscription,
            correctionMetrics: correctionMetrics,
            actionChronoDetails: [],
          );
        }
      }

      // --- Step 3: Build the extraction prompt based on route ---
      final String prompt;
      final String promptStrategy;

      if (promptTemplate != null && promptTemplate.isNotEmpty) {
        prompt = _renderClassifyPromptTemplate(
          promptTemplate,
          transcript: effectiveTranscript,
        );
        promptStrategy = promptStrategyOverride ?? 'custom-template';
      } else if (routeResult == 'timer_alarm' || routeResult == 'mixed') {
        // For "mixed" inputs (e.g., "Set a timer for 5 min and buy milk"),
        // use the timer/alarm template to avoid losing the timer/alarm intent.
        // The non-timer items won't be extracted but the primary action is preserved.
        prompt = ChronoPromptTemplate.render(
          ChronoPromptTemplate.timerAlarmTemplate,
          transcript: effectiveTranscript,
        );
        promptStrategy = 'router→$routeResult';
      } else {
        prompt = _buildClassifyPrompt(
          effectiveTranscript,
          effectiveCtx: effectiveCtx,
        );
        promptStrategy = usesFullPrompt(effectiveCtx)
            ? 'router→voice_memo/full'
            : usesEmergencyCompactPrompt(effectiveCtx)
            ? 'router→voice_memo/emergency-compact'
            : 'router→voice_memo/compact';
      }

      final structuredResult = await _generateStructuredJsonWithRetry(
        prompt,
        promptStrategy: promptStrategy,
        phase: 'classifying',
        onProgress: onProgress,
      );
      final raw = structuredResult.raw;
      final classifyMetrics = structuredResult.metrics;

      debugPrint(
        '[LlmService] Classify done at ${totalStopwatch.elapsedMilliseconds}ms',
      );
      debugPrint('[LlmService] Raw AI response: $raw');

      // --- Parse JSON from output ---
      final result = structuredResult.result;

      _stateSubject.add(
        _stateSubject.value.copyWith(status: LlmServiceStatus.ready),
      );

      return TranscriptResult(
        summary: result.summary,
        category: result.category,
        actions: result.actions,
        actionChronoDetails: result.actionChronoDetails,
        extractedIntent: result.extractedIntent,
        extractedTitle: result.extractedTitle,
        datetimeExpressionOriginal: result.datetimeExpressionOriginal,
        datetimeExpressionEnglish: result.datetimeExpressionEnglish,
        resolvedDateTime: result.resolvedDateTime,
        resolverMethod: result.resolverMethod,
        originalTranscription: transcript,
        correctedTranscription: correctedTranscription,
        correctionMetrics: correctionMetrics,
        classifyMetrics: classifyMetrics,
      );
    } catch (e) {
      debugPrint('[LlmService] Failed to process transcript: $e');
      _stateSubject.add(
        _stateSubject.value.copyWith(
          status: LlmServiceStatus.error,
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Cancel a running inference (best-effort).
  void cancelInference() {
    if (_runningRequestId >= 0) {
      fllamaCancelInference(_runningRequestId);
      _runningRequestId = -1;
    }
    // Note: We do NOT cancel LiteRT-LM here because each generate() call
    // creates a fresh Conversation. Cancelling between phases would just
    // cancel an already-completed conversation, which is harmless but could
    // confuse the engine. Only cancel on explicit user action.
  }

  /// Cancel any running LiteRT-LM inference. Call this only for explicit
  /// user-initiated cancellation.
  void cancelLiteRtLmInference() {
    _liteRtLmService.cancel();
  }

  void dispose() {
    cancelInference();
    _liteRtLmService.dispose();
    _stateSubject.close();
  }

  // ---- Prompt construction ----

  String _buildCorrectionPrompt(String transcript) {
    return CorrectionPromptTemplate.render(
      CorrectionPromptTemplate.defaultTemplate,
      transcript: transcript,
    );
  }

  String _buildClassifyPrompt(String transcript, {int? effectiveCtx}) {
    // Use the standard 3-intent template (reminder/event/note).
    // Timer/alarm cases are handled by the two-stage router in processTranscript.
    const template = ChronoPromptTemplate.compactTemplate;
    return _renderClassifyPromptTemplate(template, transcript: transcript);
  }

  /// Parse the router prompt output into a route string.
  String _parseRouterOutput(String raw) {
    try {
      final start = raw.indexOf('{');
      if (start == -1) return 'voice_memo';
      final end = raw.lastIndexOf('}');
      if (end == -1) return 'voice_memo';
      final decoded =
          jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
      final route = (decoded['route'] as String?)?.trim().toLowerCase() ?? '';
      if (const {
        'timer_alarm',
        'voice_memo',
        'mixed',
        'none',
      }.contains(route)) {
        return route;
      }
      return 'voice_memo';
    } catch (_) {
      return 'voice_memo';
    }
  }

  String _renderClassifyPromptTemplate(
    String template, {
    required String transcript,
  }) {
    return ChronoPromptTemplate.render(template, transcript: transcript);
  }

  /// Word-count threshold for brain dump mode. Transcripts with more
  /// words than this use the brain dump prompt instead of the standard
  /// classify prompt.
  static const int brainDumpWordThreshold = 50;

  String _buildBrainDumpPrompt(String transcript) {
    final localNow = DateTime.now();
    final weekday = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][localNow.weekday - 1];
    final iso = localNow.toIso8601String();
    final tzOffset = localNow.timeZoneOffset;
    final tzSign = tzOffset.isNegative ? '-' : '+';
    final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
    final tzMinutes = (tzOffset.inMinutes.abs() % 60).toString().padLeft(
      2,
      '0',
    );
    final tz = '$tzSign$tzHours:$tzMinutes';

    return '''
You are a voice-note summarization assistant specializing in long, unstructured recordings.

Current local date/time: $iso ($weekday), timezone UTC$tz.
Use this to resolve relative references like "tomorrow", "next Tuesday", "in 30 minutes", etc.

The following transcript is from a "brain dump" — a long, stream-of-consciousness voice recording. It may contain:
- Multiple unrelated topics
- Rambling or repeated ideas
- Filler words and false starts
- Mixed actionable items and general thoughts

Return EXACTLY ONE valid JSON object.
Do not include markdown fences, explanations, or any text before/after the JSON.

Your job:
1. Produce a concise executive summary (2-3 sentences max)
2. Group the content into logical sections with headers
3. Extract any actionable items mentioned anywhere in the transcript
4. Assign the category "brain_dump"

Use this exact schema:
{
  "summary": "concise 2-3 sentence executive summary in the original language",
  "category": "brain_dump",
  "sections": [
    {
      "header": "Topic or theme heading",
      "bullets": ["key point 1", "key point 2"]
    }
  ],
  "actions": [
    {
      "type": "task" | "reminder" | "calendar_event",
      "title": "short action title in the original language",
      "notes": "optional extra details" | null,
      "due_date": "ISO-8601 datetime" | null,
      "start_time": "ISO-8601 datetime" | null,
      "end_time": "ISO-8601 datetime" | null,
      "location": "location text" | null,
      "priority": "low" | "medium" | "high" | null,
      "reminder_minutes": number | null
    }
  ]
}

Rules:
- Keep sections to 4 or fewer.
- Keep bullets concise (one line each).
- Extract ALL actionable items regardless of where they appear.
- If no actions exist, return an empty array.
- Preserve the transcript language.
- Do not invent dates, times, or locations. Use null when unknown.

Transcript: "$transcript"
JSON:

/no_think''';
  }

  /// Determine whether a transcript should use brain dump mode.
  bool isBrainDump(String transcript) {
    final wordCount = transcript.trim().split(RegExp(r'\s+')).length;
    return wordCount >= brainDumpWordThreshold;
  }

  /// Process a transcript using the brain dump prompt for long recordings.
  Future<TranscriptResult> processTranscriptBrainDump(
    String transcript, {
    bool correctTranscription = true,
    void Function(String phase, String partialResponse, int tokens)? onProgress,
  }) async {
    _stateSubject.add(
      _stateSubject.value.copyWith(status: LlmServiceStatus.processing),
    );

    try {
      debugPrint(
        '[LlmService] Processing brain dump transcript (${transcript.length} chars)',
      );

      String effectiveTranscript = transcript;
      LlmInferenceMetrics? correctionMetrics;
      String? correctedTranscription;

      // --- Step 1: Correct transcription errors if enabled ---
      if (correctTranscription) {
        final correctionPrompt = _buildCorrectionPrompt(transcript);
        final correctionMaxTokens = CorrectionPromptTemplate.estimateMaxTokens(
          transcript,
        );
        final correctionResult = await _generate(
          correctionPrompt,
          overrideMaxTokens: correctionMaxTokens,
          onPartialResponse: onProgress == null
              ? null
              : (partial, tokens) => onProgress('correcting', partial, tokens),
        );

        final corrected = correctionResult.text.trim();
        correctionMetrics = correctionResult.metrics;

        if (corrected.isNotEmpty &&
            !corrected.startsWith('{') &&
            corrected.length > 5) {
          correctedTranscription = corrected;
          effectiveTranscript = corrected;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));

      // --- Step 2: Brain dump extraction prompt ---
      final prompt = _buildBrainDumpPrompt(effectiveTranscript);
      final structuredResult = await _generateStructuredJsonWithRetry(
        prompt,
        overrideMaxTokens: 768,
        promptStrategy: 'brain_dump+/no_think',
        phase: 'summarizing',
        onProgress: onProgress,
      );
      final raw = structuredResult.raw;
      final classifyMetrics = structuredResult.metrics;

      debugPrint('[LlmService] Raw brain dump response: $raw');

      // Parse using the same JSON extraction logic
      final result = structuredResult.result;
      final jsonStr = classifyMetrics.parsedJson;

      _stateSubject.add(
        _stateSubject.value.copyWith(status: LlmServiceStatus.ready),
      );

      // Build a rich summary including sections if present
      String richSummary = result.summary;
      if (jsonStr != null) {
        try {
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          final sections = parsed['sections'] as List<dynamic>?;
          if (sections != null && sections.isNotEmpty) {
            final buf = StringBuffer(result.summary);
            buf.writeln();
            for (final section in sections.whereType<Map<String, dynamic>>()) {
              final header = section['header'] as String?;
              final bullets =
                  (section['bullets'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList() ??
                  [];
              if (header != null) {
                buf.writeln('\n## $header');
                for (final bullet in bullets) {
                  buf.writeln('• $bullet');
                }
              }
            }
            richSummary = buf.toString().trim();
          }
        } catch (_) {
          // Fall back to plain summary
        }
      }

      return TranscriptResult(
        summary: richSummary,
        category: 'brain_dump',
        actions: result.actions,
        actionChronoDetails: result.actionChronoDetails,
        extractedIntent: result.extractedIntent,
        extractedTitle: result.extractedTitle,
        datetimeExpressionOriginal: result.datetimeExpressionOriginal,
        datetimeExpressionEnglish: result.datetimeExpressionEnglish,
        resolvedDateTime: result.resolvedDateTime,
        resolverMethod: result.resolverMethod,
        originalTranscription: transcript,
        correctedTranscription: correctedTranscription,
        correctionMetrics: correctionMetrics,
        classifyMetrics: classifyMetrics,
      );
    } catch (e) {
      debugPrint('[LlmService] Failed to process brain dump: $e');
      _stateSubject.add(
        _stateSubject.value.copyWith(
          status: LlmServiceStatus.error,
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  // ---- Output parsing ----

  Future<
    ({
      String raw,
      TranscriptResult result,
      LlmInferenceMetrics metrics,
      int attempts,
    })
  >
  _generateStructuredJsonWithRetry(
    String prompt, {
    int? overrideMaxTokens,
    required String promptStrategy,
    String phase = 'classifying',
    void Function(String phase, String partialResponse, int tokens)? onProgress,
  }) async {
    String raw = '';
    TranscriptResult parsed = const TranscriptResult(
      summary: '',
      category: 'note',
    );
    LlmInferenceMetrics? lastMetrics;
    Duration totalWallTime = Duration.zero;
    var totalCompletionTokens = 0;
    var attempts = 0;

    while (attempts < _maxStructuredOutputAttempts) {
      attempts++;
      final genResult = await _generate(
        prompt,
        overrideMaxTokens: overrideMaxTokens,
        onPartialResponse: onProgress == null
            ? null
            : (partial, tokens) => onProgress(phase, partial, tokens),
      );
      raw = genResult.text;
      parsed = _parseTranscriptResult(raw);
      lastMetrics = genResult.metrics;
      totalWallTime += genResult.metrics.wallTime;
      totalCompletionTokens += genResult.metrics.completionTokens;

      final needsRetry = _shouldRetryStructuredOutput(raw, parsed);

      if (!needsRetry || attempts >= _maxStructuredOutputAttempts) {
        break;
      }

      debugPrint(
        '[LlmService] Retrying invalid structured output '
        '(attempt ${attempts + 1}/$_maxStructuredOutputAttempts)',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    final parsedJson =
        _chronoLlmParser.extractFirstJsonArray(raw) ??
        _extractFirstJsonObject(raw);
    final metrics = LlmInferenceMetrics(
      modelName: _selectedModelName,
      rawPrompt: prompt,
      rawResponse: raw,
      parsedJson: parsedJson,
      wallTime: totalWallTime,
      completionTokens: totalCompletionTokens,
      tokensPerSecond: lastMetrics?.tokensPerSecond ?? 0.0,
      attempts: attempts,
      promptStrategy: promptStrategy,
      retryEnabled: _maxStructuredOutputAttempts > 1,
    );

    return (raw: raw, result: parsed, metrics: metrics, attempts: attempts);
  }

  String _sanitizeModelOutput(String raw) {
    return _chronoLlmParser.sanitizeModelOutput(raw);
  }

  bool _shouldRetryStructuredOutput(String raw, TranscriptResult result) {
    final cleaned = _sanitizeModelOutput(raw);
    final jsonStr =
        _chronoLlmParser.extractFirstJsonArray(cleaned) ??
        _extractFirstJsonObject(cleaned);

    if (jsonStr == null) {
      return true;
    }

    if (result.summary.trim().isEmpty) {
      return true;
    }

    if (result.summary.trim() == cleaned && result.actions.isEmpty) {
      return true;
    }

    if (result.category == 'note' &&
        result.actions.isEmpty &&
        (result.summary.trim() == cleaned ||
            result.summary.trim() == jsonStr.trim())) {
      return true;
    }

    return false;
  }

  String? _extractFirstJsonObject(String raw) {
    return _chronoLlmParser.extractFirstJsonObject(raw);
  }

  String _normalizeCategory(String? rawCategory) {
    switch ((rawCategory ?? '').trim().toLowerCase()) {
      case 'todo':
      case 'task':
        return 'task';
      case 'reminder':
        return 'reminder';
      case 'event':
      case 'meeting':
      case 'calendar_event':
        return 'meeting';
      case 'idea':
        return 'idea';
      default:
        return 'note';
    }
  }

  String _normalizeActionType(String? rawType, String category) {
    switch ((rawType ?? '').trim().toLowerCase()) {
      case 'calendar_event':
      case 'event':
      case 'meeting':
      case 'schedule':
        return 'calendar_event';
      case 'reminder':
        return 'reminder';
      case 'task':
      case 'todo':
        return 'task';
      default:
        return category == 'meeting' ? 'calendar_event' : 'task';
    }
  }

  static String _friendlySummary(ChronoLlmExtraction first, String raw) {
    if (first.intent == 'timer' && first.durationSeconds != null) {
      final d = first.durationSeconds!;
      final h = d ~/ 3600;
      final m = (d % 3600) ~/ 60;
      final s = d % 60;
      final parts = <String>[
        if (h > 0) '${h}h',
        if (m > 0) '${m}m',
        if (s > 0 || (h == 0 && m == 0)) '${s}s',
      ];
      final dur = parts.join(' ');
      return first.title.isNotEmpty
          ? 'Timer $dur — ${first.title}'
          : 'Timer $dur';
    }
    if (first.intent == 'alarm') {
      final expr =
          first.datetimeExpressionEnglish ?? first.datetimeExpressionOriginal;
      if (expr != null) {
        return first.title.isNotEmpty
            ? 'Alarm $expr — ${first.title}'
            : 'Alarm $expr';
      }
      return first.title.isNotEmpty ? 'Alarm — ${first.title}' : 'Alarm';
    }
    return first.title.isNotEmpty ? first.title : raw.trim();
  }

  TranscriptResult _buildTranscriptResultFromChronoExtractions(
    List<ChronoLlmExtraction> extractions,
    String raw,
  ) {
    final actions = <ExtractedActionResult>[];
    final chronoDetails = <ActionChronoDebug>[];
    String? firstResolvedDateTime;
    String? firstResolverMethod;

    for (final extraction in extractions) {
      final title = extraction.title.isNotEmpty ? extraction.title : raw.trim();

      if (extraction.intent == 'note') {
        // Notes don't produce actions with time resolution
        actions.add(
          ExtractedActionResult(
            type: 'task',
            title: title,
            notes: extraction.datetimeExpressionOriginal,
          ),
        );
        chronoDetails.add(
          ActionChronoDebug(
            intent: extraction.intent,
            title: title,
            datetimeExpressionOriginal: extraction.datetimeExpressionOriginal,
            datetimeExpressionEnglish: extraction.datetimeExpressionEnglish,
          ),
        );
        continue;
      }

      if (extraction.intent == 'timer') {
        // Timer: duration-based, no datetime resolution needed
        actions.add(
          ExtractedActionResult(
            type: 'timer',
            title: title,
            durationSeconds: extraction.durationSeconds,
          ),
        );
        chronoDetails.add(
          ActionChronoDebug(
            intent: extraction.intent,
            title: title,
            durationSeconds: extraction.durationSeconds,
          ),
        );
        continue;
      }

      final englishExpression = extraction.datetimeExpressionEnglish;
      final resolved = englishExpression == null
          ? null
          : _timeExpressionResolver.resolve(englishExpression);

      firstResolvedDateTime ??= resolved?.dateTime.toIso8601String();
      firstResolverMethod ??= resolved?.method;

      if (extraction.intent == 'alarm') {
        // Alarm: clock-time based, resolve time
        actions.add(
          ExtractedActionResult(
            type: 'alarm',
            title: title,
            startTime: resolved?.dateTime.toIso8601String(),
          ),
        );
        chronoDetails.add(
          ActionChronoDebug(
            intent: extraction.intent,
            title: title,
            datetimeExpressionOriginal: extraction.datetimeExpressionOriginal,
            datetimeExpressionEnglish: extraction.datetimeExpressionEnglish,
            resolvedDateTime: resolved?.dateTime.toIso8601String(),
            resolverMethod: resolved?.method,
          ),
        );
        continue;
      }

      actions.add(
        ExtractedActionResult(
          type: extraction.intent == 'event' ? 'calendar_event' : 'reminder',
          title: title,
          notes: extraction.datetimeExpressionOriginal,
          dueDate: extraction.intent == 'reminder'
              ? resolved?.dateTime.toIso8601String()
              : null,
          startTime: extraction.intent == 'event'
              ? resolved?.dateTime.toIso8601String()
              : null,
        ),
      );
      chronoDetails.add(
        ActionChronoDebug(
          intent: extraction.intent,
          title: title,
          datetimeExpressionOriginal: extraction.datetimeExpressionOriginal,
          datetimeExpressionEnglish: extraction.datetimeExpressionEnglish,
          resolvedDateTime: resolved?.dateTime.toIso8601String(),
          resolverMethod: resolved?.method,
        ),
      );
    }

    final first = extractions.first;
    final summary = _friendlySummary(first, raw);
    final category = switch (first.intent) {
      'event' => 'meeting',
      'reminder' => 'reminder',
      'timer' => 'timer',
      'alarm' => 'alarm',
      _ => 'note',
    };

    return TranscriptResult(
      summary: summary,
      category: category,
      actions: actions,
      actionChronoDetails: chronoDetails,
      extractedIntent: first.intent,
      extractedTitle: first.title,
      datetimeExpressionOriginal: first.datetimeExpressionOriginal,
      datetimeExpressionEnglish: first.datetimeExpressionEnglish,
      resolvedDateTime: firstResolvedDateTime,
      resolverMethod: firstResolverMethod,
    );
  }

  TranscriptResult _parseTranscriptResult(String raw) {
    final cleaned = _sanitizeModelOutput(raw);

    // Try parsing via chrono parser first (handles both array and object)
    final chronoResult = _chronoLlmParser.parse(cleaned);
    if (chronoResult.extractions.isNotEmpty) {
      return _buildTranscriptResultFromChronoExtractions(
        chronoResult.extractions,
        raw,
      );
    }

    final jsonStr = _extractFirstJsonObject(cleaned);

    if (jsonStr == null) {
      debugPrint(
        '[LlmService] Failed to parse AI response: '
        'FormatException: No JSON object found',
      );
      return TranscriptResult(summary: cleaned.trim(), category: 'note');
    }

    try {
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      final category = _normalizeCategory(parsed['category'] as String?);
      final summary = (parsed['summary'] as String?)?.trim();
      final title = (parsed['title'] as String?)?.trim();

      final actions = <ExtractedActionResult>[];

      final parsedActions = parsed['actions'];
      if (parsedActions is List) {
        for (final action in parsedActions.whereType<Map<String, dynamic>>()) {
          final actionTitle =
              ((action['title'] ?? action['summary']) as String?)?.trim() ?? '';
          if (actionTitle.isEmpty) {
            continue;
          }

          actions.add(
            ExtractedActionResult(
              type: _normalizeActionType(action['type'] as String?, category),
              title: actionTitle,
              notes: ((action['notes'] ?? action['body']) as String?)?.trim(),
              dueDate: (action['due_date'] ?? action['dueDate']) as String?,
              startTime:
                  (action['start_time'] ?? action['startTime']) as String?,
              location: (action['location'] as String?)?.trim(),
            ),
          );
        }
      }

      if (actions.isEmpty) {
        final actionItems =
            (parsed['action_items'] as List<dynamic>?)
                ?.whereType<String>()
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList() ??
            const <String>[];

        for (final item in actionItems) {
          actions.add(
            ExtractedActionResult(
              type: category == 'meeting' ? 'calendar_event' : 'task',
              title: item,
            ),
          );
        }
      }

      final resolvedSummary = (summary != null && summary.isNotEmpty)
          ? summary
          : (title ?? '').trim();

      return TranscriptResult(
        summary: resolvedSummary.isEmpty ? raw.trim() : resolvedSummary,
        category: category,
        actions: actions,
      );
    } catch (e) {
      debugPrint('[LlmService] Failed to parse AI response: $e');
      return TranscriptResult(summary: jsonStr, category: 'note');
    }
  }
}
