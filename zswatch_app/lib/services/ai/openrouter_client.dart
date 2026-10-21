import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chrono_ai_flow/chrono_ai_flow.dart';
import 'package:http/http.dart' as http;

/// Models stored in a voice config carry this prefix; anything else is local.
const openRouterModelPrefix = 'openrouter:';

bool isOpenRouterModel(String id) => id.startsWith(openRouterModelPrefix);

String openRouterModelId(String id) =>
    id.substring(openRouterModelPrefix.length);

/// Usage and limit of the user's key, from `GET /api/v1/key`.
class OpenRouterKeyInfo {
  const OpenRouterKeyInfo({
    required this.label,
    required this.usage,
    required this.usageMonthly,
    this.limit,
    this.limitRemaining,
    this.isFreeTier = false,
  });

  factory OpenRouterKeyInfo.fromJson(Map<String, Object?> json) {
    double? number(Object? v) => v is num ? v.toDouble() : null;
    return OpenRouterKeyInfo(
      label: json['label']?.toString() ?? '',
      usage: number(json['usage']) ?? 0,
      usageMonthly: number(json['usage_monthly']) ?? number(json['usage']) ?? 0,
      limit: number(json['limit']),
      limitRemaining: number(json['limit_remaining']),
      isFreeTier: json['is_free_tier'] == true,
    );
  }

  final String label;
  final double usage;
  final double usageMonthly;
  final double? limit;
  final double? limitRemaining;
  final bool isFreeTier;
}

/// One entry of `GET /api/v1/models`, reduced to what the pickers need.
class OpenRouterModel {
  const OpenRouterModel({
    required this.id,
    required this.name,
    required this.promptPrice,
    required this.completionPrice,
    required this.audioPrice,
    required this.inputModalities,
    required this.supportedParameters,
    this.zdr = false,
  });

