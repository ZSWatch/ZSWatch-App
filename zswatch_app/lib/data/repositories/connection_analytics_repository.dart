import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/watch_providers.dart';
import '../database/app_database.dart';
import '../models/connection_event.dart';

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

/// Repository for connection analytics
///
/// Handles:
/// - Recording connection events
/// - Calculating uptime percentage
/// - Tracking disconnection frequency and reasons
/// - Computing average session duration
class ConnectionAnalyticsRepository {
  final AppDatabase _db;

  ConnectionAnalyticsRepository(this._db);

  /// Record a connection event
  Future<int> recordEvent(ConnectionEvent event) {
    return _db.insertConnectionEvent(ConnectionEventsCompanion(
      watchId: Value(event.watchId),
      eventType: Value(event.eventType.toDbString()),
      timestamp: Value(event.timestamp),
      reason: Value(event.reason?.toDbString()),
      details: Value(event.details),
      sessionId: Value(event.sessionId),
    ));
  }

  /// Record a connected event
  Future<int> recordConnected(String watchId, {String? sessionId}) {
    return recordEvent(ConnectionEvent.connected(
      watchId: watchId,
      sessionId: sessionId,
    ));
  }

  /// Record a disconnected event
  Future<int> recordDisconnected(
    String watchId, {
    DisconnectReason reason = DisconnectReason.unknown,
    String? details,
    String? sessionId,
  }) {
    return recordEvent(ConnectionEvent.disconnected(
      watchId: watchId,
      reason: reason,
      details: details,
      sessionId: sessionId,
    ));
  }

  /// Record a reconnect attempt
  Future<int> recordReconnectAttempt(String watchId, {String? sessionId}) {
    return recordEvent(ConnectionEvent.reconnectAttempt(
      watchId: watchId,
      sessionId: sessionId,
    ));
  }

  /// Record a failed reconnect
  Future<int> recordReconnectFailed(
    String watchId, {
    String? details,
    String? sessionId,
  }) {
    return recordEvent(ConnectionEvent.reconnectFailed(
      watchId: watchId,
      details: details,
      sessionId: sessionId,
    ));
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
    final events = await getEvents(
      watchId: watchId,
      from: from,
      to: to,
    );

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
    final events = await getEvents(
      watchId: watchId,
      from: from,
      to: to,
    );

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
    final events = await getEvents(
      watchId: watchId,
      from: from,
      to: to,
    );

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
    final events = await getEvents(
      watchId: watchId,
      from: from,
      to: to,
    );

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
    final successfulReconnections =
        (reconnectAttempts - reconnectFailures).clamp(0, reconnectAttempts);

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

  /// Delete old connection events
  Future<int> deleteOldEvents(DateTime cutoff) {
    return _db.deleteOldConnectionEvents(cutoff);
  }

  /// Watch connection events stream
  Stream<List<ConnectionEvent>> watchEvents({
    required String watchId,
    int limit = 100,
  }) {
    return _db.watchConnectionEvents(watchId: watchId, limit: limit).map(
          (entities) => entities.map(_entityToModel).toList(),
        );
  }

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
