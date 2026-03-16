import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location/gps_service.dart';
import '../services/protocol/protocol_service.dart';
import '../services/watch_service.dart';
import 'watch_service_provider.dart';

part 'gps_providers.freezed.dart';

/// GPS service provider
final gpsServiceProvider = Provider<GpsService>((ref) {
  return GpsService();
});

/// State for GPS tracking
@freezed
abstract class GpsState with _$GpsState {
  const factory GpsState({
    @Default(false) bool isActive,
    @Default(false) bool isRequesting,
    Position? lastPosition,
    GpsError? lastError,
    DateTime? lastUpdateTime,
  }) = _GpsState;
}

/// GPS notifier that handles GPS power requests from watch
class GpsNotifier extends StateNotifier<GpsState> {
  final GpsService _gpsService;
  final WatchService _watchService;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  Timer? _updateTimer;

  /// Update interval when GPS is active (5 seconds as per spec)
  static const _updateInterval = Duration(seconds: 5);

  GpsNotifier(this._gpsService, this._watchService) : super(const GpsState()) {
    _init();
  }

  void _init() {
    debugPrint('[GpsNotifier] Initializing - listening to watch messages');
    _messageSubscription =
        _watchService.incomingMessages.listen(_handleWatchMessage);
  }

  void _handleWatchMessage(Map<String, dynamic> message) {
    final type = message['t'] as String?;
    if (type != 'gps_power') return;

    final enabled = message['status'] == true;
    debugPrint('[GpsNotifier] Received gps_power message: enabled=$enabled');
    _handleGpsPowerRequest(enabled);
  }

  /// Handle GPS power request from watch
  Future<void> _handleGpsPowerRequest(bool enabled) async {
    if (enabled) {
      await _startGpsUpdates();
    } else {
      _stopGpsUpdates();
    }
  }

  /// Start sending GPS updates to the watch
  Future<void> _startGpsUpdates() async {
    if (state.isActive) {
      debugPrint('[GpsNotifier] GPS already active');
      return;
    }

    debugPrint('[GpsNotifier] Starting GPS updates');
    state = state.copyWith(isActive: true, lastError: null);

    // Send initial location immediately
    await _sendCurrentLocation();

    // Start periodic updates
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_updateInterval, (_) {
      _sendCurrentLocation();
    });
  }

  /// Stop GPS updates
  void _stopGpsUpdates() {
    debugPrint('[GpsNotifier] Stopping GPS updates');
    _updateTimer?.cancel();
    _updateTimer = null;
    state = state.copyWith(isActive: false);
  }

  /// Get current location and send to watch
  Future<void> _sendCurrentLocation() async {
    if (state.isRequesting) {
      debugPrint('[GpsNotifier] Already requesting location, skipping');
      return;
    }

    state = state.copyWith(isRequesting: true);

    try {
      final result = await _gpsService.getCurrentLocation();

      if (result.isSuccess && result.position != null) {
        final position = result.position!;
        state = state.copyWith(
          isRequesting: false,
          lastPosition: position,
          lastUpdateTime: DateTime.now(),
          lastError: null,
        );

        // Send to watch
        await _sendGpsToWatch(position);
      } else {
        debugPrint('[GpsNotifier] GPS error: ${result.error}');
        state = state.copyWith(
          isRequesting: false,
          lastError: result.error,
        );
      }
    } catch (e) {
      debugPrint('[GpsNotifier] Exception getting location: $e');
      state = state.copyWith(
        isRequesting: false,
        lastError: GpsError.locationUnavailable,
      );
    }
  }

  /// Send GPS data to watch using Gadgetbridge protocol
  Future<void> _sendGpsToWatch(Position position) async {
    final gpsData = WatchGpsData(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speedKph: position.speed * 3.6, // m/s to km/h
      courseDegrees: position.heading,
      timestampMs: position.timestamp.millisecondsSinceEpoch,
      hdop: position.accuracy, // Using accuracy as HDOP approximation
      source: 'phone',
    );

    debugPrint(
        '[GpsNotifier] Sending GPS: ${position.latitude}, ${position.longitude}');
    await _watchService.sendGpsData(gpsData);
  }

  /// Manually trigger a location update (for testing)
  Future<void> requestLocationUpdate() async {
    await _sendCurrentLocation();
  }

  /// Open app settings so user can enable location permission
  /// 
  /// Call this when [GpsError.permissionDeniedForever] is encountered.
  Future<bool> openAppSettings() async {
    return _gpsService.openAppSettings();
  }

  /// Open system location settings
  /// 
  /// Call this when [GpsError.serviceDisabled] is encountered.
  Future<bool> openLocationSettings() async {
    return _gpsService.openLocationSettings();
  }

  @override
  void dispose() {
    debugPrint('[GpsNotifier] Disposing');
    _messageSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Provider for GPS state and control
final gpsNotifierProvider =
    StateNotifierProvider<GpsNotifier, GpsState>((ref) {
  final gpsService = ref.watch(gpsServiceProvider);
  final watchService = ref.watch(watchServiceProvider);
  return GpsNotifier(gpsService, watchService);
});

/// Whether GPS updates are currently active
final gpsActiveProvider = Provider<bool>((ref) {
  return ref.watch(gpsNotifierProvider).isActive;
});

/// Last GPS position sent to watch
final lastGpsPositionProvider = Provider<Position?>((ref) {
  return ref.watch(gpsNotifierProvider).lastPosition;
});

/// Last GPS error (if any)
final gpsErrorProvider = Provider<GpsError?>((ref) {
  return ref.watch(gpsNotifierProvider).lastError;
});
