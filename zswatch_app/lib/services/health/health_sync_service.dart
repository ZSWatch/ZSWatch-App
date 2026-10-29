import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/repositories/health_repository.dart';

/// Activity states from the watch
///
/// Values match the integer stored in database for activity samples.
/// Based on Gadgetbridge ActivityKind.java values.
enum ActivityState {
  unknown(0),
  notWorn(1),
  deepSleep(2),
  lightSleep(3),
  remSleep(4),
  still(5), // ACTIVITY in Gadgetbridge
  running(6),
  walking(7),
  swimming(8),
  cycling(9),
  exercise(10);

  final int value;
  const ActivityState(this.value);

  static ActivityState fromString(String? value) {
    return switch (value) {
      'UNKNOWN' => ActivityState.unknown,
      'NOT_WORN' => ActivityState.notWorn,
      'DEEP_SLEEP' => ActivityState.deepSleep,
      'LIGHT_SLEEP' => ActivityState.lightSleep,
      'REM_SLEEP' => ActivityState.remSleep,
      'ACTIVITY' => ActivityState.still,
      'RUNNING' => ActivityState.running,
      'WALKING' => ActivityState.walking,
      'SWIMMING' => ActivityState.swimming,
      'CYCLING' => ActivityState.cycling,
      'EXERCISE' => ActivityState.exercise,
      _ => ActivityState.unknown,
    };
  }

  static ActivityState fromValue(int value) {
    return ActivityState.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ActivityState.unknown,
    );
  }

  String get displayName {
    return switch (this) {
      ActivityState.unknown => 'Unknown',
      ActivityState.notWorn => 'Not Worn',
      ActivityState.deepSleep => 'Deep Sleep',
      ActivityState.lightSleep => 'Light Sleep',
      ActivityState.remSleep => 'REM Sleep',
      ActivityState.still => 'Still',
      ActivityState.running => 'Running',
      ActivityState.walking => 'Walking',
      ActivityState.swimming => 'Swimming',
      ActivityState.cycling => 'Cycling',
      ActivityState.exercise => 'Exercise',
    };
  }
}

/// Tracks duration spent in each activity state
class ActivityBreakdown {
  final Map<ActivityState, Duration> durations;
  final ActivityState? currentState;
  final DateTime? lastUpdate;

  const ActivityBreakdown({
    this.durations = const {},
    this.currentState,
    this.lastUpdate,
  });

