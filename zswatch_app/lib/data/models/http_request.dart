import 'package:equatable/equatable.dart';

/// HTTP relay request from watch.
///
/// Represents a request from the watch for the app to fetch a URL
/// and return the response (or XPath-evaluated result).
class HttpRequest extends Equatable {
  /// The URL to fetch
  final String url;

  /// Optional XPath expression to evaluate against XML response
  final String? xpath;

  /// Whether to disable TLS certificate validation (default: false)
  final bool insecure;

  /// Request ID from watch (echoed back in response for concurrent request handling)
  final String? id;

  /// Response body or XPath result (populated after successful fetch)
  final String? response;

  /// Error message (populated on failure)
  final String? error;

  /// When the request was received from the watch
  final DateTime? startedAt;

  /// When the request completed (success or failure)
  final DateTime? completedAt;

  const HttpRequest({
    required this.url,
    this.xpath,
    this.insecure = false,
    this.id,
    this.response,
    this.error,
    this.startedAt,
    this.completedAt,
  });

  /// Create from incoming watch message
  factory HttpRequest.fromWatchMessage(Map<String, dynamic> json) {
    return HttpRequest(
      url: json['url'] as String? ?? '',
      xpath: json['xpath'] as String?,
      insecure: json['insecure'] == true,
      id: json['id']?.toString(),
      startedAt: DateTime.now(),
    );
  }

  /// Whether the request is currently pending
  bool get isPending => completedAt == null && error == null && response == null;

  /// Whether the request completed successfully
  bool get isSuccess => response != null && error == null;

  /// Whether the request failed
  bool get isError => error != null;

  /// Duration of the request (if completed)
  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }

  HttpRequest copyWith({
    String? url,
    String? xpath,
    bool? insecure,
    String? id,
    String? response,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return HttpRequest(
      url: url ?? this.url,
      xpath: xpath ?? this.xpath,
      insecure: insecure ?? this.insecure,
      id: id ?? this.id,
      response: response ?? this.response,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [url, xpath, insecure, id, response, error, startedAt, completedAt];

  @override
  String toString() {
    return 'HttpRequest(url: $url, xpath: $xpath, insecure: $insecure, id: $id, '
        'response: ${response?.substring(0, response!.length.clamp(0, 50)) ?? 'null'}..., '
        'error: $error)';
  }
}
