import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/comm_log_entry.dart';
import '../data/models/log_entry.dart';
import '../data/models/log_filter.dart';
import '../data/models/sensor_reading.dart';
import '../data/repositories/comm_log_repository.dart';
import '../services/ble/sensor_gatt_service.dart';
import '../services/watch_service.dart';
import 'watch_service_provider.dart';

// ============================================================================
// Log Viewer Providers (T105a)
// ============================================================================

/// Provider for the currently selected log filter
final logFilterProvider = StateProvider<LogFilter>((ref) => LogFilter.all);

/// Provider for whether log streaming is enabled on watch
final logStreamingEnabledProvider = StateProvider<bool>((ref) => false);

/// Provider for log streaming state (with pending/error tracking)
final logStreamingStateProvider = StateNotifierProvider<LogStreamingStateNotifier, LogStreamingState>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  return LogStreamingStateNotifier(watchService);
});

class LogStreamingStateNotifier extends StateNotifier<LogStreamingState> {
  final WatchService _watchService;

  LogStreamingStateNotifier(this._watchService) : super(const LogStreamingState.initial());

  Future<void> enable() async {
    state = state.copyWith(pending: true, error: null);
    try {
      await _watchService.setLogStreaming(true);
      state = state.copyWith(
        requestedByApp: true,
        enabledOnWatch: true,
        pending: false,
      );
    } catch (e) {
      state = state.copyWith(
        pending: false,
        error: e.toString(),
      );
    }
  }

  Future<void> disable() async {
    state = state.copyWith(pending: true, error: null);
    try {
      await _watchService.setLogStreaming(false);
      state = state.copyWith(
        requestedByApp: false,
        enabledOnWatch: false,
        pending: false,
      );
    } catch (e) {
      state = state.copyWith(
        pending: false,
        error: e.toString(),
      );
    }
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
final logEntriesProvider = StateNotifierProvider<LogEntriesNotifier, List<LogEntry>>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  return LogEntriesNotifier(watchService);
});

class LogEntriesNotifier extends StateNotifier<List<LogEntry>> {
  static const int maxEntries = 1000;
  
  /// BLE log message delimiters (from watch firmware)
  static const String _bleLogPrefix = '<BLELOG>';
  static const String _bleLogSuffix = '</BLELOG>';
  
  final WatchService _watchService;
  int _nextId = 1;
  StreamSubscription<String>? _incomingSubscription;
  
  /// Buffer for incomplete log messages (logs can span multiple BLE packets)
  final StringBuffer _logBuffer = StringBuffer();
  bool _isBufferingLog = false;

  LogEntriesNotifier(this._watchService) : super([]) {
    _subscribeToStreams();
  }

  void _subscribeToStreams() {
    // Only subscribe to incoming data - we only want real logs from BLELOG wrapper
    _incomingSubscription = _watchService.rawIncomingData.listen((String data) {
      _processIncomingData(data);
    });
    // Note: We don't subscribe to outgoing data for the log viewer
    // The log viewer is for firmware logs only, not BLE protocol traffic
  }

  /// Process incoming data, extracting only BLELOG-wrapped log messages
  void _processIncomingData(String data) {
    String remaining = data;
    
    while (remaining.isNotEmpty) {
      if (_isBufferingLog) {
        // We're in the middle of receiving a log message
        final suffixIndex = remaining.indexOf(_bleLogSuffix);
        if (suffixIndex >= 0) {
          // Found the end of the log message
          _logBuffer.write(remaining.substring(0, suffixIndex));
          _emitLogEntry(_logBuffer.toString());
          _logBuffer.clear();
          _isBufferingLog = false;
          remaining = remaining.substring(suffixIndex + _bleLogSuffix.length);
        } else {
          // Still buffering, add all data
          _logBuffer.write(remaining);
          remaining = '';
        }
      } else {
        // Check if this data contains a log prefix
        final prefixIndex = remaining.indexOf(_bleLogPrefix);
        if (prefixIndex >= 0) {
          // Found a log prefix - ignore any data before it (protocol traffic)
          
          // Start buffering the log message
          final afterPrefix = remaining.substring(prefixIndex + _bleLogPrefix.length);
          final suffixIndex = afterPrefix.indexOf(_bleLogSuffix);
          
          if (suffixIndex >= 0) {
            // Complete log message in this packet
            _emitLogEntry(afterPrefix.substring(0, suffixIndex));
            remaining = afterPrefix.substring(suffixIndex + _bleLogSuffix.length);
          } else {
            // Log continues in next packet(s)
            _isBufferingLog = true;
            _logBuffer.write(afterPrefix);
            remaining = '';
          }
        } else {
          // No log prefix - ignore this data (it's protocol traffic, not logs)
          remaining = '';
        }
      }
    }
  }
  
  /// Emit a log entry (from BLELOG wrapper)
  void _emitLogEntry(String logContent) {
    if (logContent.isEmpty) return;
    
    final entry = LogEntry.incoming(
      id: _nextId++,
      message: logContent,
      messageType: 'log',
      type: LogEntryType.log,
      isJson: false,
    );
    _addEntry(entry);
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

  @override
  void dispose() {
    _incomingSubscription?.cancel();
    super.dispose();
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
/// Wired to watch service streams to automatically capture TX/RX traffic
final commLogRepositoryProvider = StateNotifierProvider<CommLogNotifier, List<CommLogEntry>>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  return CommLogNotifier(watchService);
});

/// State notifier that maintains the comm log repository and subscribes to watch streams
class CommLogNotifier extends StateNotifier<List<CommLogEntry>> {
  static const String _bleLogPrefix = '<BLELOG>';
  static const String _bleLogSuffix = '</BLELOG>';

