import 'package:flutter/foundation.dart';

/// Filter types for log viewer
enum LogFilter {
  /// Show all incoming BLE NUS data
  all('All', null),

  /// Show only raw log messages from watch
  logsOnly('Logs Only', 'log'),

  /// Show only notification-related messages
  notifications('Notifications', 'notification'),

  /// Show only music-related messages
  music('Music', 'music'),

  /// Show only activity/health messages
  activity('Activity', 'activity'),

  /// Show only status/device info messages
  status('Status', 'status'),

  /// Show only GPS-related messages
  gps('GPS', 'gps'),

  /// Show only alert/info/warn/error messages
  alerts('Alerts', 'alert');

  /// Display name for the filter
  final String displayName;

  /// Internal filter key (maps to LogEntryType name, or null for all)
  final String? filterKey;

  const LogFilter(this.displayName, this.filterKey);

  /// Get the icon for this filter
  @override
  String toString() => displayName;
}

/// Current state of log streaming from watch
@immutable
class LogStreamingState {
  /// Whether app has requested log streaming from watch
  final bool requestedByApp;

  /// Whether log streaming is currently enabled on watch
  /// Note: May be true even if not requested by app (watch setting)
  final bool enabledOnWatch;

  /// Whether we're waiting for confirmation from watch
  final bool pending;

  /// Error message if log enable/disable failed
  final String? error;

  const LogStreamingState({
    this.requestedByApp = false,
    this.enabledOnWatch = false,
    this.pending = false,
    this.error,
  });

  const LogStreamingState.initial()
      : requestedByApp = false,
        enabledOnWatch = false,
        pending = false,
        error = null;

  LogStreamingState copyWith({
    bool? requestedByApp,
    bool? enabledOnWatch,
    bool? pending,
    String? error,
  }) {
    return LogStreamingState(
      requestedByApp: requestedByApp ?? this.requestedByApp,
      enabledOnWatch: enabledOnWatch ?? this.enabledOnWatch,
      pending: pending ?? this.pending,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogStreamingState &&
          runtimeType == other.runtimeType &&
          requestedByApp == other.requestedByApp &&
          enabledOnWatch == other.enabledOnWatch &&
          pending == other.pending &&
          error == other.error;

  @override
  int get hashCode =>
      Object.hash(requestedByApp, enabledOnWatch, pending, error);

  @override
  String toString() =>
      'LogStreamingState(requestedByApp: $requestedByApp, enabledOnWatch: $enabledOnWatch, pending: $pending)';
}
