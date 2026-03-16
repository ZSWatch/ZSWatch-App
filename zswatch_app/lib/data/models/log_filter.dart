import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_filter.freezed.dart';

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
@freezed
abstract class LogStreamingState with _$LogStreamingState {
  const LogStreamingState._();

  const factory LogStreamingState({
    /// Whether app has requested log streaming from watch
    @Default(false) bool requestedByApp,

    /// Whether log streaming is currently enabled on watch
    /// Note: May be true even if not requested by app (watch setting)
    @Default(false) bool enabledOnWatch,

    /// Whether we're waiting for confirmation from watch
    @Default(false) bool pending,

    /// Error message if log enable/disable failed
    String? error,
  }) = _LogStreamingState;

  /// Initial state
  factory LogStreamingState.initial() => const LogStreamingState();
}