  final WatchService _watchService;
  final CommLogRepository _repo = CommLogRepository();
  StreamSubscription<String>? _rxSubscription;
  StreamSubscription<String>? _txSubscription;
  bool _discardingBleLog = false;

  CommLogNotifier(this._watchService) : super([]) {
    _subscribeToStreams();
  }

  CommLogRepository get repository => _repo;

  /// Remove BLELOG-wrapped firmware debug logs so the comm log only shows protocol traffic.
  /// Returns null if the entire chunk was debug-only.
  String? _stripDebugLogs(String data) {
    var remaining = data;
    final buffer = StringBuffer();

    while (remaining.isNotEmpty) {
      if (_discardingBleLog) {
        final endIndex = remaining.indexOf(_bleLogSuffix);
        if (endIndex == -1) {
          // Still inside a debug log segment - discard everything in this chunk.
          return buffer.isEmpty ? null : buffer.toString();
        }
        remaining = remaining.substring(endIndex + _bleLogSuffix.length);
        _discardingBleLog = false;
        continue;
      }

      final startIndex = remaining.indexOf(_bleLogPrefix);
      if (startIndex == -1) {
        buffer.write(remaining);
        break;
      }

      if (startIndex > 0) {
        buffer.write(remaining.substring(0, startIndex));
      }

      remaining = remaining.substring(startIndex + _bleLogPrefix.length);
      final endIndex = remaining.indexOf(_bleLogSuffix);

      if (endIndex == -1) {
        _discardingBleLog = true;
        break;
      }

      remaining = remaining.substring(endIndex + _bleLogSuffix.length);
    }

    final sanitized = buffer.toString();
    return sanitized.isEmpty ? null : sanitized;
  }

  void _subscribeToStreams() {
    _rxSubscription = _watchService.rawIncomingData.listen((data) {
      final sanitized = _stripDebugLogs(data);
      if (sanitized == null) return;

      _repo.addRx(sanitized);
      // Return a new list to trigger rebuild
      state = List.from(_repo.entries);
    });

    _txSubscription = _watchService.rawOutgoingData.listen((data) {
      _repo.addTx(data);
      // Return a new list to trigger rebuild
      state = List.from(_repo.entries);
    });
  }

  void clear() {
    _repo.clear();
    state = [];
  }

  @override
  void dispose() {
    _rxSubscription?.cancel();
    _txSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for communication log entries (refreshes on change)
final commLogEntriesProvider = Provider<List<CommLogEntry>>((ref) {
  final entries = ref.watch(commLogRepositoryProvider);
  // Return in chronological order (oldest first, newest last)
  // This matches the auto-scroll to bottom behavior in the UI
  return entries.toList();
});

/// Provider for communication log statistics
final commLogStatsProvider = Provider<CommLogStats>((ref) {
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
// Sensor Providers (T102)
// ============================================================================

/// Provider for sensor GATT service
/// Note: This needs to be initialized after connection is established
final sensorServiceProvider = Provider<SensorGattService?>((ref) {
  // This will be set up when developer tools screen is opened
  // and watch is connected
  return null;
});

/// Provider for all sensor readings (combines all sensor buffers)
/// This is used by the sensor debug screen to receive sensor data
final sensorReadingsProvider = StreamProvider<List<SensorReading>>((ref) {
  // For now, return an empty stream since sensor GATT isn't fully connected
  // In a full implementation, this would combine all sensor streams
  return Stream.value(<SensorReading>[]);
});

/// Provider for sensor streaming state
final sensorStreamingStateProvider = StateProvider<SensorStreamingState>((ref) {
  return const SensorStreamingState();
});

/// State for which sensors are currently streaming
class SensorStreamingState {
  final bool accelerometer;
  final bool gyroscope;
  final bool ppg;
  final bool temperature;

  const SensorStreamingState({
    this.accelerometer = false,
    this.gyroscope = false,
    this.ppg = false,
    this.temperature = false,
  });

  SensorStreamingState copyWith({
    bool? accelerometer,
    bool? gyroscope,
    bool? ppg,
    bool? temperature,
  }) {
    return SensorStreamingState(
      accelerometer: accelerometer ?? this.accelerometer,
      gyroscope: gyroscope ?? this.gyroscope,
      ppg: ppg ?? this.ppg,
      temperature: temperature ?? this.temperature,
    );
  }

  bool get any => accelerometer || gyroscope || ppg || temperature;
}

/// Provider for accelerometer readings buffer
final accelerometerBufferProvider = StateNotifierProvider<SensorBufferNotifier, List<SensorReading>>((ref) {
  return SensorBufferNotifier(SensorType.accelerometer);
});

/// Provider for gyroscope readings buffer
final gyroscopeBufferProvider = StateNotifierProvider<SensorBufferNotifier, List<SensorReading>>((ref) {
  return SensorBufferNotifier(SensorType.gyroscope);
});

/// Provider for temperature readings buffer
final temperatureBufferProvider = StateNotifierProvider<SensorBufferNotifier, List<SensorReading>>((ref) {
  return SensorBufferNotifier(SensorType.temperature);
});

class SensorBufferNotifier extends StateNotifier<List<SensorReading>> {
  static const int maxReadings = 200;
  
  final SensorType type;

  SensorBufferNotifier(this.type) : super([]);

  void add(SensorReading reading) {
    if (reading.type != type) return;
    
    final newList = [...state, reading];
    if (newList.length > maxReadings) {
      state = newList.sublist(newList.length - maxReadings);
    } else {
      state = newList;
    }
  }

  void clear() {
    state = [];
  }
}

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
