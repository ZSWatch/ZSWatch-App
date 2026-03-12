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

  /// Per-model GPU layer limit. When non-null, overrides
  /// [LlmService.numGpuLayers]. Set to a low value (or 0) for models that
  /// exceed available Metal VRAM on smaller devices.
  final int? maxGpuLayers;

  const LlmModelInfo({
    required this.id,
    required this.displayName,
    required this.family,
    required this.filename,
    this.downloadUrl,
    this.expectedSizeBytes,
    this.userProvided = false,
    this.contextSize,
    this.maxGpuLayers,
  });

  bool get isDownloadable => downloadUrl != null;

  String get shortSourceLabel => userProvided ? 'Imported' : 'Catalog';
}

/// Status of the LLM service.
enum LlmServiceStatus {
  idle,
  downloading,
  processing,
  ready,
  error,
}

/// How well a model fits into available device memory.
enum ModelMemoryFit {
  /// Plenty of headroom — full context, full GPU.
  comfortable,

  /// Tight — context will be reduced but GPU is still used.
  reduced,

  /// Very tight — minimal context and CPU-only fallback.
  cpuFallback,
}

/// Result of [LlmService.checkModelFit] for a specific model on this device.
class ModelFitResult {
  final ModelMemoryFit fit;
  final int contextSize;
  final int gpuLayers;
  final int deviceMemoryMB;
  final int modelSizeMB;
  final int headroomMB;

  const ModelFitResult({
    required this.fit,
    required this.contextSize,
    required this.gpuLayers,
    required this.deviceMemoryMB,
    required this.modelSizeMB,
    required this.headroomMB,
  });

  /// Human-readable summary for the UI.
  String get summary {
    switch (fit) {
      case ModelMemoryFit.comfortable:
        return 'Fits well — full performance';
      case ModelMemoryFit.reduced:
        return 'Tight fit — context reduced to $contextSize tokens';
      case ModelMemoryFit.cpuFallback:
        return 'Low memory — CPU-only mode (slower)';
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
  }) =>
      LlmServiceState(
        status: status ?? this.status,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        error: error ?? this.error,
      );
}

/// One extracted action from the LLM output.
class ExtractedActionResult {
  final String type; // "task", "calendar_event", "reminder"
  final String title;
  final String? notes;
  final String? dueDate;
  final String? startTime;
  final String? location;

