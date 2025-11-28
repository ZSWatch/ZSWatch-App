import 'package:flutter/foundation.dart';

/// Direction of BLE communication
enum CommDirection {
  /// Data sent from phone to watch
  tx,

  /// Data received from watch
  rx,
}

/// A single communication log entry for debugging BLE traffic
@immutable
class CommLogEntry {
  /// Unique identifier for this entry
  final int id;

  /// Timestamp when the entry was recorded
  final DateTime timestamp;

  /// The raw data content
  final String data;

  /// Direction of communication
  final CommDirection direction;

  /// Size in bytes
  final int sizeBytes;

  /// Optional parsed message type (from 't' field in JSON)
  final String? messageType;

  /// Whether the data was chunked across multiple BLE packets
  final bool wasChunked;

  /// Number of chunks if chunked
  final int? chunkCount;

  const CommLogEntry({
    required this.id,
    required this.timestamp,
    required this.data,
    required this.direction,
    required this.sizeBytes,
    this.messageType,
    this.wasChunked = false,
    this.chunkCount,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommLogEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(id, timestamp);

  @override
  String toString() =>
      'CommLogEntry(id: $id, direction: $direction, size: $sizeBytes, type: $messageType)';
}

/// Statistics for communication log
@immutable
class CommLogStats {
  /// Total entries in the log
  final int totalEntries;

  /// Total TX entries
  final int txCount;

  /// Total RX entries
  final int rxCount;

  /// Total bytes sent
  final int totalTxBytes;

  /// Total bytes received
  final int totalRxBytes;

  /// Oldest entry timestamp
  final DateTime? oldestEntry;

  /// Newest entry timestamp
  final DateTime? newestEntry;

  const CommLogStats({
    this.totalEntries = 0,
    this.txCount = 0,
    this.rxCount = 0,
    this.totalTxBytes = 0,
    this.totalRxBytes = 0,
    this.oldestEntry,
    this.newestEntry,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommLogStats &&
          runtimeType == other.runtimeType &&
          totalEntries == other.totalEntries &&
          totalTxBytes == other.totalTxBytes &&
          totalRxBytes == other.totalRxBytes;

  @override
  int get hashCode => Object.hash(totalEntries, totalTxBytes, totalRxBytes);
}
