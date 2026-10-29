import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/comm_log_entry.dart';
import '../data/models/log_entry.dart';
import '../data/models/log_filter.dart';
import '../data/repositories/comm_log_repository.dart';

import 'watch_service_provider.dart';
import 'companion_runtime_providers.dart';

// ============================================================================
// Log Viewer Providers (T105a)
// ============================================================================

/// Provider for the currently selected log filter
final logFilterProvider = StateProvider<LogFilter>((ref) => LogFilter.all);

// Capture outlives the viewer. The native owner also buffers logs while the
// Flutter engine is detached and replays them when this stream attaches.
final companionLiveLogEventsProvider = StreamProvider<Map<String, Object?>>((
  ref,
) {
  return ref.watch(companionClientProvider).liveLogs();
});

/// Provider for log streaming state (with pending/error tracking)
final logStreamingStateProvider =
    StateNotifierProvider<LogStreamingStateNotifier, LogStreamingState>((ref) {
      final notifier = LogStreamingStateNotifier.native(
        ref.watch(companionClientProvider).setLogStreaming,
      );
      ref.listen(companionLiveLogEventsProvider, (previous, next) {
        next.whenData(notifier.receiveNative);
        if (next.hasError) notifier.failNative(next.error!);
      });
      return notifier;
    });

class LogStreamingStateNotifier extends StateNotifier<LogStreamingState> {
  final Future<void> Function(bool) _nativeCommand;

  LogStreamingStateNotifier.native(this._nativeCommand)
    : super(const LogStreamingState());

  void receiveNative(Map<String, Object?> event) {
    if (event['kind'] != 'state') return;
    state = state.copyWith(
      requestedByApp: event['requested'] == true,
      enabledOnWatch: event['written'] == true,
      pending: event['pending'] == true,
      error: null,
    );
  }

  void failNative(Object error) {
    state = state.copyWith(pending: false, error: error.toString());
  }

  Future<void> _setNative(bool enabled) async {
    state = state.copyWith(pending: true, error: null);
    try {
      await _nativeCommand(enabled);
    } catch (error) {
      if (mounted) failNative(error);
    }
  }

  Future<void> enable() async {
    return _setNative(true);
  }

  Future<void> disable() async {
    return _setNative(false);
  }

  void toggle() {
    if (state.requestedByApp) {
      disable();
    } else {
      enable();
    }
  }
}

