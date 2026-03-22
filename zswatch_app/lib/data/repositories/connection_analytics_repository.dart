import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/watch_providers.dart';
import '../database/app_database.dart';
import '../models/connection_event.dart';
import 'base_repository.dart';

/// Statistics about connection quality
class ConnectionStats {
  /// Uptime percentage (0-100) for the period
  final double uptimePercentage;

  /// Total connected time in the period
  final Duration totalConnectedTime;

  /// Number of disconnections in the period
  final int disconnectionCount;

  /// Average session duration
  final Duration averageSessionDuration;

  /// Number of successful reconnections
  final int successfulReconnections;

  /// Number of failed reconnection attempts
  final int failedReconnections;

  /// Reconnection success rate (0-100)
  double get reconnectionSuccessRate {
    final total = successfulReconnections + failedReconnections;
    if (total == 0) return 100;
    return (successfulReconnections / total) * 100;
  }

  const ConnectionStats({
    required this.uptimePercentage,
    required this.totalConnectedTime,
    required this.disconnectionCount,
    required this.averageSessionDuration,
    required this.successfulReconnections,
    required this.failedReconnections,
  });

  static const empty = ConnectionStats(
    uptimePercentage: 0,
    totalConnectedTime: Duration.zero,
    disconnectionCount: 0,
    averageSessionDuration: Duration.zero,
    successfulReconnections: 0,
    failedReconnections: 0,
  );
}

/// Type of a connection timeline segment
enum ConnectionSegmentType {
  /// Watch was connected and the app was in the foreground/background tracking it
  connected,

  /// Watch was disconnected but the app was running and recorded it
  disconnected,

  /// No events recorded — app was likely not running (killed/suspended)
  appNotRunning,
}

/// A contiguous segment of the connection timeline
class ConnectionSegment {
  final DateTime start;
  final DateTime end;
  final ConnectionSegmentType type;

  const ConnectionSegment({
    required this.start,
    required this.end,
    required this.type,
  });

  Duration get duration => end.difference(start);
}

