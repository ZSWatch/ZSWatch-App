import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xpath.dart' as xpath;

import '../../data/models/http_request.dart';

/// Result of an HTTP relay operation
class HttpRelayResult {
  /// The response body or XPath-evaluated result
  final String? response;

  /// Error message if the request failed
  final String? error;

  /// Whether the operation was successful
  bool get isSuccess => error == null && response != null;

  const HttpRelayResult({this.response, this.error});

  factory HttpRelayResult.success(String response) =>
      HttpRelayResult(response: response);

  factory HttpRelayResult.failure(String error) =>
      HttpRelayResult(error: error);
}

/// Service for performing HTTP relay requests on behalf of the watch.
///
/// Handles:
/// - HTTP/HTTPS GET requests
/// - Optional XPath evaluation for XML responses
/// - Per-request TLS certificate validation bypass (insecure mode)
/// - Concurrent request support
class HttpRelayService {
  /// Default timeout for HTTP requests
  static const _defaultTimeout = Duration(seconds: 30);

  /// Standard HTTP client for secure requests
  late final http.Client _secureClient;

  /// HTTP client that bypasses TLS certificate validation
  http.Client? _insecureClient;

  HttpRelayService() {
    _secureClient = http.Client();
  }

  /// Get or create an insecure HTTP client (bypasses TLS validation)
  http.Client _getInsecureClient() {
    if (_insecureClient != null) return _insecureClient!;

    // Create an HttpClient that accepts all certificates
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    _insecureClient = IOClient(httpClient);
    return _insecureClient!;
  }

  /// Perform an HTTP relay request.
  ///
  /// [request] contains the URL, optional XPath, and insecure flag.
  /// Returns [HttpRelayResult] with either response or error.
  Future<HttpRelayResult> performRequest(HttpRequest request) async {
    debugPrint(
      '[HttpRelayService] Performing request: ${request.url}, '
      'xpath: ${request.xpath}, insecure: ${request.insecure}',
    );

    // Validate URL
    final uri = Uri.tryParse(request.url);
    if (uri == null || !uri.hasScheme) {
      return HttpRelayResult.failure('Invalid URL: ${request.url}');
    }

    // Only allow HTTP and HTTPS
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return HttpRelayResult.failure('Unsupported scheme: ${uri.scheme}');
    }

    try {
      // Select client based on insecure flag
      final client = request.insecure ? _getInsecureClient() : _secureClient;

      // Perform GET request
      final response = await client
          .get(
            uri,
            headers: {'User-Agent': 'ZSWatch-Companion/1.0', 'Accept': '*/*'},
          )
          .timeout(_defaultTimeout);

      debugPrint('[HttpRelayService] Response status: ${response.statusCode}');

      // Check for HTTP errors
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return HttpRelayResult.failure(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      String body = response.body;

      // If XPath is provided, parse as XML and evaluate
      if (request.xpath != null && request.xpath!.isNotEmpty) {
        try {
          body = _evaluateXPath(body, request.xpath!);
        } catch (e) {
          return HttpRelayResult.failure('XPath error: $e');
        }
      }

      debugPrint('[HttpRelayService] Success, response length: ${body.length}');
      return HttpRelayResult.success(body);
    } on TimeoutException {
      return HttpRelayResult.failure('Request timed out');
    } on SocketException catch (e) {
      return HttpRelayResult.failure('Network error: ${e.message}');
    } on HandshakeException catch (e) {
      return HttpRelayResult.failure('TLS error: ${e.message}');
    } on FormatException catch (e) {
      return HttpRelayResult.failure('Format error: ${e.message}');
    } catch (e) {
      debugPrint('[HttpRelayService] Error: $e');
      return HttpRelayResult.failure('Request failed: $e');
    }
  }

  /// Evaluate an XPath expression against XML content.
  ///
  /// Returns the string value of the XPath result.
  /// Throws if parsing or evaluation fails.
  String _evaluateXPath(String xmlContent, String xpathExpr) {
    // Parse XML
    final document = xml.XmlDocument.parse(xmlContent);

    // Evaluate XPath
    final result = document.xpath(xpathExpr);

    if (result.isEmpty) {
      throw Exception('XPath returned no results');
    }

    // Convert results to string
    // If multiple nodes, join with newline
    final values = result.map((node) {
      if (node is xml.XmlText) {
        return node.value;
      } else if (node is xml.XmlElement) {
        return node.innerText;
      } else if (node is xml.XmlAttribute) {
        return node.value;
      } else {
        return node.toString();
      }
    }).toList();

    return values.join('\n');
  }

  /// Dispose resources
  void dispose() {
    _secureClient.close();
    _insecureClient?.close();
  }
}
