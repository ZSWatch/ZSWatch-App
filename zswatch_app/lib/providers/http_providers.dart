import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/http_request.dart';
import '../services/http/http_relay_service.dart';
import '../services/watch_service.dart';
import 'watch_service_provider.dart';

/// HTTP relay service provider
final httpRelayServiceProvider = Provider<HttpRelayService>((ref) {
  final service = HttpRelayService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// State for HTTP relay tracking
class HttpRelayState {
  /// Currently pending requests (keyed by request ID)
  final Map<String, HttpRequest> pendingRequests;

  /// Recently completed requests (for debugging/logging)
  final List<HttpRequest> recentRequests;

  /// Whether HTTP relay is enabled
  final bool isEnabled;

  const HttpRelayState({
    this.pendingRequests = const {},
    this.recentRequests = const [],
    this.isEnabled = true,
  });

  /// Number of pending requests
  int get pendingCount => pendingRequests.length;

  /// Whether any requests are pending
  bool get hasPending => pendingRequests.isNotEmpty;

  HttpRelayState copyWith({
    Map<String, HttpRequest>? pendingRequests,
    List<HttpRequest>? recentRequests,
    bool? isEnabled,
  }) {
    return HttpRelayState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      recentRequests: recentRequests ?? this.recentRequests,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

/// HTTP relay notifier that handles HTTP requests from the watch.
///
/// Listens to incoming watch messages for `t:"http"` requests,
/// performs the HTTP requests, and sends responses back to the watch.
///
/// Features:
/// - Concurrent request support (FR-122)
/// - XPath evaluation for XML responses (FR-119)
/// - Per-request insecure TLS override (FR-118)
/// - Request ID echoing for matching (FR-120, FR-121)
class HttpRelayNotifier extends StateNotifier<HttpRelayState> {
  final HttpRelayService _httpService;
  final WatchService _watchService;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  /// Maximum number of recent requests to keep in history
  static const _maxRecentRequests = 50;

  HttpRelayNotifier(this._httpService, this._watchService)
      : super(const HttpRelayState()) {
    _init();
  }

  void _init() {
    debugPrint('[HttpRelayNotifier] Initializing - listening to watch messages');
    _messageSubscription =
        _watchService.incomingMessages.listen(_handleWatchMessage);
  }

  void _handleWatchMessage(Map<String, dynamic> message) {
    final type = message['t'] as String?;
    if (type != 'http') return;

    // Check if this is a request (has url) or a response (has resp/err)
    // We only handle requests from the watch
    if (!message.containsKey('url')) return;

    debugPrint('[HttpRelayNotifier] Received HTTP request: $message');
    _handleHttpRequest(message);
  }

  /// Handle an incoming HTTP request from the watch
  Future<void> _handleHttpRequest(Map<String, dynamic> message) async {
    if (!state.isEnabled) {
      debugPrint('[HttpRelayNotifier] HTTP relay disabled, ignoring request');
      return;
    }

    // Create request model
    final request = HttpRequest.fromWatchMessage(message);

    // Validate URL
    if (request.url.isEmpty) {
      await _watchService.sendHttpError(request.id ?? '', 'Empty URL');
      return;
    }

    // Track pending request
    final requestId = request.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    state = state.copyWith(
      pendingRequests: {...state.pendingRequests, requestId: request},
    );

    try {
      // Perform the HTTP request
      final result = await _httpService.performRequest(request);

      // Complete the request
      final completedRequest = request.copyWith(
        response: result.response,
        error: result.error,
        completedAt: DateTime.now(),
      );

      // Send response or error to watch
      if (result.isSuccess) {
        await _watchService.sendHttpResponse(request.id ?? '', result.response!);
      } else {
        await _watchService.sendHttpError(request.id ?? '', result.error!);
      }

      // Update state
      _completeRequest(requestId, completedRequest);
    } catch (e) {
      debugPrint('[HttpRelayNotifier] Exception handling HTTP request: $e');

      // Send error to watch
      await _watchService.sendHttpError(request.id ?? '', 'Internal error: $e');

      // Complete with error
      final failedRequest = request.copyWith(
        error: e.toString(),
        completedAt: DateTime.now(),
      );
      _completeRequest(requestId, failedRequest);
    }
  }

  /// Complete a request and move it to recent history
  void _completeRequest(String requestId, HttpRequest completedRequest) {
    final pending = Map<String, HttpRequest>.from(state.pendingRequests);
    pending.remove(requestId);

    // Add to recent requests (limit size)
    final recent = [completedRequest, ...state.recentRequests];
    if (recent.length > _maxRecentRequests) {
      recent.removeLast();
    }

    state = state.copyWith(
      pendingRequests: pending,
      recentRequests: recent,
    );
  }

  /// Enable or disable HTTP relay
  void setEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
  }

  /// Clear recent request history
  void clearHistory() {
    state = state.copyWith(recentRequests: []);
  }

  @override
  void dispose() {
    debugPrint('[HttpRelayNotifier] Disposing');
    _messageSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for HTTP relay state and control
final httpRelayNotifierProvider =
    StateNotifierProvider<HttpRelayNotifier, HttpRelayState>((ref) {
  final httpService = ref.watch(httpRelayServiceProvider);
  final watchService = ref.watch(watchServiceProvider);
  return HttpRelayNotifier(httpService, watchService);
});

/// Whether HTTP relay is enabled
final httpRelayEnabledProvider = Provider<bool>((ref) {
  return ref.watch(httpRelayNotifierProvider).isEnabled;
});

/// Number of pending HTTP requests
final httpRelayPendingCountProvider = Provider<int>((ref) {
  return ref.watch(httpRelayNotifierProvider).pendingCount;
});

/// Recent HTTP requests (for debugging/logging)
final httpRelayRecentRequestsProvider = Provider<List<HttpRequest>>((ref) {
  return ref.watch(httpRelayNotifierProvider).recentRequests;
});
