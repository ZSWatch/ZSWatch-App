import 'dart:async';

import 'package:flutter/foundation.dart';

import '../protocol/protocol_service.dart';

/// Service for synchronizing time with the watch
///
/// Handles:
/// - Initial time sync on connection
/// - Periodic time sync (optional)
/// - Timezone updates
class TimeSyncService {
  final ProtocolService _protocolService;
  Timer? _periodicSyncTimer;

  TimeSyncService(this._protocolService);

  /// Sync current time to the watch
  ///
  /// Sends the current time and timezone offset to the watch.
  Future<void> syncTime() async {
    final now = DateTime.now();
    final tzOffset = now.timeZoneOffset.inMinutes / 60.0;

    debugPrint('Syncing time: $now (TZ offset: $tzOffset hours)');

    await _protocolService.syncTime(now, timezoneOffsetHours: tzOffset);
  }

  /// Sync a specific time to the watch
  Future<void> syncSpecificTime(DateTime time, {double? timezoneOffsetHours}) async {
    final tzOffset = timezoneOffsetHours ?? time.timeZoneOffset.inMinutes / 60.0;

    debugPrint('Syncing specific time: $time (TZ offset: $tzOffset hours)');

    await _protocolService.syncTime(time, timezoneOffsetHours: tzOffset);
  }

  /// Start periodic time sync
  ///
  /// [interval] - How often to sync time (default: every hour)
  void startPeriodicSync({Duration interval = const Duration(hours: 1)}) {
    stopPeriodicSync();

    // Sync immediately
    syncTime();

    // Then sync periodically
    _periodicSyncTimer = Timer.periodic(interval, (_) {
      syncTime();
    });
  }

  /// Stop periodic time sync
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  /// Check if periodic sync is active
  bool get isPeriodicSyncActive => _periodicSyncTimer != null;

  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
  }
}

/// Extension to create TimeSyncService from protocol service
extension TimeSyncServiceExtension on ProtocolService {
  /// Create a time sync service for this protocol
  TimeSyncService createTimeSyncService() {
    return TimeSyncService(this);
  }
}

