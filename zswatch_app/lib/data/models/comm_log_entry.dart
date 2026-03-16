import 'package:freezed_annotation/freezed_annotation.dart';

part 'comm_log_entry.freezed.dart';

/// Direction of BLE communication
enum CommDirection {
  /// Data sent from phone to watch
  tx,

  /// Data received from watch
  rx,
}

/// A single communication log entry for debugging BLE traffic
@freezed
abstract class CommLogEntry with _$CommLogEntry {
  const CommLogEntry._();

  const factory CommLogEntry({
    /// Unique identifier for this entry
    required int id,

    /// Timestamp when the entry was recorded
    required DateTime timestamp,

    /// The raw data content
    required String data,

    /// Direction of communication
    required CommDirection direction,

    /// Size in bytes
    required int sizeBytes,

    /// Optional parsed message type (from 't' field in JSON)
    String? messageType,

    /// Whether the data was chunked across multiple BLE packets
    @Default(false) bool wasChunked,

    /// Number of chunks if chunked
    int? chunkCount,
  }) = _CommLogEntry;

  /// Create a TX (outgoing) entry
  factory CommLogEntry.tx({
    required int id,
    required String data,
    String? messageType,
    bool wasChunked = false,
    int? chunkCount,
  }) {
    return CommLogEntry(
      id: id,
      timestamp: DateTime.now(),
      data: data,
      direction: CommDirection.tx,
      sizeBytes: data.length,
      messageType: messageType,
      wasChunked: wasChunked,
      chunkCount: chunkCount,
    );
  }

  /// Create an RX (incoming) entry
  factory CommLogEntry.rx({
    required int id,
    required String data,
    String? messageType,
  }) {
    return CommLogEntry(
      id: id,
      timestamp: DateTime.now(),
      data: data,
      direction: CommDirection.rx,
      sizeBytes: data.length,
      messageType: messageType,
    );
  }

  /// Format the timestamp for display
  String get formattedTimestamp {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// Get direction display string
  String get directionDisplay => direction == CommDirection.tx ? 'TX' : 'RX';

  /// Get direction arrow for display
  String get directionArrow => direction == CommDirection.tx ? '→' : '←';

  /// Get a truncated preview of the data
  String get dataPreview {
    if (data.length <= 100) return data;
    return '${data.substring(0, 100)}...';
  }

  /// Format size for display
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
}

/// Statistics for communication log
@freezed
abstract class CommLogStats with _$CommLogStats {
  const CommLogStats._();

  const factory CommLogStats({
    /// Total entries in the log
    @Default(0) int totalEntries,

    /// Total TX entries
    @Default(0) int txCount,

    /// Total RX entries
    @Default(0) int rxCount,

    /// Total bytes sent
    @Default(0) int totalTxBytes,

    /// Total bytes received
    @Default(0) int totalRxBytes,

    /// Oldest entry timestamp
    DateTime? oldestEntry,

    /// Newest entry timestamp
    DateTime? newestEntry,
  }) = _CommLogStats;

  /// Total bytes (TX + RX)
  int get totalBytes => totalTxBytes + totalRxBytes;

  /// Format total bytes for display
  String get formattedTotalBytes {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Duration of log window
  Duration? get duration {
    if (oldestEntry == null || newestEntry == null) return null;
    return newestEntry!.difference(oldestEntry!);
  }
}
