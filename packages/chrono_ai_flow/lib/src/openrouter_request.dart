/// OpenRouter request shapes shared by the app and the benchmark, so cloud
/// numbers from the testbench match what the app sends.
abstract final class OpenRouterRequest {
  static const String baseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultTranscriptionModel =
      'google/gemini-3.1-flash-lite';
  static const String defaultAnalysisModel = 'google/gemini-3.1-flash-lite';
  static const String referer = 'https://github.com/ZSWatch/ZSWatch-App';
  static const String title = 'ZSWatch';

  static const String transcriptionPrompt =
      'Transcribe this voice memo verbatim in the language spoken (usually '
      'Swedish or English). Output only the transcript text. If there is no '
      'speech, output nothing.';

  /// Zero data retention, and never a provider that may store or train on it.
  static const Map<String, Object?> privateRouting = {
    'zdr': true,
    'data_collection': 'deny',
  };

  static Map<String, String> headers(String apiKey) => {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
    'HTTP-Referer': referer,
    'X-Title': title,
  };

  /// Text analysis with the app's extraction prompt. [reasoningEffort] is
  /// sent only for models that support it (`none` where allowed).
  static Map<String, Object?> analysis(
    String model,
    String prompt, {
    int maxTokens = 512,
    String? reasoningEffort = 'none',
  }) => {
    'model': model,
    'messages': [
      {'role': 'user', 'content': _stripNoThink(prompt)},
    ],
    'max_tokens': maxTokens,
    'temperature': 0.2,
    'reasoning': ?(reasoningEffort == null
        ? null
        : {'effort': reasoningEffort, 'exclude': true}),
    'provider': privateRouting,
    'usage': {'include': true},
  };

  /// Speech-to-text through an audio-capable chat model. [format] is the
  /// container name OpenRouter expects (`ogg` for the watch's Ogg Opus).
  static Map<String, Object?> transcription(
    String model,
    String base64Audio, {
    String format = 'ogg',
    String? reasoningEffort = 'none',
  }) => {
    'model': model,
    'messages': [
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': transcriptionPrompt},
          {
            'type': 'input_audio',
            'input_audio': {'data': base64Audio, 'format': format},
          },
        ],
      },
    ],
    'max_tokens': 1024,
    'temperature': 0.0,
    'reasoning': ?(reasoningEffort == null
        ? null
        : {'effort': reasoningEffort, 'exclude': true}),
    'provider': privateRouting,
    'usage': {'include': true},
  };

  static String _stripNoThink(String prompt) =>
      prompt.replaceAll(RegExp(r'^/no_think\n?', multiLine: true), '');

  /// The assistant text of a chat completion body, or an [OpenRouterFailure].
  /// OpenRouter reports some failures in a 200 body.
  static String contentOf(int status, Map<String, Object?> body) {
    final error = body['error'];
    if (status != 200 || error != null) {
      throw OpenRouterFailure.fromResponse(status, body);
    }
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const OpenRouterFailure(OpenRouterFailureKind.retry, 'No choices');
    }
    final choice = choices.first as Map;
    final message = choice['message'];
    final content = message is Map ? message['content'] : null;
    if (content is String) return content;
    if (choice['error'] != null) {
      throw OpenRouterFailure.fromResponse(200, {'error': choice['error']});
    }
    return '';
  }
}

enum OpenRouterFailureKind {
  /// Missing, invalid or revoked key: wait for the user to fix it.
  auth,

  /// No credit or key limit reached: wait for a top-up.
  credits,

  /// Network, rate limit, provider down: try again later.
  retry,

  /// The request itself is wrong (bad model id, moderation): do not repeat.
  rejected,
}

class OpenRouterFailure implements Exception {
  const OpenRouterFailure(
    this.kind,
    this.message, {
    this.status,
    this.retryAfter,
  });

  factory OpenRouterFailure.fromResponse(
    int status,
    Map<String, Object?> body, {
    Duration? retryAfter,
  }) {
    final error = body['error'];
    final map = error is Map ? error : const <String, Object?>{};
    final code = map['code'] is int ? map['code']! as int : status;
    final message = map['message']?.toString() ?? 'HTTP $status';
    final effective = status == 200 ? code : status;
    return OpenRouterFailure(
      kindFor(effective, message, retryAfter: retryAfter),
      message,
      status: effective,
      retryAfter: retryAfter,
    );
  }

  static OpenRouterFailureKind kindFor(
    int status,
    String message, {
    Duration? retryAfter,
  }) {
    if (status == 401) return OpenRouterFailureKind.auth;
    if (status == 402) {
      return retryAfter != null
          ? OpenRouterFailureKind.retry
          : OpenRouterFailureKind.credits;
    }
    // 403 is a disabled key unless it is a moderation flag.
    if (status == 403) {
      return message.toLowerCase().contains('moderat')
          ? OpenRouterFailureKind.rejected
          : OpenRouterFailureKind.auth;
    }
    if (status == 408 || status == 429 || status >= 500) {
      return OpenRouterFailureKind.retry;
    }
    if (status >= 400) return OpenRouterFailureKind.rejected;
    return OpenRouterFailureKind.retry;
  }

  final OpenRouterFailureKind kind;
  final String message;
  final int? status;
  final Duration? retryAfter;

  @override
  String toString() => 'OpenRouterFailure($kind, $status, $message)';
}
