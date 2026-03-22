import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/battery_repository.dart';
import '../data/repositories/connection_analytics_repository.dart';
import '../services/analytics/battery_storage_service.dart';
import '../services/analytics/connection_analytics_service.dart';
import 'watch_providers.dart';
import 'watch_service_provider.dart';

// Re-export repository providers for convenient access
export '../data/repositories/battery_repository.dart' show batteryRepositoryProvider;
export '../data/repositories/connection_analytics_repository.dart' show connectionAnalyticsRepositoryProvider, ConnectionSegment, ConnectionSegmentType, ConnectionStats;
export '../services/analytics/battery_storage_service.dart' show batteryStorageServiceProvider;
export '../services/analytics/connection_analytics_service.dart' show connectionAnalyticsServiceProvider;

// ============================================================================
// Enums and Constants
// ============================================================================

/// Time range options for connection analytics timeline
enum TimeRangeOption {
  oneHour(Duration(hours: 1), '1h'),
  sixHours(Duration(hours: 6), '6h'),
  twelveHours(Duration(hours: 12), '12h'),
  twentyFourHours(Duration(hours: 24), '24h'),
  sevenDays(Duration(days: 7), '7d');

  final Duration duration;
  final String label;

  const TimeRangeOption(this.duration, this.label);
}

// ============================================================================
// Battery Analytics Providers
// ============================================================================

/// Provider for battery readings from the last 24 hours
final batteryReadings24HoursProvider = FutureProvider.autoDispose
    .family<List<BatteryReadingEntity>, String>((ref, watchId) async {
  final repository = ref.watch(batteryRepositoryProvider);
  return repository.getLast24Hours(watchId);
});

/// Provider for battery readings from the last 7 days
final batteryReadings7DaysProvider = FutureProvider.autoDispose
    .family<List<BatteryReadingEntity>, String>((ref, watchId) async {
  final repository = ref.watch(batteryRepositoryProvider);
  return repository.getLast7Days(watchId);
});

/// Provider for daily battery snapshots (for 7-day chart)
final batteryDailySnapshotsProvider = FutureProvider.autoDispose
    .family<List<BatteryReadingEntity>, String>((ref, watchId) async {
  final repository = ref.watch(batteryRepositoryProvider);
  return repository.getDailySnapshots(watchId: watchId, days: 7);
});

/// Provider for battery drain rate (% per hour)
final batteryDrainRateProvider = FutureProvider.autoDispose
    .family<double?, String>((ref, watchId) async {
  final repository = ref.watch(batteryRepositoryProvider);
  final now = DateTime.now();
  return repository.calculateDrainRatePerHour(
    watchId: watchId,
    from: now.subtract(const Duration(hours: 24)),
    to: now,
  );
});

/// Provider for estimated remaining battery time
final estimatedBatteryTimeProvider = FutureProvider.autoDispose
    .family<Duration?, String>((ref, watchId) async {
  final repository = ref.watch(batteryRepositoryProvider);
  return repository.estimateRemainingTime(watchId);
});

/// Provider for selected watch ID (from connection or primary watch)
final selectedWatchIdProvider = Provider<String?>((ref) {
  final connection = ref.watch(watchConnectionProvider);
  if (connection.isConnected && connection.watchId.isNotEmpty) {
    return connection.watchId;
  }
  final primaryWatch = ref.watch(primaryWatchProvider).valueOrNull;
  return primaryWatch?.id;
});

/// Provider for current watch battery readings (uses selected watch)
final currentWatchBatteryReadingsProvider = FutureProvider.autoDispose<List<BatteryReadingEntity>>((ref) async {
  final selectedWatchId = ref.watch(selectedWatchIdProvider);
  if (selectedWatchId == null) return [];
  
  final repository = ref.watch(batteryRepositoryProvider);
  return repository.getLast24Hours(selectedWatchId);
});

/// Provider for current watch battery drain rate
final currentWatchDrainRateProvider = FutureProvider.autoDispose<double?>((ref) async {
  final selectedWatchId = ref.watch(selectedWatchIdProvider);
  if (selectedWatchId == null) return null;
  
  final repository = ref.watch(batteryRepositoryProvider);
  final now = DateTime.now();
  return repository.calculateDrainRatePerHour(
    watchId: selectedWatchId,
    from: now.subtract(const Duration(hours: 24)),
    to: now,
  );
});

/// Provider for current watch estimated time remaining
final currentWatchEstimatedTimeProvider = FutureProvider.autoDispose<Duration?>((ref) async {
  final selectedWatchId = ref.watch(selectedWatchIdProvider);
  if (selectedWatchId == null) return null;
  
  final repository = ref.watch(batteryRepositoryProvider);
  return repository.estimateRemainingTime(selectedWatchId);
});

