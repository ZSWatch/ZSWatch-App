import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a GPS location request
class GpsResult {
  final Position? position;
  final GpsError? error;

  GpsResult.success(this.position) : error = null;
  GpsResult.failure(this.error) : position = null;

  bool get isSuccess => position != null;
  bool get isFailure => error != null;
}

/// GPS errors
enum GpsError {
  /// Location services are disabled
  serviceDisabled,

  /// Location permission denied
  permissionDenied,

  /// Location permission denied forever (user selected "Don't ask again")
  permissionDeniedForever,

  /// Failed to get location (timeout or other error)
  locationUnavailable,
}

/// Service for obtaining GPS location from the phone
class GpsService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Check current permission status
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  /// Get current location
  ///
  /// Returns a [GpsResult] with either the position or an error.
  /// This method handles permission checks internally.
  Future<GpsResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 10),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GpsService] Location services disabled');
        return GpsResult.failure(GpsError.serviceDisabled);
      }

      // Check permission
      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[GpsService] Location permission denied');
          return GpsResult.failure(GpsError.permissionDenied);
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[GpsService] Location permission denied forever');
        return GpsResult.failure(GpsError.permissionDeniedForever);
      }

      // Get current position
      debugPrint('[GpsService] Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
      debugPrint(
          '[GpsService] Got position: ${position.latitude}, ${position.longitude}');
      return GpsResult.success(position);
    } catch (e) {
      debugPrint('[GpsService] Error getting location: $e');
      return GpsResult.failure(GpsError.locationUnavailable);
    }
  }

  /// Get last known location (faster but may be stale)
  Future<Position?> getLastKnownLocation() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('[GpsService] Error getting last known location: $e');
      return null;
    }
  }

  /// Stream of position updates for continuous tracking
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // meters
    Duration? interval,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Open app settings so user can manually enable location permission
  /// 
  /// Returns true if settings were opened successfully.
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  /// Open location settings (system location toggle)
  /// 
  /// Returns true if settings were opened successfully.
  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }
}
