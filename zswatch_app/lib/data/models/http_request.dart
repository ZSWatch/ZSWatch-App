import 'package:freezed_annotation/freezed_annotation.dart';

part 'http_request.freezed.dart';

/// HTTP relay request from watch.
///
/// Represents a request from the watch for the app to fetch a URL
/// and return the response (or XPath-evaluated result).
@freezed
abstract class HttpRequest with _$HttpRequest {
  const HttpRequest._();

  const factory HttpRequest({
    /// The URL to fetch
    required String url,

    /// Optional XPath expression to evaluate against XML response
    String? xpath,

    /// Whether to disable TLS certificate validation (default: false)
    @Default(false) bool insecure,

    /// Request ID from watch (echoed back in response for concurrent request handling)
    String? id,

    /// Response body or XPath result (populated after successful fetch)
    String? response,

    /// Error message (populated on failure)
    String? error,

    /// When the request was received from the watch
    DateTime? startedAt,

    /// When the request completed (success or failure)
    DateTime? completedAt,
  }) = _HttpRequest;

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
}