// ============================================================================
// Connection Timeline Time Range Selection
// ============================================================================

/// Provider to track the selected time range for connection timeline per watch.
/// Defaults to full range (7 days).
final connectionTimelineRangeProvider = StateProvider.autoDispose
    .family<TimeRangeOption, String>(
      (ref, watchId) => TimeRangeOption.sevenDays,
    );

// ============================================================================
// Connection Analytics Providers
// ============================================================================

/// Provider for connection stats for the last 24 hours
final connectionStats24HoursProvider = FutureProvider.autoDispose
    .family<ConnectionStats, String>((ref, watchId) async {
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  return repository.getLast24HoursStats(watchId);
});

/// Provider for connection stats for the last 7 days
final connectionStats7DaysProvider = FutureProvider.autoDispose
    .family<ConnectionStats, String>((ref, watchId) async {
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  return repository.getLast7DaysStats(watchId);
});

/// Provider for uptime percentage
final uptimePercentageProvider = FutureProvider.autoDispose
    .family<double, ({String watchId, Duration window})>((ref, params) async {
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  final now = DateTime.now();
  return repository.calculateUptimePercentage(
    watchId: params.watchId,
    from: now.subtract(params.window),
    to: now,
  );
});

/// Provider for disconnection count in last 24 hours
final disconnectionCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, watchId) async {
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  final now = DateTime.now();
  return repository.getDisconnectionCount(
    watchId: watchId,
    from: now.subtract(const Duration(hours: 24)),
    to: now,
  );
});

/// Provider for average session duration
final averageSessionDurationProvider = FutureProvider.autoDispose
    .family<Duration, String>((ref, watchId) async {
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  final now = DateTime.now();
  return repository.calculateAverageSessionDuration(
    watchId: watchId,
    from: now.subtract(const Duration(days: 7)),
    to: now,
  );
});

/// Provider for current watch connection stats (24h)
final currentWatchConnectionStatsProvider = FutureProvider.autoDispose<ConnectionStats?>((ref) async {
  final selectedWatchId = ref.watch(selectedWatchIdProvider);
  if (selectedWatchId == null) return null;
  
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  return repository.getLast24HoursStats(selectedWatchId);
});

/// Provider for current watch 7-day connection stats
final currentWatchConnectionStats7DaysProvider = FutureProvider.autoDispose<ConnectionStats?>((ref) async {
  final selectedWatchId = ref.watch(selectedWatchIdProvider);
  if (selectedWatchId == null) return null;
  
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  return repository.getLast7DaysStats(selectedWatchId);
});

/// Provider for connection events stream (for real-time updates)
final connectionEventsStreamProvider = StreamProvider.autoDispose
    .family<List<ConnectionEventEntity>, String>((ref, watchId) {
  final db = ref.watch(databaseProvider);
  return db.watchConnectionEvents(watchId: watchId, limit: 50);
});

/// Provider for the oldest connection event timestamp for a watch.
/// Used to auto-size the timeline window.
final oldestConnectionEventTimeProvider = FutureProvider.autoDispose
    .family<DateTime?, String>((ref, watchId) async {
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  return repository.getOldestEventTime(watchId);
});

/// Provider for the connection timeline segments.
/// The window is determined by the selected time range from connectionTimelineRangeProvider.
final connectionTimelineProvider = FutureProvider.autoDispose
    .family<({List<ConnectionSegment> segments, DateTime windowStart, DateTime windowEnd}), String>(
        (ref, watchId) async {
  final repository = ref.watch(connectionAnalyticsRepositoryProvider);
  final selectedRange = ref.watch(connectionTimelineRangeProvider(watchId));
  final now = DateTime.now();
  final windowStart = now.subtract(selectedRange.duration);
  
  final segments = await repository.getConnectionTimeline(
    watchId: watchId,
    from: windowStart,
    to: now,
  );
  return (segments: segments, windowStart: windowStart, windowEnd: now);
});

/// Provider for current watch connection events stream
final currentWatchConnectionEventsProvider = StreamProvider.autoDispose<List<ConnectionEventEntity>>((ref) {
  final selectedWatchId = ref.watch(selectedWatchIdProvider);
  if (selectedWatchId == null) {
    return Stream.value([]);
  }
  
  final db = ref.watch(databaseProvider);
  return db.watchConnectionEvents(watchId: selectedWatchId, limit: 50);
});

// ============================================================================
// Service Initialization Providers
// ============================================================================

/// Provider that ensures analytics services are initialized
/// Should be watched in a top-level widget to start the services
final analyticsServicesInitializedProvider = Provider<bool>((ref) {
  // Watch the services to ensure they're started
  ref.watch(batteryStorageServiceProvider);
  ref.watch(connectionAnalyticsServiceProvider);
  return true;
});
