import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/connection.dart';
import '../../data/repositories/battery_repository.dart';
import '../../providers/watch_service_provider.dart';
import '../watch_service.dart';

/// Service that stores battery readings when they arrive from the watch
///
/// The watch periodically sends battery status updates via the Gadgetbridge
/// protocol. This service listens to those updates and stores them in the
/// database for analytics charts.
///
/// Unlike a timer-based sampling approach, this stores readings exactly when
/// the watch reports them, avoiding duplicate or redundant samples.
class BatteryStorageService {
  final WatchService _watchService;
  final BatteryRepository _batteryRepository;

  StreamSubscription<int>? _batterySubscription;
  StreamSubscription<Connection>? _connectionSubscription;

  String? _currentWatchId;
  int? _lastStoredLevel;
  DateTime? _lastStoredTime;

  /// Minimum time between stored readings (5 minutes)
  /// This prevents storing too many readings if the watch sends frequent updates
  static const _minStorageInterval = Duration(minutes: 5);

  BatteryStorageService(this._watchService, this._batteryRepository);

  /// Start listening for battery updates
  void start() {
    // Track connection to get watch ID and charging status
    _connectionSubscription = _watchService.connectionStream.listen((
      connection,
    ) {
      if (connection.isConnected) {
        _currentWatchId = connection.watchId;
      } else {
        _currentWatchId = null;
      }
    });

    // Store initial watch ID if already connected
    if (_watchService.isConnected) {
      _currentWatchId = _watchService.currentConnection.watchId;
    }

    // Listen for battery updates from the watch
    _batterySubscription = _watchService.batteryStream.listen(_onBatteryUpdate);
  }

  /// Stop listening
  void stop() {
    _batterySubscription?.cancel();
    _batterySubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  Future<void> _onBatteryUpdate(int level) async {
    final watchId = _currentWatchId;
    if (watchId == null || watchId.isEmpty) return;

    // Throttle storage: only store if enough time has passed or level changed significantly
    final now = DateTime.now();
    final shouldStore = _shouldStoreReading(level, now);

    if (!shouldStore) return;

    final isCharging = _watchService.currentConnection.isCharging;

    try {
      await _batteryRepository.insertBatteryReading(
        watchId: watchId,
        level: level,
        isCharging: isCharging,
      );

      _lastStoredLevel = level;
      _lastStoredTime = now;
    } catch (e) {
      debugPrint('[BatteryStorage] Failed to store: $e');
    }
  }

  bool _shouldStoreReading(int level, DateTime now) {
    // Always store first reading
    if (_lastStoredTime == null) return true;

    // Store if enough time has passed
    if (now.difference(_lastStoredTime!) >= _minStorageInterval) return true;

    // Store if level changed significantly (5% or more)
    if (_lastStoredLevel != null) {
      final delta = (level - _lastStoredLevel!).abs();
      if (delta >= 5) return true;
    }

    return false;
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}

/// Provider for battery storage service
final batteryStorageServiceProvider = Provider<BatteryStorageService>((ref) {
  final watchService = ref.watch(watchServiceProvider);
  final batteryRepository = ref.watch(batteryRepositoryProvider);

  final service = BatteryStorageService(watchService, batteryRepository);
  service.start();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