  factory OpenRouterModel.fromJson(Map<String, Object?> json) {
    double price(Object? v) => double.tryParse(v?.toString() ?? '') ?? 0;
    final pricing = (json['pricing'] as Map?) ?? const {};
    final architecture = (json['architecture'] as Map?) ?? const {};
    return OpenRouterModel(
      id: json['id']! as String,
      name: json['name']?.toString() ?? json['id']! as String,
      promptPrice: price(pricing['prompt']),
      completionPrice: price(pricing['completion']),
      audioPrice: price(pricing['audio']),
      inputModalities: [
        for (final m in (architecture['input_modalities'] as List?) ?? const [])
          m.toString(),
      ],
      supportedParameters: [
        for (final p in (json['supported_parameters'] as List?) ?? const [])
          p.toString(),
      ],
      zdr: json['zdr'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'pricing': {
      'prompt': '$promptPrice',
      'completion': '$completionPrice',
      'audio': '$audioPrice',
    },
    'architecture': {'input_modalities': inputModalities},
    'supported_parameters': supportedParameters,
    'zdr': zdr,
  };

  OpenRouterModel withZdr(bool value) => OpenRouterModel(
    id: id,
    name: name,
    promptPrice: promptPrice,
    completionPrice: completionPrice,
    audioPrice: audioPrice,
    inputModalities: inputModalities,
    supportedParameters: supportedParameters,
    zdr: value,
  );

  final String id;
  final String name;

  /// USD per token.
  final double promptPrice;
  final double completionPrice;
  final double audioPrice;
  final List<String> inputModalities;
  final List<String> supportedParameters;

  /// Has at least one zero-data-retention endpoint.
  final bool zdr;

  bool get acceptsAudio => inputModalities.contains('audio');
  bool get acceptsText => inputModalities.contains('text');
  bool get supportsReasoning => supportedParameters.contains('reasoning');
  bool get isFree => id.endsWith(':free');

  /// Rough cost of one memo: ~1500 prompt + 150 output tokens for analysis,
  /// ~15 s of audio (~32 tokens/s) + 60 output tokens for transcription.
  double get analysisCostPerMemo => 1500 * promptPrice + 150 * completionPrice;
  double get transcriptionCostPerMemo =>
      480 * (audioPrice > 0 ? audioPrice : promptPrice) +
      60 * completionPrice +
      40 * promptPrice;
}

/// Thin HTTP client for the user's OpenRouter key. Never logs the key,
/// prompts or transcripts.
class OpenRouterClient {
  OpenRouterClient(this._apiKey, {http.Client? client})
    : _http = client ?? http.Client();

  static const requestTimeout = Duration(seconds: 45);

  final String _apiKey;
  final http.Client _http;
  bool _closed = false;

  /// Cost of the calls made by this client, from OpenRouter's usage report.
  double totalCost = 0;

  Future<String> transcribe(String model, Uint8List oggOpus) async {
    final text = await _chat(
      OpenRouterRequest.transcription(model, base64Encode(oggOpus)),
    );
    return text.trim();
  }

  Future<String> analyze(
    String model,
    String prompt, {
    int maxTokens = 512,
    bool reasoning = true,
  }) => _chat(
    OpenRouterRequest.analysis(
      model,
      prompt,
      maxTokens: maxTokens,
      reasoningEffort: reasoning ? 'none' : null,
    ),
  );

  Future<OpenRouterKeyInfo> keyInfo() async {
    final response = await _send(
      () => _http.get(
        Uri.parse('${OpenRouterRequest.baseUrl}/key'),
        headers: OpenRouterRequest.headers(_apiKey),
      ),
    );
    final body = _decode(response);
    if (response.statusCode != 200 || body['data'] is! Map) {
      throw OpenRouterFailure.fromResponse(response.statusCode, body);
    }
    return OpenRouterKeyInfo.fromJson(
      Map<String, Object?>.from(body['data']! as Map),
    );
  }

  /// Public model list joined with zero-data-retention availability.
  static Future<List<OpenRouterModel>> fetchModels({
    http.Client? client,
  }) async {
    final http.Client c = client ?? http.Client();
    try {
      final responses = await Future.wait([
        c
            .get(Uri.parse('${OpenRouterRequest.baseUrl}/models'))
            .timeout(requestTimeout),
        c
            .get(Uri.parse('${OpenRouterRequest.baseUrl}/endpoints/zdr'))
            .timeout(requestTimeout),
      ]);
      for (final r in responses) {
        if (r.statusCode != 200) {
          throw OpenRouterFailure.fromResponse(r.statusCode, _decode(r));
        }
      }
      final zdr = <String>{
        for (final e in (_decode(responses[1])['data'] as List?) ?? const [])
          if (e is Map && e['model_id'] is String) e['model_id']! as String,
      };
      return [
        for (final m in (_decode(responses[0])['data'] as List?) ?? const [])
          if (m is Map)
            OpenRouterModel.fromJson(
              Map<String, Object?>.from(m),
            ).withZdr(zdr.contains(m['id'])),
      ];
    } finally {
      if (client == null) c.close();
    }
  }

  Future<String> _chat(Map<String, Object?> request) async {
    final response = await _send(
      () => _http.post(
        Uri.parse('${OpenRouterRequest.baseUrl}/chat/completions'),
        headers: OpenRouterRequest.headers(_apiKey),
        body: jsonEncode(request),
      ),
    );
    final body = _decode(response);
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    if (response.statusCode != 200 || body['error'] != null) {
      throw OpenRouterFailure.fromResponse(
        response.statusCode,
        body,
        retryAfter: retryAfter == null ? null : Duration(seconds: retryAfter),
      );
    }
    final usage = body['usage'];
    if (usage is Map && usage['cost'] is num) {
      totalCost += (usage['cost']! as num).toDouble();
    }
    return OpenRouterRequest.contentOf(response.statusCode, body);
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    if (_closed) {
      throw const OpenRouterFailure(OpenRouterFailureKind.retry, 'Cancelled');
    }
    try {
      return await call().timeout(requestTimeout);
    } on TimeoutException {
      throw const OpenRouterFailure(OpenRouterFailureKind.retry, 'Timeout');
    } on SocketException {
      throw const OpenRouterFailure(OpenRouterFailureKind.retry, 'Offline');
    } on http.ClientException {
      throw OpenRouterFailure(
        OpenRouterFailureKind.retry,
        _closed ? 'Cancelled' : 'Connection failed',
      );
    }
  }

  static Map<String, Object?> _decode(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      return value is Map ? Map<String, Object?>.from(value) : const {};
    } on FormatException {
      return {
        'error': {'code': response.statusCode, 'message': 'Invalid response'},
      };
    }
  }

  void close() {
    _closed = true;
    _http.close();
  }
}