  const ExtractedActionResult({
    required this.type,
    required this.title,
    this.notes,
    this.dueDate,
    this.startTime,
    this.location,
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

  LlmInferenceMetrics copyWithParsedJson(String? json) =>
      LlmInferenceMetrics(
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
  static const List<LlmModelInfo> catalogModels = [
    LlmModelInfo(
      id: defaultModelId,
      displayName: 'Qwen2.5 1.5B Instruct · Q4_K_M',
      family: 'Qwen2.5-1.5B-Instruct',
      filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      expectedSizeBytes: 1120 * 1024 * 1024,
    ),
    LlmModelInfo(
      id: 'qwen25_1_5b_q5_k_m',
      displayName: 'Qwen2.5 1.5B Instruct · Q5_K_M',
      family: 'Qwen2.5-1.5B-Instruct',
      filename: 'qwen2.5-1.5b-instruct-q5_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q5_k_m.gguf',
      expectedSizeBytes: 1290 * 1024 * 1024,
    ),
    LlmModelInfo(
      id: 'qwen25_1_5b_q8_0',
      displayName: 'Qwen2.5 1.5B Instruct · Q8_0',
      family: 'Qwen2.5-1.5B-Instruct',
      filename: 'qwen2.5-1.5b-instruct-q8_0.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q8_0.gguf',
      expectedSizeBytes: 1890 * 1024 * 1024,
    ),
    LlmModelInfo(
      id: 'qwen3_1_7b_q4_k_m',
      displayName: 'Qwen3 1.7B Instruct · Q4_K_M',
      family: 'Qwen3-1.7B',
      filename: 'Qwen3-1.7B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/ggml-org/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf',
      expectedSizeBytes: 1220 * 1024 * 1024,
    ),
    LlmModelInfo(
      id: 'smollm3_3b_q4_k_m',
      displayName: 'SmolLM3 3B Instruct · Q4_K_M',
      family: 'SmolLM3-3B',
      filename: 'SmolLM3-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/ggml-org/SmolLM3-3B-GGUF/resolve/main/SmolLM3-Q4_K_M.gguf',
      expectedSizeBytes: 1840 * 1024 * 1024,
    ),
    LlmModelInfo(
      id: 'qwen35_2b_q4_k_m',
      displayName: 'Qwen3.5 2B Instruct · Q4_K_M (Experimental)',
      family: 'Qwen3.5-2B',
      filename: 'Qwen3.5-2B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
      expectedSizeBytes: 1222 * 1024 * 1024,
    ),
    LlmModelInfo(
      id: 'llama32_3b_q4_k_m',
      displayName: 'Llama 3.2 3B Instruct · Q4_K_M',
      family: 'Llama-3.2-3B-Instruct',
      filename: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      expectedSizeBytes: 2020 * 1024 * 1024,
    ),
  ];

  String _selectedModelId = defaultModelId;
  String _selectedModelName = 'Qwen2.5 1.5B Instruct · Q4_K_M';

  /// Human-readable name shown in the UI / persisted alongside AI results.
  String get modelName => _selectedModelName;
  String get selectedModelId => _selectedModelId;

  // ---- Tunables ----
  int nCtx = 2048;
  int nThreads = 2;
  int maxTokens = 512;
  double temperature = 0.1;
  double topP = 0.9;
  double presencePenalty = 1.1;

  /// GPU layer offloading. 99 = all layers on Metal/GPU, 0 = CPU-only.
  int numGpuLayers = 99;

  // ---- Internal state ----
  String? _modelPath;
  int _runningRequestId = -1;
  int? _deviceMemoryMB;

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

    ModelMemoryFit fit;
    if (params.gpuLayers == 0) {
      fit = ModelMemoryFit.cpuFallback;
    } else if (params.contextSize < nCtx) {
      fit = ModelMemoryFit.reduced;
    } else {
      fit = ModelMemoryFit.comfortable;
    }

    return ModelFitResult(
      fit: fit,
      contextSize: params.contextSize,
      gpuLayers: params.gpuLayers,
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

  static String customModelIdForFilename(String filename) => 'custom::$filename';

  static bool _isCustomModelId(String id) => id.startsWith('custom::');

  Future<List<LlmModelInfo>> availableModels() async {
    final importedDir = Directory(await _importedModelDir());
    final imported = <LlmModelInfo>[];

    if (importedDir.existsSync()) {
      for (final entity in importedDir.listSync()) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.gguf')) {
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
          ),
        );
      }
    }

    imported.sort((a, b) => a.displayName.compareTo(b.displayName));
    return [...catalogModels, ...imported];
  }

  void selectModel(String modelId) {
    _selectedModelId = modelId;
    final builtIn = catalogModels.where((m) => m.id == modelId).firstOrNull;
    _selectedModelName = builtIn?.displayName ??
        (_isCustomModelId(modelId)
            ? modelId.replaceFirst('custom::', '')
            : catalogModels.first.displayName);
    _modelPath = null;
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
    final model = await _resolveModelById(modelId ?? _selectedModelId) ??
        catalogModels.first;
    return File(await _modelFilePathFor(model)).existsSync();
  }

  /// Size of the local model file in bytes, or null if not downloaded.
  Future<int?> modelFileSize({String? modelId}) async {
    final model = await _resolveModelById(modelId ?? _selectedModelId) ??
        catalogModels.first;
    final f = File(await _modelFilePathFor(model));
    return f.existsSync() ? f.lengthSync() : null;
  }

  // ---- Model management ----

  /// Download the GGUF model from HuggingFace.
  Future<void> downloadModel({String? modelId}) async {
    final model = await _resolveModelById(modelId ?? _selectedModelId) ??
        catalogModels.first;

    if (!model.isDownloadable) {
      throw StateError('Selected model is imported and cannot be downloaded.');
    }

    if (await isModelDownloaded(modelId: model.id)) {
      debugPrint('[LlmService] Model already downloaded');
      return;
    }

    _stateSubject.add(_stateSubject.value.copyWith(
      status: LlmServiceStatus.downloading,
      downloadProgress: 0.0,
    ));

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
          _stateSubject.add(_stateSubject.value.copyWith(
            downloadProgress: received / contentLength,
          ));
        }
      }

      await sink.close();
      client.close();

      // Atomic rename
      File(tmpPath).renameSync(destPath);

