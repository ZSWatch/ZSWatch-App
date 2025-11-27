import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/constants/ble_constants.dart';
import '../../data/models/health_sample.dart';
import '../../data/repositories/health_repository.dart';
import '../watch_service.dart';

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
  still(5),      // ACTIVITY in Gadgetbridge
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
  final WatchService _watchService;
  final HealthRepository _healthRepository;

  StreamSubscription<List<int>>? _hrSubscription;
  StreamSubscription<Map<String, dynamic>>? _activitySubscription;

  // Heart rate streaming state
  final _heartRateController = BehaviorSubject<int?>.seeded(null);
  final _isStreamingController = BehaviorSubject<bool>.seeded(false);
  
  // Step count state (from activity messages)
  final _stepsController = BehaviorSubject<int>.seeded(0);
  
  // Activity state tracking (breakdown is calculated from database)
  final _activityBreakdownController = BehaviorSubject<ActivityBreakdown>.seeded(
    const ActivityBreakdown(),
  );

  BluetoothDevice? _device;
  BluetoothCharacteristic? _hrMeasurementChar;

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
  Stream<ActivityBreakdown> get activityBreakdownStream => _activityBreakdownController.stream;
  
  /// Current activity breakdown
  ActivityBreakdown get currentActivityBreakdown => _activityBreakdownController.value;

  HealthSyncService({
    required WatchService watchService,
    required HealthRepository healthRepository,
  })  : _watchService = watchService,
        _healthRepository = healthRepository {
    _initialize();
  }

  void _initialize() {
    // Listen for activity messages from watch (Gadgetbridge protocol)
    _activitySubscription = _watchService.incomingMessages.listen(_handleActivityMessage);
  }

  /// Start heart rate streaming
  ///
  /// Subscribes to the standard BLE Heart Rate Service (0x180D)
  /// and emits readings in real-time.
  Future<void> startHeartRateStreaming(String deviceId) async {
    if (_isStreamingController.value) {
      debugPrint('[HealthSync] HR streaming already active');
      return;
    }

    try {
      _device = BluetoothDevice.fromId(deviceId);

      // Check if already connected
      final isConnected = _device!.isConnected;
      if (!isConnected) {
        debugPrint('[HealthSync] Device not connected, cannot start HR streaming');
        return;
      }

      // Discover services if not already done
      List<BluetoothService> services = _device!.servicesList;
      if (services.isEmpty) {
        services = await _device!.discoverServices();
      }

      // Find Heart Rate Service
      final hrService = services.cast<BluetoothService?>().firstWhere(
            (s) => s?.uuid == Guid(HeartRateUuids.service),
            orElse: () => null,
          );

      if (hrService == null) {
        debugPrint('[HealthSync] Heart Rate Service not found');
        return;
      }

      // Find HR Measurement characteristic
      _hrMeasurementChar = hrService.characteristics
          .cast<BluetoothCharacteristic?>()
          .firstWhere(
            (c) => c?.uuid == Guid(HeartRateUuids.measurement),
            orElse: () => null,
          );

      if (_hrMeasurementChar == null) {
        debugPrint('[HealthSync] HR Measurement characteristic not found');
        return;
      }

      // Subscribe to notifications
      await _hrMeasurementChar!.setNotifyValue(true);
      
      _hrSubscription?.cancel();
      _hrSubscription = _hrMeasurementChar!.onValueReceived.listen(
        _handleHeartRateData,
        onError: (e) => debugPrint('[HealthSync] HR stream error: $e'),
      );

      _isStreamingController.add(true);
      debugPrint('[HealthSync] HR streaming started');

    } catch (e) {
      debugPrint('[HealthSync] Failed to start HR streaming: $e');
      _isStreamingController.add(false);
    }
  }

  /// Stop heart rate streaming
  Future<void> stopHeartRateStreaming() async {
    if (!_isStreamingController.value) return;

    try {
      _hrSubscription?.cancel();
      _hrSubscription = null;

      if (_hrMeasurementChar != null) {
        try {
          await _hrMeasurementChar!.setNotifyValue(false);
        } catch (e) {
          // Ignore errors when disabling notifications (device may have disconnected)
          debugPrint('[HealthSync] Error disabling HR notifications: $e');
        }
      }

      _hrMeasurementChar = null;
      _isStreamingController.add(false);
      _heartRateController.add(null);
      debugPrint('[HealthSync] HR streaming stopped');

    } catch (e) {
      debugPrint('[HealthSync] Error stopping HR streaming: $e');
    }
  }

  /// Parse heart rate measurement data according to BLE Heart Rate Profile
  ///
  /// Format (per BLE HRS specification):
  /// Byte 0: Flags
  ///   - Bit 0: Heart Rate Value Format (0 = UINT8, 1 = UINT16)
  ///   - Bit 1-2: Sensor Contact Status
  ///   - Bit 3: Energy Expended Present
  ///   - Bit 4: RR-Interval Present
  /// Byte 1 (or 1-2): Heart Rate Value
  void _handleHeartRateData(List<int> data) {
    if (data.isEmpty) return;

    try {
      final flags = data[0];
      final isUint16 = (flags & 0x01) != 0;

      int heartRate;
      if (isUint16) {
        // 16-bit heart rate value
        if (data.length < 3) return;
        heartRate = data[1] | (data[2] << 8);
      } else {
        // 8-bit heart rate value
        if (data.length < 2) return;
        heartRate = data[1];
      }

      // Validate range (30-250 BPM is reasonable)
      if (heartRate < 30 || heartRate > 250) {
        debugPrint('[HealthSync] Invalid HR value: $heartRate');
        return;
      }

      debugPrint('[HealthSync] HR: $heartRate BPM');
      _heartRateController.add(heartRate);

      // Persist to repository
      _persistHeartRate(heartRate);

    } catch (e) {
      debugPrint('[HealthSync] Error parsing HR data: $e');
    }
  }

  /// Persist heart rate reading to database
  Future<void> _persistHeartRate(int bpm, [DateTime? timestamp]) async {
    final watchId = _watchService.currentWatch?.id;
    if (watchId == null) return;

    try {
      await _healthRepository.insertHeartRate(
        watchId: watchId,
        bpm: bpm,
        timestamp: timestamp,
      );
    } catch (e) {
      debugPrint('[HealthSync] Error persisting HR: $e');
    }
  }
  
  /// Persist step count to database
  /// 
  /// Note: The watch sends cumulative daily steps, so we store
  /// the latest value with a "daily" granularity, updating the same
  /// record throughout the day.
  Future<void> _persistSteps(String watchId, int steps, [DateTime? timestamp]) async {
    try {
      final ts = timestamp ?? DateTime.now();
      await _healthRepository.insertSteps(
        watchId: watchId,
        steps: steps,
        timestamp: ts,
        granularity: Granularity.realtime,
      );
    } catch (e) {
      debugPrint('[HealthSync] Error persisting steps: $e');
    }
  }

  /// Handle activity messages from Gadgetbridge protocol
  ///
  /// NOTE: Activity sync via Gadgetbridge is not yet implemented in watch firmware.
  /// This is a placeholder for when `t:"act"` and `t:"actfetch"` messages are added.
  void _handleActivityMessage(Map<String, dynamic> message) {
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
    final watchId = _watchService.currentWatch?.id;
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
      debugPrint('[HealthSync] Activity update - steps: $steps, ts: $timestamp');
      _stepsController.add(steps);
      _persistSteps(watchId, steps, timestamp);
    }

    if (heartRate != null) {
      debugPrint('[HealthSync] Activity update - HR: $heartRate, ts: $timestamp');
      _heartRateController.add(heartRate);
      _persistHeartRate(heartRate, timestamp);
    }
    
    // Track activity state
    if (activityString != null) {
      final newState = ActivityState.fromString(activityString);
      debugPrint('[HealthSync] Activity update - state: $activityString -> $newState, ts: $timestamp');
      _persistAndUpdateActivityState(watchId, newState, timestamp);
    }
  }
  
  /// Persist activity state to database and update breakdown
  Future<void> _persistAndUpdateActivityState(
    String watchId, 
    ActivityState state, 
    DateTime timestamp,
  ) async {
    try {
      // Persist to database
      await _healthRepository.insertActivity(
        watchId: watchId,
        activityStateValue: state.value,
        timestamp: timestamp,
      );
      
      // Refresh breakdown from database
      await _refreshActivityBreakdown(watchId);
    } catch (e) {
      debugPrint('[HealthSync] Error persisting activity: $e');
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
      
      _activityBreakdownController.add(ActivityBreakdown(
        durations: durations,
        currentState: currentState,
        lastUpdate: now,
      ));
    } catch (e) {
      debugPrint('[HealthSync] Error refreshing activity breakdown: $e');
    }
  }
  
  /// Load activity breakdown from database (call on startup/reconnect)
  Future<void> loadActivityBreakdown() async {
    final watchId = _watchService.currentWatch?.id;
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
    final watchId = _watchService.currentWatch?.id;
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
    debugPrint('[HealthSync] requestActivitySync - Not yet implemented in firmware');
    // TODO: Send actfetch request when firmware supports this
    // await _watchService.sendGb({'t': 'actfetch'});
  }

  /// Run data cleanup (60-day retention)
  Future<int> cleanupOldData() async {
    return _healthRepository.cleanupOldData();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopHeartRateStreaming();
    await _activitySubscription?.cancel();
    await _heartRateController.close();
    await _isStreamingController.close();
    await _stepsController.close();
    await _activityBreakdownController.close();
  }
}