/// Repository for connection analytics
///
/// Handles:
/// - Recording connection events
/// - Calculating uptime percentage
/// - Tracking disconnection frequency and reasons
/// - Computing average session duration
class ConnectionAnalyticsRepository
    extends BaseRepository<ConnectionEvent, ConnectionEventEntity> {
  final AppDatabase _db;

  ConnectionAnalyticsRepository(this._db);

  /// Record a connection event
  Future<int> recordEvent(ConnectionEvent event) {
    return _db.insertConnectionEvent(
      ConnectionEventsCompanion(
        watchId: Value(event.watchId),
        eventType: Value(event.eventType.toDbString()),
        timestamp: Value(event.timestamp),
        reason: Value(event.reason?.toDbString()),
        details: Value(event.details),
        sessionId: Value(event.sessionId),
      ),
    );
  }

  /// Record a connected event
  Future<int> recordConnected(String watchId, {String? sessionId}) {
    return recordEvent(
      ConnectionEvent.connected(watchId: watchId, sessionId: sessionId),
    );
  }

  /// Record a disconnected event
  Future<int> recordDisconnected(
    String watchId, {
    DisconnectReason reason = DisconnectReason.unknown,
    String? details,
    String? sessionId,
  }) {
    return recordEvent(
      ConnectionEvent.disconnected(
        watchId: watchId,
        reason: reason,
        details: details,
        sessionId: sessionId,
      ),
    );
  }

  /// Record a reconnect attempt
  Future<int> recordReconnectAttempt(String watchId, {String? sessionId}) {
    return recordEvent(
      ConnectionEvent.reconnectAttempt(watchId: watchId, sessionId: sessionId),
    );
  }

  /// Record a failed reconnect
  Future<int> recordReconnectFailed(
    String watchId, {
    String? details,
    String? sessionId,
  }) {
    return recordEvent(
      ConnectionEvent.reconnectFailed(
        watchId: watchId,
        details: details,
        sessionId: sessionId,
      ),
    );
  }

  /// Get connection events for a watch within date range
  Future<List<ConnectionEvent>> getEvents({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) async {
    final entities = await _db.getConnectionEvents(
      watchId: watchId,
      from: from,
      to: to,
    );
    return entities.map(_entityToModel).toList();
  }

  /// Get recent disconnection events with reasons
  Future<List<ConnectionEvent>> getRecentDisconnections({
    required String watchId,
    int limit = 20,
  }) async {
    final entities = await _db.getRecentDisconnections(
      watchId: watchId,
      limit: limit,
    );
    return entities.map(_entityToModel).toList();
  }

  /// Calculate connection uptime percentage for a period
  Future<double> calculateUptimePercentage({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) async {
    final events = await getEvents(watchId: watchId, from: from, to: to);

    if (events.isEmpty) return 0;

    // Calculate total connected time
    Duration totalConnected = Duration.zero;
    DateTime? lastConnectTime;

    for (final event in events) {
      if (event.eventType == ConnectionEventType.connected) {
        lastConnectTime = event.timestamp;
      } else if (event.eventType == ConnectionEventType.disconnected &&
          lastConnectTime != null) {
        totalConnected += event.timestamp.difference(lastConnectTime);
        lastConnectTime = null;
      }
    }

    // If still connected at end of period, count until 'to' time
    if (lastConnectTime != null) {
      final endTime = to.isBefore(DateTime.now()) ? to : DateTime.now();
      totalConnected += endTime.difference(lastConnectTime);
    }

    final totalPeriod = to.difference(from);
    if (totalPeriod.inSeconds == 0) return 0;

    return (totalConnected.inSeconds / totalPeriod.inSeconds) * 100;
  }

  /// Calculate total connected time for a period
  Future<Duration> calculateTotalConnectedTime({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) async {
    final events = await getEvents(watchId: watchId, from: from, to: to);

    if (events.isEmpty) return Duration.zero;

    Duration totalConnected = Duration.zero;
    DateTime? lastConnectTime;

    for (final event in events) {
      if (event.eventType == ConnectionEventType.connected) {
        lastConnectTime = event.timestamp;
      } else if (event.eventType == ConnectionEventType.disconnected &&
          lastConnectTime != null) {
        totalConnected += event.timestamp.difference(lastConnectTime);
        lastConnectTime = null;
      }
    }

    // If still connected at end of period
    if (lastConnectTime != null) {
      final endTime = to.isBefore(DateTime.now()) ? to : DateTime.now();
      totalConnected += endTime.difference(lastConnectTime);
    }

    return totalConnected;
  }

  /// Get disconnection count for a period
  Future<int> getDisconnectionCount({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) {
    return _db.getConnectionEventCount(
      watchId: watchId,
      eventType: 'disconnected',
      from: from,
      to: to,
    );
  }

  /// Calculate average session duration for a period
  Future<Duration> calculateAverageSessionDuration({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) async {
    final events = await getEvents(watchId: watchId, from: from, to: to);

    if (events.isEmpty) return Duration.zero;

    List<Duration> sessions = [];
    DateTime? lastConnectTime;

    for (final event in events) {
      if (event.eventType == ConnectionEventType.connected) {
        lastConnectTime = event.timestamp;
      } else if (event.eventType == ConnectionEventType.disconnected &&
          lastConnectTime != null) {
        sessions.add(event.timestamp.difference(lastConnectTime));
        lastConnectTime = null;
      }
    }

    // Include ongoing session
    if (lastConnectTime != null) {
      final endTime = to.isBefore(DateTime.now()) ? to : DateTime.now();
      sessions.add(endTime.difference(lastConnectTime));
    }

    if (sessions.isEmpty) return Duration.zero;

    final totalSeconds = sessions.fold<int>(
      0,
      (sum, duration) => sum + duration.inSeconds,
    );

    return Duration(seconds: totalSeconds ~/ sessions.length);
  }

  /// Get comprehensive connection statistics for a period
  Future<ConnectionStats> getConnectionStats({
    required String watchId,
    required DateTime from,
    required DateTime to,
  }) async {
    final events = await getEvents(watchId: watchId, from: from, to: to);

    if (events.isEmpty) return ConnectionStats.empty;

    // Calculate all stats in one pass
    Duration totalConnected = Duration.zero;
    List<Duration> sessions = [];
    DateTime? lastConnectTime;
    int disconnectionCount = 0;
    int reconnectAttempts = 0;
    int reconnectFailures = 0;

    for (final event in events) {
      switch (event.eventType) {
        case ConnectionEventType.connected:
          lastConnectTime = event.timestamp;
          break;
        case ConnectionEventType.disconnected:
          disconnectionCount++;
          if (lastConnectTime != null) {
            final session = event.timestamp.difference(lastConnectTime);
            sessions.add(session);
            totalConnected += session;
            lastConnectTime = null;
          }
          break;
        case ConnectionEventType.reconnectAttempt:
          reconnectAttempts++;
          break;
        case ConnectionEventType.reconnectFailed:
          reconnectFailures++;
          break;
      }
    }

    // Include ongoing session
    if (lastConnectTime != null) {
      final endTime = to.isBefore(DateTime.now()) ? to : DateTime.now();
      final session = endTime.difference(lastConnectTime);
      sessions.add(session);
      totalConnected += session;
    }

    // Calculate uptime percentage
    final totalPeriod = to.difference(from);
    final uptimePercentage = totalPeriod.inSeconds > 0
        ? (totalConnected.inSeconds / totalPeriod.inSeconds) * 100
        : 0.0;

    // Calculate average session duration
    Duration averageSession = Duration.zero;
    if (sessions.isNotEmpty) {
      final totalSeconds = sessions.fold<int>(
        0,
        (sum, duration) => sum + duration.inSeconds,
      );
      averageSession = Duration(seconds: totalSeconds ~/ sessions.length);
    }

    // Successful reconnections = attempts - failures
    // (each success results in a connected event)
    final successfulReconnections = (reconnectAttempts - reconnectFailures)
        .clamp(0, reconnectAttempts);

    return ConnectionStats(
      uptimePercentage: uptimePercentage,
      totalConnectedTime: totalConnected,
      disconnectionCount: disconnectionCount,
      averageSessionDuration: averageSession,
      successfulReconnections: successfulReconnections,
      failedReconnections: reconnectFailures,
    );
  }

  /// Get stats for the last 24 hours
  Future<ConnectionStats> getLast24HoursStats(String watchId) {
    final now = DateTime.now();
    return getConnectionStats(
      watchId: watchId,
      from: now.subtract(const Duration(hours: 24)),
      to: now,
    );
  }

  /// Get stats for the last 7 days
  Future<ConnectionStats> getLast7DaysStats(String watchId) {
    final now = DateTime.now();
    return getConnectionStats(
      watchId: watchId,
      from: now.subtract(const Duration(days: 7)),
      to: now,
    );
  }

  /// Build a timeline of connection segments for a period.
  ///
  /// Returns a list of [ConnectionSegment] ordered by start time.
  /// Gaps between events with no heartbeat activity are marked as
  /// [ConnectionSegmentType.appNotRunning].
  ///
  /// [appNotRunningThreshold] — minimum silent gap to classify as "app not
  /// running" rather than just "disconnected". Defaults to 10 minutes.
  Future<List<ConnectionSegment>> getConnectionTimeline({
    required String watchId,
    required DateTime from,
    required DateTime to,
    Duration appNotRunningThreshold = const Duration(minutes: 10),
  }) async {
    final events = await getEvents(watchId: watchId, from: from, to: to);
    // Peek at the event just before the window to seed the initial state.
    // Without this, a session that started before windowStart would appear as
    // a gap (appNotRunning) until the first event inside the window.
    final seedEntity = await _db.getLastConnectionEventBefore(
      watchId: watchId,
      before: from,
    );
    final seed = seedEntity != null ? _entityToModel(seedEntity) : null;
    debugPrint('=== TIMELINE DEBUG ===');
    debugPrint('Window: $from → $to');
    debugPrint('Seed event: ${seed?.eventType} @ ${seed?.timestamp}');
    debugPrint('Events in window (${events.length}):');
    for (final e in events) {
      debugPrint('  ${e.eventType} @ ${e.timestamp}');
    }
    final result = _buildTimeline(
      events,
      from,
      to,
      appNotRunningThreshold,
      seed,
    );
    debugPrint('Segments (${result.length}):');
    for (final s in result) {
      debugPrint('  ${s.type} ${s.start} → ${s.end}');
    }
    debugPrint('=== END TIMELINE DEBUG ===');
    return result;
  }

  List<ConnectionSegment> _buildTimeline(
    List<ConnectionEvent> events,
    DateTime from,
    DateTime to,
    Duration appNotRunningThreshold,
    ConnectionEvent? seedEvent,
  ) {
    final List<ConnectionSegment> segments = [];
    DateTime cursor = from;

    // Walk through sorted events and emit segments between them.
    // Connected windows: between a 'connected' and the next 'disconnected'.
    // Disconnected windows: between 'disconnected' and next 'connected'.
    // App-not-running windows: a disconnected gap exceeding the threshold
    //   with no reconnect_attempt events inside it.

    // Seed from the last event before the window so we know whether the watch
    // was already connected at windowStart (avoids a false appNotRunning gap).
    DateTime? sessionStart =
        (seedEvent?.eventType == ConnectionEventType.connected) ? from : null;
    ConnectionEvent? lastDisconnect;

    void _emitGap(
      DateTime start,
      DateTime end,
      List<ConnectionEvent> eventsInGap,
    ) {
      if (end.difference(start) < const Duration(seconds: 30)) return;
      final hasActivity = eventsInGap.any(
        (e) =>
            e.eventType == ConnectionEventType.reconnectAttempt ||
            e.eventType == ConnectionEventType.reconnectFailed,
      );
      final type =
          (!hasActivity && end.difference(start) >= appNotRunningThreshold)
          ? ConnectionSegmentType.appNotRunning
          : ConnectionSegmentType.disconnected;
      segments.add(ConnectionSegment(start: start, end: end, type: type));
    }

    for (final event in events) {
      switch (event.eventType) {
        case ConnectionEventType.connected:
          if (sessionStart != null) {
            // Previous session was never closed (app was killed while connected).
            // Close it as a connected segment up to the cursor position, then
            // emit an appNotRunning gap from cursor to this new connect event.
            if (sessionStart != cursor) {
              segments.add(
                ConnectionSegment(
                  start: sessionStart!,
                  end: cursor,
                  type: ConnectionSegmentType.connected,
                ),
              );
            }
            final gapEvents = events
                .where(
                  (e) =>
                      e.timestamp.isAfter(cursor) &&
                      e.timestamp.isBefore(event.timestamp),
                )
                .toList();
            _emitGap(cursor, event.timestamp, gapEvents);
          } else if (cursor.isBefore(event.timestamp)) {
            // Gap with no prior session — disconnected or app-not-running.
            final gapEvents = events
                .where(
                  (e) =>
                      e.timestamp.isAfter(cursor) &&
                      e.timestamp.isBefore(event.timestamp),
                )
                .toList();
            _emitGap(cursor, event.timestamp, gapEvents);
          }
          sessionStart = event.timestamp;
          cursor = event.timestamp;
          lastDisconnect = null;
          break;

        case ConnectionEventType.disconnected:
          if (sessionStart != null) {
            // Close the connected segment
            segments.add(
              ConnectionSegment(
                start: sessionStart!,
                end: event.timestamp,
                type: ConnectionSegmentType.connected,
              ),
            );
            cursor = event.timestamp;
            sessionStart = null;
          }
          lastDisconnect = event;
          break;

        case ConnectionEventType.reconnectAttempt:
        case ConnectionEventType.reconnectFailed:
          // These don't open/close segments, but prevent gap → appNotRunning
          break;
      }
    }

    // Handle the tail: from cursor to `to`
    if (sessionStart != null) {
      // Still connected
      segments.add(
        ConnectionSegment(
          start: sessionStart!,
          end: to.isBefore(DateTime.now()) ? to : DateTime.now(),
          type: ConnectionSegmentType.connected,
        ),
      );
    } else if (cursor.isBefore(to)) {
      final tailEvents = events
          .where((e) => e.timestamp.isAfter(cursor))
          .toList();
      _emitGap(
        cursor,
        to.isBefore(DateTime.now()) ? to : DateTime.now(),
        tailEvents,
      );
    }

    segments.sort((a, b) => a.start.compareTo(b.start));
    return segments;
  }

  /// Delete old connection events
  Future<int> deleteOldEvents(DateTime cutoff) {
    return _db.deleteOldConnectionEvents(cutoff);
  }

  /// Delete all connection events for a watch (for manual "clear sample" use)
  Future<int> clearAllEvents(String watchId) {
    return _db.deleteAllConnectionEventsForWatch(watchId);
  }

  /// Return the timestamp of the oldest stored event for a watch, or null if none.
  Future<DateTime?> getOldestEventTime(String watchId) async {
    final events = await _db.getConnectionEvents(
      watchId: watchId,
      from: DateTime.fromMillisecondsSinceEpoch(0),
      to: DateTime.now().add(const Duration(seconds: 1)),
    );
    if (events.isEmpty) return null;
    return events
        .map((e) => e.timestamp)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Watch connection events stream
  Stream<List<ConnectionEvent>> watchEvents({
    required String watchId,
    int limit = 100,
  }) {
    return _db
        .watchConnectionEvents(watchId: watchId, limit: limit)
        .map((entities) => entities.map(_entityToModel).toList());
  }

  @override
  ConnectionEvent fromEntity(ConnectionEventEntity entity) =>
      _entityToModel(entity);

  ConnectionEvent _entityToModel(ConnectionEventEntity entity) {
    return ConnectionEvent(
      id: entity.id,
      watchId: entity.watchId,
      eventType: ConnectionEventTypeExtension.fromDbString(entity.eventType),
      timestamp: entity.timestamp,
      reason: entity.reason != null
          ? DisconnectReasonExtension.fromDbString(entity.reason)
          : null,
      details: entity.details,
      sessionId: entity.sessionId,
    );
  }
}

/// Provider for connection analytics repository
final connectionAnalyticsRepositoryProvider =
    Provider<ConnectionAnalyticsRepository>((ref) {
      final db = ref.watch(databaseProvider);
      return ConnectionAnalyticsRepository(db);
    });