      _stateSubject.add(_stateSubject.value.copyWith(
        status: LlmServiceStatus.ready,
        downloadProgress: 1.0,
      ));

      _selectedModelName = model.displayName;
      debugPrint('[LlmService] Model downloaded to $destPath');
    } catch (e) {
      _stateSubject.add(_stateSubject.value.copyWith(
        status: LlmServiceStatus.error,
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// Delete the local model file.
  Future<void> deleteModel({String? modelId}) async {
    final model = await _resolveModelById(modelId ?? _selectedModelId) ??
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
    if (!source.path.toLowerCase().endsWith('.gguf')) {
      throw ArgumentError('Only .gguf models can be imported.');
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
    );

    selectModel(importedModel.id);
    return importedModel;
  }

  // ---- Inference ----

  /// Ensure _modelPath is set (lazy init).
  Future<void> _ensureModel() async {
    if (_modelPath != null) return;
    final model = await currentModelInfo();
    final path = await _modelFilePathFor(model);
    if (!File(path).existsSync()) {
      throw StateError(
        'Selected model is not available locally. Download or import it first.',
      );
    }
    _selectedModelName = model.displayName;
    _modelPath = path;
  }

  // ---- Memory-aware tunables ----

  static const MethodChannel _deviceChannel =
      MethodChannel('dev.zswatch.app/productivity');

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

  /// Compute context size dynamically based on available device RAM and model
  /// size. Uses [LlmModelInfo.contextSize] if explicitly set, otherwise scales
  /// down when the model weight file would leave too little headroom for the
  /// KV cache + compute buffers on the GPU.
  ///
  /// Heuristic budget (conservative):
  ///   usableGPU ≈ deviceRAM × 0.55          (OS + app + Flutter overhead)
  ///   headroom  = usableGPU − modelFileSize
  ///   if headroom ≥ 600 MB → nCtx 2048, full GPU
  ///   if headroom ≥ 300 MB → nCtx 1024, full GPU
  ///   if headroom ≥ 100 MB → nCtx  512, full GPU
  ///   else                 → nCtx  512, CPU-only (avoid Metal OOM crash)
  Future<({int contextSize, int gpuLayers})> _computeInferenceParams(
    LlmModelInfo modelInfo,
  ) async {
    // Explicit per-model overrides win.
    final explicitCtx = modelInfo.contextSize;
    final explicitGpu = modelInfo.maxGpuLayers;
    if (explicitCtx != null && explicitGpu != null) {
      return (contextSize: explicitCtx, gpuLayers: explicitGpu);
    }

    final deviceMB = await _queryDeviceMemoryMB();
    final modelMB = (modelInfo.expectedSizeBytes ?? 0) ~/ (1024 * 1024);

    // On iOS, Metal shares unified memory with the system. After OS + app +
    // Flutter + BLE overhead, roughly 55% is available for the GPU working set.
    // On Android the GPU typically has even less available headroom.
    final usableMB = (deviceMB * 0.55).round();
    final headroomMB = usableMB - modelMB;

    int ctx;
    int gpu;

    if (headroomMB >= 600) {
      ctx = nCtx; // full context (default 2048)
      gpu = numGpuLayers;
    } else if (headroomMB >= 300) {
      ctx = 1024;
      gpu = numGpuLayers;
    } else if (headroomMB >= 100) {
      ctx = 512;
      gpu = numGpuLayers;
    } else {
      // Very tight — fall back to CPU-only to avoid Metal page-fault crash.
      ctx = 512;
      gpu = 0;
      debugPrint(
        '[LlmService] WARNING: Low memory headroom (${headroomMB}MB). '
        'Falling back to CPU-only inference to prevent GPU crash. '
        'Model ${modelInfo.id} ($modelMB MB) on device with $deviceMB MB RAM.',
      );
    }

    // Let explicit per-model values override the computed ones.
    return (
      contextSize: explicitCtx ?? ctx,
      gpuLayers: explicitGpu ?? gpu,
    );
  }

  static void _logFilter(String log) {
    if (log.contains('loaded') ||
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
    await _ensureModel();

    final completer = Completer<String>();
    final stopwatch = Stopwatch()..start();
    int tokenCount = 0;

    final modelInfo = await currentModelInfo();
    final params = await _computeInferenceParams(modelInfo);

    debugPrint(
      '[LlmService] Inference: model=${modelInfo.id} nCtx=${params.contextSize} '
      'gpuLayers=${params.gpuLayers} deviceRAM=${_deviceMemoryMB ?? "?"}MB',
    );

    final request = OpenAiRequest(
      messages: [Message(Role.user, prompt)],
      modelPath: _modelPath!,
      maxTokens: overrideMaxTokens ?? maxTokens,
      numGpuLayers: params.gpuLayers,
      temperature: temperature,
      topP: topP,
      frequencyPenalty: 0.0,
      presencePenalty: presencePenalty,
      contextSize: params.contextSize,
      logger: _logFilter,
    );

    _runningRequestId = await fllamaChat(
      request,
      (String response, String responseJson, bool done) {
        tokenCount++;
        onPartialResponse?.call(response, tokenCount);
        if (done && !completer.isCompleted) {
          completer.complete(response);
        }
      },
    );

    final text = (await completer.future).trim();
    stopwatch.stop();

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
      debugPrint(
        '[LlmService] Processing transcript (${transcript.length} chars)',
      );

      String effectiveTranscript = transcript;
      LlmInferenceMetrics? correctionMetrics;
      String? correctedTranscription;

      // --- Step 1: Correct transcription errors if enabled ---
      if (correctTranscription) {
        final correctionPrompt = _buildCorrectionPrompt(transcript);
        final correctionMaxTokens =
            CorrectionPromptTemplate.estimateMaxTokens(transcript);
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
              '[LlmService] Correction output not usable, using original');
        }
      }

      // Brief pause between inference calls to let the native (C++) side
      // finish any post-done logging from the previous request. Without this,
      // the next fllamaChat call triggers cleanup of the previous logger
      // NativeCallable while C++ may still be invoking it, causing a fatal
      // "Callback invoked after it has been deleted" crash.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // --- Step 2: Build the extraction prompt ---
      final promptTemplate = classifyPromptOverride?.trim();
      final prompt = (promptTemplate != null && promptTemplate.isNotEmpty)
          ? _renderClassifyPromptTemplate(
              promptTemplate,
              transcript: effectiveTranscript,
            )
          : _buildClassifyPrompt(effectiveTranscript);
      final structuredResult = await _generateStructuredJsonWithRetry(
        prompt,
        promptStrategy: (promptTemplate != null && promptTemplate.isNotEmpty)
            ? (promptStrategyOverride ?? 'custom-template')
            : 'full+/no_think',
        phase: 'classifying',
        onProgress: onProgress,
      );
      final raw = structuredResult.raw;
      final classifyMetrics = structuredResult.metrics;

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
  }

  void dispose() {
    cancelInference();
    _stateSubject.close();
  }

  // ---- Prompt construction ----

  String _buildCorrectionPrompt(String transcript) {
    return CorrectionPromptTemplate.render(
      CorrectionPromptTemplate.defaultTemplate,
      transcript: transcript,
    );
  }

  String _buildClassifyPrompt(String transcript) {
    return _renderClassifyPromptTemplate(
      defaultClassifyPromptTemplate,
      transcript: transcript,
    );
  }

  String _renderClassifyPromptTemplate(
    String template, {
    required String transcript,
  }) {
    return ChronoPromptTemplate.render(
      template,
      transcript: transcript,
    );
  }

  /// Word-count threshold for brain dump mode. Transcripts with more
  /// words than this use the brain dump prompt instead of the standard
  /// classify prompt.
  static const int brainDumpWordThreshold = 50;

  String _buildBrainDumpPrompt(String transcript) {
    final localNow = DateTime.now();
    final weekday = const [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ][localNow.weekday - 1];
    final iso = localNow.toIso8601String();
    final tzOffset = localNow.timeZoneOffset;
    final tzSign = tzOffset.isNegative ? '-' : '+';
    final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
    final tzMinutes = (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
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
        final correctionMaxTokens =
            CorrectionPromptTemplate.estimateMaxTokens(transcript);
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
              final bullets = (section['bullets'] as List<dynamic>?)
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

  Future<({
    String raw,
    TranscriptResult result,
    LlmInferenceMetrics metrics,
    int attempts,
  })> _generateStructuredJsonWithRetry(
    String prompt, {
    int? overrideMaxTokens,
    required String promptStrategy,
    String phase = 'classifying',
    void Function(String phase, String partialResponse, int tokens)? onProgress,
  }) async {
    String raw = '';
    TranscriptResult parsed = const TranscriptResult(summary: '', category: 'note');
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

      if (!_shouldRetryStructuredOutput(raw, parsed) ||
          attempts >= _maxStructuredOutputAttempts) {
        break;
      }

      debugPrint(
        '[LlmService] Retrying invalid structured output '
        '(attempt ${attempts + 1}/$_maxStructuredOutputAttempts)',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    final parsedJson = _extractFirstJsonObject(raw);
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

    return (
      raw: raw,
      result: parsed,
      metrics: metrics,
      attempts: attempts,
    );
  }

  String _sanitizeModelOutput(String raw) {
    return _chronoLlmParser.sanitizeModelOutput(raw);
  }

  bool _shouldRetryStructuredOutput(String raw, TranscriptResult result) {
    final cleaned = _sanitizeModelOutput(raw);
    final jsonStr = _extractFirstJsonObject(cleaned);

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
        (result.summary.trim() == cleaned || result.summary.trim() == jsonStr.trim())) {
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

  ChronoLlmExtraction? _parseChronoExtractionResult(
    Map<String, dynamic> parsed,
  ) {
    return _chronoLlmParser.parse(jsonEncode(parsed)).extraction;
  }

  TranscriptResult _buildTranscriptResultFromChronoExtraction(
    ChronoLlmExtraction extraction,
    String raw,
  ) {
    final summary = extraction.title.isNotEmpty
        ? extraction.title
        : raw.trim();
    final category = switch (extraction.intent) {
      'event' => 'meeting',
      'reminder' => 'reminder',
      _ => 'note',
    };

    if (extraction.intent == 'note') {
      return TranscriptResult(
        summary: summary,
        category: 'note',
        extractedIntent: extraction.intent,
        extractedTitle: extraction.title,
        datetimeExpressionOriginal: extraction.datetimeExpressionOriginal,
        datetimeExpressionEnglish: extraction.datetimeExpressionEnglish,
      );
    }

    final englishExpression = extraction.datetimeExpressionEnglish;
    final resolved = englishExpression == null
        ? null
        : _timeExpressionResolver.resolve(englishExpression);

    final action = ExtractedActionResult(
      type: extraction.intent == 'event' ? 'calendar_event' : 'reminder',
      title: summary,
      notes: extraction.datetimeExpressionOriginal,
      dueDate: extraction.intent == 'reminder' ? resolved?.dateTime.toIso8601String() : null,
      startTime: extraction.intent == 'event' ? resolved?.dateTime.toIso8601String() : null,
    );

    return TranscriptResult(
      summary: summary,
      category: category,
      actions: [action],
      extractedIntent: extraction.intent,
      extractedTitle: extraction.title,
      datetimeExpressionOriginal: extraction.datetimeExpressionOriginal,
      datetimeExpressionEnglish: extraction.datetimeExpressionEnglish,
      resolvedDateTime: resolved?.dateTime.toIso8601String(),
      resolverMethod: resolved?.method,
    );
  }

  TranscriptResult _parseTranscriptResult(String raw) {
    final cleaned = _sanitizeModelOutput(raw);
    final jsonStr = _extractFirstJsonObject(cleaned);

    if (jsonStr == null) {
      debugPrint('[LlmService] Failed to parse AI response: '
          'FormatException: No JSON object found');
      return TranscriptResult(
        summary: cleaned.trim(),
        category: 'note',
      );
    }

    try {
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      final chronoExtraction = _parseChronoExtractionResult(parsed);
      if (chronoExtraction != null) {
        return _buildTranscriptResultFromChronoExtraction(
          chronoExtraction,
          raw,
        );
      }

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
              startTime: (action['start_time'] ?? action['startTime']) as String?,
              location: (action['location'] as String?)?.trim(),
            ),
          );
        }
      }

      if (actions.isEmpty) {
        final actionItems = (parsed['action_items'] as List<dynamic>?)
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

      final resolvedSummary =
          (summary != null && summary.isNotEmpty) ? summary : (title ?? '').trim();

      return TranscriptResult(
        summary: resolvedSummary.isEmpty ? raw.trim() : resolvedSummary,
        category: category,
        actions: actions,
      );
    } catch (e) {
      debugPrint('[LlmService] Failed to parse AI response: $e');
      return TranscriptResult(
        summary: jsonStr,
        category: 'note',
      );
    }
  }
}
