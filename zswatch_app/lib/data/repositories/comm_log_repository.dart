import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/comm_log_entry.dart';

/// Repository for storing BLE communication logs with automatic rotation
///
/// Implements FR-066: Communication logs MUST rotate at 5,000 entries or 5MB
/// (whichever first), discarding oldest entries.
class CommLogRepository {
  /// Maximum number of entries to keep
  static const int maxEntries = 5000;

  /// Maximum total size in bytes (5MB)
  static const int maxSizeBytes = 5 * 1024 * 1024;

  /// Internal storage using a queue for efficient rotation
  final Queue<CommLogEntry> _entries = Queue();

  /// Running total of bytes stored
  int _totalBytes = 0;

  /// Entry ID counter
  int _nextId = 1;

  /// Get all entries (oldest first)
  List<CommLogEntry> get entries => _entries.toList();

  /// Get entries in reverse order (newest first)
  List<CommLogEntry> get entriesReversed => _entries.toList().reversed.toList();

  /// Number of entries currently stored
  int get length => _entries.length;

  /// Whether the repository is empty
  bool get isEmpty => _entries.isEmpty;

  /// Whether the repository is at max capacity
  bool get isFull => _entries.length >= maxEntries || _totalBytes >= maxSizeBytes;

  /// Total bytes stored
  int get totalBytes => _totalBytes;

  /// Get statistics about the log
  CommLogStats get stats {
    if (_entries.isEmpty) {
      return const CommLogStats();
    }

    int txCount = 0;
    int rxCount = 0;
    int totalTxBytes = 0;
    int totalRxBytes = 0;

    for (final entry in _entries) {
      if (entry.direction == CommDirection.tx) {
        txCount++;
        totalTxBytes += entry.sizeBytes;
      } else {
        rxCount++;
        totalRxBytes += entry.sizeBytes;
      }
    }

    return CommLogStats(
      totalEntries: _entries.length,
      txCount: txCount,
      rxCount: rxCount,
      totalTxBytes: totalTxBytes,
      totalRxBytes: totalRxBytes,
      oldestEntry: _entries.first.timestamp,
      newestEntry: _entries.last.timestamp,
    );
  }

  /// Add a TX (outgoing) entry
  void addTx(String data, {String? messageType, bool wasChunked = false, int? chunkCount}) {
    _addEntry(CommLogEntry.tx(
      id: _nextId++,
      data: data,
      messageType: messageType,
      wasChunked: wasChunked,
      chunkCount: chunkCount,
    ));
  }

  /// Add an RX (incoming) entry
  void addRx(String data, {String? messageType}) {
    _addEntry(CommLogEntry.rx(
      id: _nextId++,
      data: data,
      messageType: messageType,
    ));
  }

  void _addEntry(CommLogEntry entry) {
    // Rotate out old entries if needed
    while (_shouldRotate(entry.sizeBytes)) {
      _removeOldest();
    }

    _entries.add(entry);
    _totalBytes += entry.sizeBytes;

  }

  bool _shouldRotate(int newEntrySize) {
    if (_entries.isEmpty) return false;

    // Check entry count limit
    if (_entries.length >= maxEntries) return true;

    // Check size limit
    if (_totalBytes + newEntrySize > maxSizeBytes) return true;

    return false;
  }

  void _removeOldest() {
    if (_entries.isEmpty) return;

    final oldest = _entries.removeFirst();
    _totalBytes -= oldest.sizeBytes;
  }

  /// Clear all entries
  void clear() {
    _entries.clear();
    _totalBytes = 0;
    debugPrint('[CommLog] Cleared all entries');
  }

  /// Get entries matching a filter
  List<CommLogEntry> filter({
    CommDirection? direction,
    String? messageType,
    DateTime? after,
    DateTime? before,
    String? containsText,
  }) {
    return _entries.where((entry) {
      if (direction != null && entry.direction != direction) return false;
      if (messageType != null && entry.messageType != messageType) return false;
      if (after != null && entry.timestamp.isBefore(after)) return false;
      if (before != null && entry.timestamp.isAfter(before)) return false;
      if (containsText != null &&
          !entry.data.toLowerCase().contains(containsText.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Get entries within a time window
  List<CommLogEntry> getWindow(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _entries.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  /// Export log as string for sharing
  String export() {
    final buffer = StringBuffer();
    buffer.writeln('ZSWatch Communication Log');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Entries: ${_entries.length}');
    buffer.writeln('Total Size: ${_formatBytes(_totalBytes)}');
    buffer.writeln('---');

    for (final entry in _entries) {
      buffer.writeln('[${entry.formattedTimestamp}] ${entry.directionArrow} ${entry.data}');
    }

    return buffer.toString();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
