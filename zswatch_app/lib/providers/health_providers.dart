import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/health_sample.dart';
import '../data/repositories/health_repository.dart';
import '../services/health/health_sync_service.dart';
import 'watch_providers.dart';
import 'watch_service_provider.dart';

export '../services/health/health_sync_service.dart' show ActivityState, ActivityBreakdown;

part 'health_providers.freezed.dart';

// ==================== Repository Provider ====================

/// Provider for the health repository singleton
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return HealthRepository(db);
});

// ==================== Service Provider ====================

/// Provider for the health sync service singleton
final healthSyncServiceProvider = Provider<HealthSyncService>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  final healthRepository = ref.watch(healthRepositoryProvider);
  
  final service = HealthSyncService(
    watchService: watchService,
    healthRepository: healthRepository,
  );
  
  ref.onDispose(() => service.dispose());
  return service;
});

// ==================== Heart Rate Streaming State ====================

/// State class for heart rate streaming
@freezed
abstract class HeartRateStreamingState with _$HeartRateStreamingState {
  const HeartRateStreamingState._();

  const factory HeartRateStreamingState({
    @Default(false) bool isStreaming,
    int? currentBpm,
    @Default(<HeartRateReading>[]) List<HeartRateReading> recentReadings,
    DateTime? lastUpdate,
  }) = _HeartRateStreamingState;

  /// Average BPM from recent readings
  int? get averageBpm {
    if (recentReadings.isEmpty) return null;
    final sum = recentReadings.map((r) => r.bpm).reduce((a, b) => a + b);
    return sum ~/ recentReadings.length;
  }

  /// Min BPM from recent readings
  int? get minBpm {
    if (recentReadings.isEmpty) return null;
    return recentReadings.map((r) => r.bpm).reduce((a, b) => a < b ? a : b);
  }

  /// Max BPM from recent readings
  int? get maxBpm {
    if (recentReadings.isEmpty) return null;
    return recentReadings.map((r) => r.bpm).reduce((a, b) => a > b ? a : b);
  }
}

/// Single heart rate reading with timestamp
class HeartRateReading {
  final int bpm;
  final DateTime timestamp;

  const HeartRateReading({
    required this.bpm,
    required this.timestamp,
  });
}

/// Notifier for heart rate streaming state
class HeartRateStreamingNotifier extends StateNotifier<HeartRateStreamingState> {
  final HealthSyncService _healthSyncService;
  final Ref _ref;
  
  StreamSubscription<int?>? _hrSubscription;
  StreamSubscription<bool>? _streamingSubscription;
  bool _disposed = false;
  
  /// Maximum number of readings to keep for chart
  static const int maxReadings = 120; // 2 minutes at 1 reading/second

  HeartRateStreamingNotifier(this._healthSyncService, this._ref) 
      : super(const HeartRateStreamingState()) {
    _initialize();
  }

  void _initialize() {
    // Listen to streaming state
    _streamingSubscription = _healthSyncService.isStreamingStream.listen((isStreaming) {
      if (_disposed) return;
      state = state.copyWith(isStreaming: isStreaming);
    });

    // Listen to heart rate values
    _hrSubscription = _healthSyncService.heartRateStream.listen((bpm) {
      if (_disposed) return;
      if (bpm != null) {
        _addReading(bpm);
      }
    });
  }

  void _addReading(int bpm) {
    if (_disposed) return;
    
    final now = DateTime.now();
    final newReading = HeartRateReading(bpm: bpm, timestamp: now);
    
    // Keep only recent readings
    final readings = [...state.recentReadings, newReading];
    if (readings.length > maxReadings) {
      readings.removeRange(0, readings.length - maxReadings);
    }
    
    state = state.copyWith(
      currentBpm: bpm,
      recentReadings: readings,
      lastUpdate: now,
    );
  }

  /// Start heart rate streaming
  Future<void> startStreaming() async {
    final connection = _ref.read(watchConnectionProvider);
    if (!connection.isConnected) return;
    
    await _healthSyncService.startHeartRateStreaming(connection.watchId);
  }

  /// Stop heart rate streaming
  Future<void> stopStreaming() async {
    await _healthSyncService.stopHeartRateStreaming();
    state = state.copyWith(
      isStreaming: false,
      currentBpm: null,
    );
  }

  /// Clear reading history
  void clearReadings() {
    if (_disposed) return;
    state = state.copyWith(recentReadings: []);
  }

