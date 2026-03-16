/// App-wide named constants replacing magic numbers.
abstract final class AppConstants {
  /// Notification deduplication window in milliseconds.
  /// Prevents duplicate notifications from appearing within this window.
  static const int notificationDeduplicationWindowMs = 2000;

  /// Maximum quick reconnect attempts before switching to slower backoff.
  static const int maxQuickReconnectAttempts = 3;

  /// Maximum number of comm log entries kept in the in-memory buffer.
  static const int commLogMaxEntries = 5000;

  /// Maximum number of log entries kept in the log viewer in-memory buffer.
  static const int logViewerMaxEntries = 1000;

  /// Minimum acceptable MTU negotiated with a BLE device.
  /// iOS typically negotiates 185–512 bytes; values below this indicate a
  /// degraded connection that may cause packet fragmentation.
  static const int minimumAcceptableMtu = 185;

  /// Number of days of health / analytics data to retain before pruning.
  static const int analyticsRetentionDays = 60;
}
