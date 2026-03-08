import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fllama/fllama.dart';
import 'package:flutter/foundation.dart';
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

  const LlmModelInfo({
    required this.id,
    required this.displayName,
    required this.family,
    required this.filename,
    this.downloadUrl,
    this.expectedSizeBytes,
    this.userProvided = false,
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

  const LlmInferenceMetrics({
    required this.modelName,
    required this.rawPrompt,
    required this.rawResponse,
    this.parsedJson,
    required this.wallTime,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.tokensPerSecond = 0.0,
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
      );
}

/// Result of processTranscript().
class TranscriptResult {
  final String summary;
  final String category;
  final List<ExtractedActionResult> actions;
  final String? originalTranscription;
  final String? correctedTranscription;
  final LlmInferenceMetrics? correctionMetrics;
  final LlmInferenceMetrics? classifyMetrics;

  const TranscriptResult({
    required this.summary,
    required this.category,
    this.actions = const [],
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
  int numGpuLayers = 99;

  // ---- Internal state ----
  String? _modelPath;
  int _runningRequestId = -1;

  final _stateSubject = BehaviorSubject<LlmServiceState>.seeded(
    const LlmServiceState(),
  );

  /// Observable service state (for UI bindings).
  Stream<LlmServiceState> get stateStream => _stateSubject.stream;
  LlmServiceState get currentState => _stateSubject.value;

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

    final request = OpenAiRequest(
      messages: [Message(Role.user, prompt)],
      modelPath: _modelPath!,
      maxTokens: overrideMaxTokens ?? maxTokens,
      numGpuLayers: numGpuLayers,
      temperature: temperature,
      topP: topP,
      frequencyPenalty: 0.0,
      presencePenalty: presencePenalty,
      contextSize: nCtx,
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
        final correctionResult = await _generate(
          correctionPrompt,
          overrideMaxTokens: 1024,
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
      final prompt = _buildClassifyPrompt(effectiveTranscript);
      final genResult = await _generate(
        prompt,
        onPartialResponse: onProgress == null
            ? null
            : (partial, tokens) => onProgress('classifying', partial, tokens),
      );
      final raw = genResult.text;
      final classifyMetrics = genResult.metrics.copyWithParsedJson(null);

      debugPrint('[LlmService] Raw AI response: $raw');

      // --- Parse JSON from output ---
      final result = _parseTranscriptResult(raw);

      _stateSubject.add(
        _stateSubject.value.copyWith(status: LlmServiceStatus.ready),
      );

      // Attach the parsed JSON to classify metrics
      final jsonStr = _extractFirstJsonObject(raw);
      final finalClassifyMetrics = classifyMetrics.copyWithParsedJson(jsonStr);

      return TranscriptResult(
        summary: result.summary,
        category: result.category,
        actions: result.actions,
        originalTranscription: transcript,
        correctedTranscription: correctedTranscription,
        correctionMetrics: correctionMetrics,
        classifyMetrics: finalClassifyMetrics,
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
    return '''
You are a precise transcription correction assistant.

The following text was produced by an automatic speech-to-text system and may contain errors such as:
- Wrong words that sound similar (homophones)
- Missing or extra words
- Spelling mistakes in proper nouns
- Grammar errors introduced by the speech recognizer

Your job: output ONLY the corrected text, preserving the original language.
Do not add explanations, markdown, or any text that was not in the original.
If the transcription is already correct, output it unchanged.

Original transcription:
"$transcript"

Corrected transcription:''';
  }

  String _buildClassifyPrompt(String transcript) {
    return '''
You are a precise voice-note extraction assistant.

Return EXACTLY ONE valid JSON object.
Do not include markdown fences.
Do not include explanations.
Do not include any text before or after the JSON.
Do not return multiple JSON objects.

Analyze the transcript and produce:
1. a short summary
2. a category
3. structured actions if the transcript contains actionable items

Preserve the transcript language in summary, title, notes, and location.
Do not invent dates, times, or locations. Use null when unknown.

Use this exact schema:
{
  "summary": "short summary in the original language",
  "category": "idea" | "task" | "reminder" | "meeting" | "note",
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
- Use "meeting" for calendar-like content.
- Use "task" or "reminder" for actionable personal follow-ups.
- Use "note" or "idea" when there is no clear action.
- If no actions exist, return an empty array.
- Keep the summary short and useful for a timeline card.

Transcript: "$transcript"
JSON: ''';
  }

  // ---- Output parsing ----

  String? _extractFirstJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start == -1) {
      return null;
    }

    var depth = 0;
    var inString = false;
    var escaping = false;

    for (var i = start; i < raw.length; i++) {
      final char = raw[i];

      if (escaping) {
        escaping = false;
        continue;
      }

      if (char == '\\' && inString) {
        escaping = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        continue;
      }

      if (inString) {
        continue;
      }

      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return raw.substring(start, i + 1);
        }
      }
    }

    return null;
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

  TranscriptResult _parseTranscriptResult(String raw) {
    final jsonStr = _extractFirstJsonObject(raw);

    if (jsonStr == null) {
      debugPrint('[LlmService] Failed to parse AI response: '
          'FormatException: No JSON object found');
      return TranscriptResult(
        summary: raw.trim(),
        category: 'note',
      );
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