  @override
  void dispose() {
    _disposed = true;
    _hrSubscription?.cancel();
    _streamingSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for heart rate streaming notifier
final heartRateStreamingProvider = 
    StateNotifierProvider<HeartRateStreamingNotifier, HeartRateStreamingState>((ref) {
  final healthSyncService = ref.watch(healthSyncServiceProvider);
  return HeartRateStreamingNotifier(healthSyncService, ref);
});

// ==================== Activity Breakdown Provider ====================

/// State class for activity breakdown with range support
@freezed
abstract class ActivityBreakdownState with _$ActivityBreakdownState {
  const factory ActivityBreakdownState({
    @Default(StepsHistoryRange.day) StepsHistoryRange range,
    @Default(ActivityBreakdown()) ActivityBreakdown breakdown,
    @Default(false) bool isLoading,
    String? error,
  }) = _ActivityBreakdownState;
}

/// Notifier for activity breakdown state with range support
class ActivityBreakdownNotifier extends StateNotifier<ActivityBreakdownState> {
  final HealthRepository _healthRepository;
  final HealthSyncService _healthSyncService;
  final Ref _ref;
  
  StreamSubscription<ActivityBreakdown>? _activitySubscription;
  bool _disposed = false;

  ActivityBreakdownNotifier(this._healthRepository, this._healthSyncService, this._ref) 
      : super(const ActivityBreakdownState()) {
    _initialize();
  }
  
  void _initialize() {
    loadData(StepsHistoryRange.day);
    
    // Listen to real-time activity updates - only update when viewing today
    _activitySubscription = _healthSyncService.activityBreakdownStream.listen((breakdown) {
      if (_disposed) return;
      // Only update with real-time data for day view
      if (state.range == StepsHistoryRange.day) {
        state = state.copyWith(breakdown: breakdown);
      }
    });
  }

  /// Load activity breakdown data for the specified range
  Future<void> loadData(StepsHistoryRange range) async {
    final watchId = _ref.read(currentWatchProvider)?.id;
    if (watchId == null) return;

    state = state.copyWith(range: range, isLoading: true);

    try {
      final now = DateTime.now();
      final DateTime from;

      switch (range) {
        case StepsHistoryRange.day:
          from = DateTime(now.year, now.month, now.day);
          break;
        case StepsHistoryRange.week:
          from = now.subtract(const Duration(days: 7));
          break;
        case StepsHistoryRange.month:
          from = now.subtract(const Duration(days: 30));
          break;
      }

      // Get breakdown from database
      final Map<int, Duration> breakdownMap;
      if (range == StepsHistoryRange.day) {
        breakdownMap = await _healthRepository.getActivityBreakdown(
          watchId: watchId,
          date: now,
        );
      } else {
        breakdownMap = await _healthRepository.getActivityBreakdownForRange(
          watchId: watchId,
          from: from,
          to: now,
        );
      }

      // Convert int keys to ActivityState
      final durations = <ActivityState, Duration>{};
      for (final entry in breakdownMap.entries) {
        final activityState = ActivityState.fromValue(entry.key);
        durations[activityState] = entry.value;
      }

      // Get current state (only for day view)
      ActivityState? currentState;
      if (range == StepsHistoryRange.day) {
        final todayActivity = await _healthRepository.getDailyActivity(
          watchId: watchId,
          date: now,
        );
        if (todayActivity.isNotEmpty) {
          currentState = ActivityState.fromValue(todayActivity.last.intValue);
        }
      }

      state = state.copyWith(
        breakdown: ActivityBreakdown(
          durations: durations,
          currentState: currentState,
          lastUpdate: now,
        ),
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh current data
  Future<void> refresh() async {
    await loadData(state.range);
  }
  
  @override
  void dispose() {
    _disposed = true;
    _activitySubscription?.cancel();
    super.dispose();
  }
}

/// Provider for activity breakdown notifier
final activityBreakdownProvider = 
    StateNotifierProvider<ActivityBreakdownNotifier, ActivityBreakdownState>((ref) {
  final healthRepository = ref.watch(healthRepositoryProvider);
  final healthSyncService = ref.watch(healthSyncServiceProvider);
  return ActivityBreakdownNotifier(healthRepository, healthSyncService, ref);
});

// ==================== Health Summary State ====================

/// State class for health summary
@freezed
abstract class HealthSummaryState with _$HealthSummaryState {
  const factory HealthSummaryState({
    @Default(0) int todaySteps,
    int? latestHeartRate,
    @Default(<HealthAggregate>[]) List<HealthAggregate> weeklySteps,
    @Default(false) bool isLoading,
    String? error,
  }) = _HealthSummaryState;
}

/// Notifier for health summary state
class HealthSummaryNotifier extends StateNotifier<HealthSummaryState> {
  final HealthRepository _healthRepository;
  final HealthSyncService _healthSyncService;
  final Ref _ref;
  
  StreamSubscription<int>? _stepsSubscription;
  StreamSubscription<int?>? _hrSubscription;
  bool _disposed = false;

  HealthSummaryNotifier(this._healthRepository, this._healthSyncService, this._ref) 
      : super(const HealthSummaryState()) {
    _initialize();
  }
  
  void _initialize() {
    _loadSummary();
    
    // Listen to real-time step updates
    _stepsSubscription = _healthSyncService.stepsStream.listen((steps) {
      if (_disposed) return;
      state = state.copyWith(todaySteps: steps);
    });
    
    // Listen to real-time HR updates
    _hrSubscription = _healthSyncService.heartRateStream.listen((hr) {
      if (_disposed) return;
      if (hr != null) {
        state = state.copyWith(latestHeartRate: hr);
      }
    });
  }

  Future<void> _loadSummary() async {
    final watchId = _ref.read(currentWatchProvider)?.id;
    if (watchId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      // Load today's steps
      final todaySteps = await _healthRepository.getTodaySteps(watchId);

      // Load latest heart rate
      final latestHr = await _healthRepository.getLatestHeartRate(watchId);

      // Load weekly steps
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final weeklySteps = await _healthRepository.getStepsHistory(
        watchId: watchId,
        from: weekAgo,
        to: now,
        granularity: Granularity.daily,
      );

      state = state.copyWith(
        todaySteps: todaySteps,
        latestHeartRate: latestHr?.intValue,
        weeklySteps: weeklySteps,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh health summary
  Future<void> refresh() async {
    await _loadSummary();
  }
  
  @override
  void dispose() {
    _disposed = true;
    _stepsSubscription?.cancel();
    _hrSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for health summary notifier
final healthSummaryProvider = 
    StateNotifierProvider<HealthSummaryNotifier, HealthSummaryState>((ref) {
  final healthRepository = ref.watch(healthRepositoryProvider);
  final healthSyncService = ref.watch(healthSyncServiceProvider);
  return HealthSummaryNotifier(healthRepository, healthSyncService, ref);
});

// ==================== Steps History State ====================

/// Time range for steps history
enum StepsHistoryRange {
  day,
  week,
  month,
}

/// State class for steps history
@freezed
abstract class StepsHistoryState with _$StepsHistoryState {
  const factory StepsHistoryState({
    @Default(StepsHistoryRange.day) StepsHistoryRange range,
    @Default(<HealthAggregate>[]) List<HealthAggregate> data,
    @Default(0) int totalSteps,
    @Default(false) bool isLoading,
    String? error,
  }) = _StepsHistoryState;
}

/// Notifier for steps history state
class StepsHistoryNotifier extends StateNotifier<StepsHistoryState> {
  final HealthRepository _healthRepository;
  final HealthSyncService _healthSyncService;
  final Ref _ref;
  
  StreamSubscription<int>? _stepsSubscription;
  bool _disposed = false;

  StepsHistoryNotifier(this._healthRepository, this._healthSyncService, this._ref) 
      : super(const StepsHistoryState()) {
    _initialize();
  }
  
  void _initialize() {
    loadData(StepsHistoryRange.day);
    
    // Listen to real-time step updates - only update total when viewing today
    _stepsSubscription = _healthSyncService.stepsStream.listen((steps) {
      if (_disposed) return;
      // Only update total steps in real-time for day view
      // For week/month views, we want to show the historical totals from database
      if (state.range == StepsHistoryRange.day) {
        state = state.copyWith(totalSteps: steps);
      }
    });
  }

  /// Load steps data for the specified range
  Future<void> loadData(StepsHistoryRange range) async {
    final watchId = _ref.read(currentWatchProvider)?.id;
    if (watchId == null) return;

    state = state.copyWith(range: range, isLoading: true);

    try {
      final now = DateTime.now();
      final DateTime from;
      final Granularity granularity;

      switch (range) {
        case StepsHistoryRange.day:
          from = DateTime(now.year, now.month, now.day);
          granularity = Granularity.hourly;
          break;
        case StepsHistoryRange.week:
          from = now.subtract(const Duration(days: 7));
          granularity = Granularity.daily;
          break;
        case StepsHistoryRange.month:
          from = now.subtract(const Duration(days: 30));
          granularity = Granularity.daily;
          break;
      }

      final data = await _healthRepository.getStepsHistory(
        watchId: watchId,
        from: from,
        to: now,
        granularity: granularity,
      );

      // For day view, just use the max (current cumulative) value
      // For week/month, sum up each day's max value
      final int total;
      if (data.isEmpty) {
        total = 0;
      } else if (range == StepsHistoryRange.day) {
        // For today, use the max value since it's cumulative
        total = data.map((a) => a.total.round()).reduce((a, b) => a > b ? a : b);
      } else {
        // For week/month, sum up each period's max
        total = data.map((a) => a.total.round()).reduce((a, b) => a + b);
      }

      state = state.copyWith(
        data: data,
        totalSteps: total,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh current data
  Future<void> refresh() async {
    await loadData(state.range);
  }
  
  @override
  void dispose() {
    _disposed = true;
    _stepsSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for steps history notifier
final stepsHistoryProvider = 
    StateNotifierProvider<StepsHistoryNotifier, StepsHistoryState>((ref) {
  final healthRepository = ref.watch(healthRepositoryProvider);
  final healthSyncService = ref.watch(healthSyncServiceProvider);
  return StepsHistoryNotifier(healthRepository, healthSyncService, ref);
});

// ==================== Heart Rate History State ====================

/// State class for heart rate history
class HeartRateHistoryState {
  final List<HealthSample> todayReadings;
  final HealthAggregate? todayAggregate;
  final bool isLoading;
  final String? error;

  const HeartRateHistoryState({
    this.todayReadings = const [],
    this.todayAggregate,
    this.isLoading = false,
    this.error,
  });

  HeartRateHistoryState copyWith({
    List<HealthSample>? todayReadings,
    HealthAggregate? todayAggregate,
    bool? isLoading,
    String? error,
  }) {
    return HeartRateHistoryState(
      todayReadings: todayReadings ?? this.todayReadings,
      todayAggregate: todayAggregate ?? this.todayAggregate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for heart rate history state
class HeartRateHistoryNotifier extends StateNotifier<HeartRateHistoryState> {
  final HealthRepository _healthRepository;
  final HealthSyncService _healthSyncService;
  final Ref _ref;
  
  StreamSubscription<int?>? _hrSubscription;
  bool _disposed = false;

  HeartRateHistoryNotifier(this._healthRepository, this._healthSyncService, this._ref) 
      : super(const HeartRateHistoryState()) {
    _initialize();
  }
  
  void _initialize() {
    loadData();
    
    // Listen to real-time HR updates (from activity messages or live streaming)
    // and refresh data when new HR values arrive
    _hrSubscription = _healthSyncService.heartRateStream.listen((hr) {
      if (_disposed || hr == null) return;
      // Reload data from database to include the new reading
      loadData();
    });
  }

  /// Load today's heart rate data
  Future<void> loadData() async {
    final watchId = _ref.read(currentWatchProvider)?.id;
    if (watchId == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final now = DateTime.now();
      final readings = await _healthRepository.getDailyHeartRate(
        watchId: watchId,
        date: now,
      );

      HealthAggregate? aggregate;
      if (readings.isNotEmpty) {
        aggregate = HealthAggregate.fromSamples(
          samples: readings,
          periodStart: DateTime(now.year, now.month, now.day),
          periodEnd: now,
          granularity: Granularity.daily,
        );
      }

      state = state.copyWith(
        todayReadings: readings,
        todayAggregate: aggregate,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await loadData();
  }
  
  @override
  void dispose() {
    _disposed = true;
    _hrSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for heart rate history notifier
final heartRateHistoryProvider = 
    StateNotifierProvider<HeartRateHistoryNotifier, HeartRateHistoryState>((ref) {
  final healthRepository = ref.watch(healthRepositoryProvider);
  final healthSyncService = ref.watch(healthSyncServiceProvider);
  return HeartRateHistoryNotifier(healthRepository, healthSyncService, ref);
});

// ==================== Data Cleanup Provider ====================

/// Provider for running data cleanup
final dataCleanupProvider = FutureProvider<int>((ref) async {
  final healthRepository = ref.watch(healthRepositoryProvider);
  return healthRepository.cleanupOldData();
});