/// Provider for all log entries (maintains a buffer)
final logEntriesProvider =
    StateNotifierProvider<LogEntriesNotifier, List<LogEntry>>((ref) {
      final notifier = LogEntriesNotifier.native();
      ref.listen(companionLiveLogEventsProvider, (previous, next) {
        next.whenData((event) {
          if (event['kind'] == 'log' && event['message'] is String) {
            notifier._emitLogEntry(
              event['message']! as String,
              timestamp: event['utc_ms'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(event['utc_ms']! as int)
                  : null,
            );
          }
        });
      });
      return notifier;
    });

class LogEntriesNotifier extends StateNotifier<List<LogEntry>> {
  static const int maxEntries = 1000;

  int _nextId = 1;

  LogEntriesNotifier.native() : super([]);

  /// Emit a log entry (from BLELOG wrapper)
  void _emitLogEntry(String logContent, {DateTime? timestamp}) {
    if (logContent.isEmpty) return;

    final entry = LogEntry.incoming(
      id: _nextId++,
      message: logContent,
      messageType: 'log',
      type: LogEntryType.log,
      isJson: false,
    );
    _addEntry(timestamp == null ? entry : entry.copyWith(timestamp: timestamp));
  }

  void _addEntry(LogEntry entry) {
    final newList = [...state, entry];
    // Trim if over max
    if (newList.length > maxEntries) {
      state = newList.sublist(newList.length - maxEntries);
    } else {
      state = newList;
    }
  }

  void clear() {
    state = [];
  }
}

/// Provider for filtered log entries based on selected filter
final filteredLogEntriesProvider = Provider<List<LogEntry>>((ref) {
  final entries = ref.watch(logEntriesProvider);
  final filter = ref.watch(logFilterProvider);

  if (filter == LogFilter.all) {
    return entries;
  }

  return entries.where((entry) {
    switch (filter) {
      case LogFilter.all:
        return true;
      case LogFilter.logsOnly:
        return entry.type == LogEntryType.log;
      case LogFilter.notifications:
        return entry.type == LogEntryType.notification;
      case LogFilter.music:
        return entry.type == LogEntryType.music;
      case LogFilter.activity:
        return entry.type == LogEntryType.activity;
      case LogFilter.status:
        return entry.type == LogEntryType.status;
      case LogFilter.gps:
        return entry.type == LogEntryType.gps;
      case LogFilter.alerts:
        return entry.type == LogEntryType.alert;
    }
  }).toList();
});

// ============================================================================
// Communication Log Providers (T104)
// ============================================================================

/// Provider for the communication log repository
/// Projects the native companion traffic stream.
final commLogRepositoryProvider =
    StateNotifierProvider.autoDispose<CommLogNotifier, List<CommLogEntry>>((
      ref,
    ) {
      return CommLogNotifier.native(
        ref.watch(companionClientProvider).communicationTraffic(),
      );
    });

/// Maintains the communication log from native events.
class CommLogNotifier extends StateNotifier<List<CommLogEntry>> {
  final CommLogRepository _repo = CommLogRepository();

  StreamSubscription<Map<String, Object?>>? _nativeSubscription;
  int _nativeId = 1;

  CommLogNotifier.native(Stream<Map<String, Object?>> events) : super([]) {
    _nativeSubscription = events.listen((event) {
      final chunks = event['chunk_count']! as int;
      _repo.add(
        CommLogEntry(
          id: _nativeId++,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            event['utc_ms']! as int,
          ),
          data: event['data']! as String,
          direction: event['direction'] == 'tx'
              ? CommDirection.tx
              : CommDirection.rx,
          sizeBytes: event['size_bytes']! as int,
          wasChunked: event['direction'] == 'tx' && chunks > 1,
          chunkCount: event['direction'] == 'tx' ? chunks : null,
        ),
      );
      state = _repo.entries;
    });
  }

  CommLogRepository get repository => _repo;

  void clear() {
    _repo.clear();
    state = [];
  }

  @override
  void dispose() {
    _nativeSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for communication log entries (refreshes on change)
final commLogEntriesProvider = Provider.autoDispose<List<CommLogEntry>>((ref) {
  final entries = ref.watch(commLogRepositoryProvider);
  // Return in chronological order (oldest first, newest last)
  // This matches the auto-scroll to bottom behavior in the UI
  return entries.toList();
});

/// Provider for communication log statistics
final commLogStatsProvider = Provider.autoDispose<CommLogStats>((ref) {
  // Watch the state to trigger rebuild when entries change
  final entries = ref.watch(commLogRepositoryProvider);

  if (entries.isEmpty) {
    return const CommLogStats();
  }

  int txCount = 0;
  int rxCount = 0;
  int totalTxBytes = 0;
  int totalRxBytes = 0;

  for (final entry in entries) {
    if (entry.direction == CommDirection.tx) {
      txCount++;
      totalTxBytes += entry.sizeBytes;
    } else {
      rxCount++;
      totalRxBytes += entry.sizeBytes;
    }
  }

  return CommLogStats(
    totalEntries: entries.length,
    txCount: txCount,
    rxCount: rxCount,
    totalTxBytes: totalTxBytes,
    totalRxBytes: totalRxBytes,
    oldestEntry: entries.first.timestamp,
    newestEntry: entries.last.timestamp,
  );
});

// ============================================================================
// BLE Diagnostics Providers (T107)
// ============================================================================

/// Provider for BLE diagnostics data
final bleDiagnosticsProvider = Provider<BleDiagnostics>((ref) {
  final connection = ref.watch(watchConnectionProvider);

  return BleDiagnostics(
    mtu: connection.mtu,
    rssi: connection.rssi,
    isConnected: connection.isConnected,
    connectedAt: connection.connectedAt,
  );
});

/// BLE diagnostics data model
class BleDiagnostics {
  final int? mtu;
  final int? rssi;
  final bool isConnected;
  final DateTime? connectedAt;

  const BleDiagnostics({
    this.mtu,
    this.rssi,
    this.isConnected = false,
    this.connectedAt,
  });

  String get mtuDisplay => mtu != null ? '$mtu bytes' : 'N/A';
  String get rssiDisplay => rssi != null ? '$rssi dBm' : 'N/A';

  /// Connection duration since connected
  Duration? get connectionDuration {
    if (connectedAt == null || !isConnected) return null;
    return DateTime.now().difference(connectedAt!);
  }

  /// Formatted connection duration string
  String get connectionDurationDisplay {
    final duration = connectionDuration;
    if (duration == null) return 'N/A';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get signalStrength {
    if (rssi == null) return 'Unknown';
    if (rssi! > -50) return 'Excellent';
    if (rssi! > -60) return 'Good';
    if (rssi! > -70) return 'Fair';
    return 'Weak';
  }
}