  ActivityBreakdown copyWith({
    Map<ActivityState, Duration>? durations,
    ActivityState? currentState,
    DateTime? lastUpdate,
  }) {
    return ActivityBreakdown(
      durations: durations ?? this.durations,
      currentState: currentState ?? this.currentState,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  /// Total tracked duration
  Duration get totalDuration {
    return durations.values.fold(Duration.zero, (a, b) => a + b);
  }

  /// Get percentage for a state (0.0 to 1.0)
  double getPercentage(ActivityState state) {
    final total = totalDuration;
    if (total == Duration.zero) return 0.0;
    final stateDuration = durations[state] ?? Duration.zero;
    return stateDuration.inSeconds / total.inSeconds;
  }
}

/// Service for health data synchronization and real-time streaming
///
/// Handles:
/// - Real-time heart rate streaming via BLE GATT (0x180D)
/// - Activity data sync via Gadgetbridge protocol (placeholder)
/// - Data persistence to health repository
class HealthSyncService {
  final String? Function() _companionWatchId;
  bool _disposed = false;
  String? get _watchId => _companionWatchId();
  final HealthRepository _healthRepository;

  StreamSubscription<Map<String, dynamic>>? _activitySubscription;

  // Heart rate streaming state
  final _heartRateController = BehaviorSubject<int?>.seeded(null);
  final _isStreamingController = BehaviorSubject<bool>.seeded(false);

  // Step count state (from activity messages)
  final _stepsController = BehaviorSubject<int>.seeded(0);

  // Activity state tracking (breakdown is calculated from database)
  final _activityBreakdownController =
      BehaviorSubject<ActivityBreakdown>.seeded(const ActivityBreakdown());

  /// Stream of real-time heart rate values
  Stream<int?> get heartRateStream => _heartRateController.stream;

  /// Current heart rate value
  int? get currentHeartRate => _heartRateController.value;

  /// Whether HR streaming is active
  Stream<bool> get isStreamingStream => _isStreamingController.stream;

  /// Current streaming state
  bool get isStreaming => _isStreamingController.value;

  /// Stream of step count updates
  Stream<int> get stepsStream => _stepsController.stream;

  /// Current step count
  int get currentSteps => _stepsController.value;

  /// Stream of activity breakdown updates
  Stream<ActivityBreakdown> get activityBreakdownStream =>
      _activityBreakdownController.stream;

  /// Current activity breakdown
  ActivityBreakdown get currentActivityBreakdown =>
      _activityBreakdownController.value;

  /// UI projection only: the native owner has already committed these samples.
  /// This path never creates a BluetoothDevice or writes duplicate rows.
  HealthSyncService.forCompanion({
    required HealthRepository healthRepository,
    required String? Function() watchId,
    required Stream<Map<String, dynamic>> activity,
  }) : _companionWatchId = watchId,
       _healthRepository = healthRepository {
    _activitySubscription = activity.listen(
      _handleActivityMessage,
      onError: (Object error) =>
          debugPrint('[HealthSync] Observer error: $error'),
    );
  }

  /// Handle activity messages from Gadgetbridge protocol
  ///
  /// The watch emits live `act` updates. Historical `actfetch` remains a
  /// firmware placeholder.
  void _handleActivityMessage(Map<String, dynamic> message) {
    if (_disposed) return;
    final type = message['t'] as String?;
    if (type == null) return;

    switch (type) {
      case 'act':
        // Real-time activity update
        _handleActivityUpdate(message);
        break;
      case 'actfetch':
        // Activity fetch response (historical data)
        _handleActivityFetch(message);
        break;
    }
  }

  /// Handle real-time activity update (t:"act")
  ///
  /// Expected format:
  /// { "t": "act", "stp": 1234, "hrm": 72, "act": "WALKING", "ts": 1234567890000, "rt": 1 }
  /// ts is optional - milliseconds since 1970. If not specified, current time is used.
  void _handleActivityUpdate(Map<String, dynamic> message) {
    final watchId = _watchId;
    if (watchId == null) return;

    // Parse timestamp - use provided ts or current time
    final tsMillis = message['ts'] as int?;
    final timestamp = tsMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(tsMillis)
        : DateTime.now();

    final steps = message['stp'] as int?;
    final heartRate = message['hrm'] as int?;
    final activityString = message['act'] as String?;

    if (steps != null) {
      _stepsController.add(steps);
    }

    if (heartRate != null) {
      debugPrint(
        '[HealthSync] Activity update - HR: $heartRate, ts: $timestamp',
      );
      _heartRateController.add(heartRate);
    }

    // Track activity state
    if (activityString != null) {
      unawaited(_refreshActivityBreakdown(watchId));
    }
  }

  /// Refresh activity breakdown from database
  Future<void> _refreshActivityBreakdown(String watchId) async {
    try {
      final now = DateTime.now();
      final breakdownMap = await _healthRepository.getActivityBreakdown(
        watchId: watchId,
        date: now,
      );

      // Convert int keys to ActivityState
      final durations = <ActivityState, Duration>{};
      for (final entry in breakdownMap.entries) {
        final state = ActivityState.fromValue(entry.key);
        durations[state] = entry.value;
      }

      // Get current state from most recent sample
      final todayActivity = await _healthRepository.getDailyActivity(
        watchId: watchId,
        date: now,
      );
      final currentState = todayActivity.isNotEmpty
          ? ActivityState.fromValue(todayActivity.last.intValue)
          : null;

      if (_disposed) return;
      _activityBreakdownController.add(
        ActivityBreakdown(
          durations: durations,
          currentState: currentState,
          lastUpdate: now,
        ),
      );
    } catch (e) {
      debugPrint('[HealthSync] Error refreshing activity breakdown: $e');
    }
  }

  /// Load activity breakdown from database (call on startup/reconnect)
  Future<void> loadActivityBreakdown() async {
    final watchId = _watchId;
    if (watchId == null) return;
    await _refreshActivityBreakdown(watchId);
  }

  /// Reset activity tracking (e.g., at start of day)
  void resetActivityTracking() {
    _activityBreakdownController.add(const ActivityBreakdown());
  }

  /// Handle activity fetch response (t:"actfetch")
  ///
  /// Expected format (Gadgetbridge):
  /// { "t": "actfetch", "d": [{ "ts": 1234567890, "stp": 100, "hrm": 72 }, ...] }
  void _handleActivityFetch(Map<String, dynamic> message) {
    final watchId = _watchId;
    if (watchId == null) return;

    final data = message['d'] as List<dynamic>?;
    if (data == null || data.isEmpty) return;

    debugPrint('[HealthSync] Activity fetch - ${data.length} samples');

    // TODO: Parse and persist historical data when firmware supports this
  }

  /// Request activity sync from watch
  ///
  /// NOTE: Not yet implemented in watch firmware.
  /// This would send a request for historical activity data.
  Future<void> requestActivitySync() async {
    debugPrint(
      '[HealthSync] requestActivitySync - Not yet implemented in firmware',
    );
    // TODO: Send actfetch request when firmware supports this
    // await _watchService.sendGb({'t': 'actfetch'});
  }

  /// Run data cleanup (60-day retention)
  Future<int> cleanupOldData() async {
    return _healthRepository.cleanupOldData();
  }

  /// Dispose resources
  Future<void> dispose() async {
    _disposed = true;

    await _activitySubscription?.cancel();
    await _heartRateController.close();
    await _isStreamingController.close();
    await _stepsController.close();
    await _activityBreakdownController.close();
  }
}
