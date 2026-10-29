import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/utils/lifecycle_logger.dart';

/// Access to Android diagnostics and battery settings.
class ForegroundService {
  static const _channel = MethodChannel('dev.zswatch.app/foreground_service');

  static ForegroundService? _instance;
  static ForegroundService get instance => _instance ??= ForegroundService._();

  ForegroundService._();

  /// Retrieve the persisted native/Dart lifecycle diagnostic ring buffer.
  Future<List<LifecycleLogEntry>> getLifecycleEvents() async {
    if (!Platform.isAndroid) return [];

    try {
      final rawEvents =
          await _channel.invokeMethod<List<dynamic>>('getLifecycleEvents') ??
          const <dynamic>[];
      final entries = <LifecycleLogEntry>[];
      for (final rawEvent in rawEvents) {
        if (rawEvent is Map<Object?, Object?>) {
          final entry = LifecycleLogEntry.fromMap(rawEvent);
          if (LifecycleLogger.shouldPersistDiagnostic(
            entry.source,
            entry.message,
          )) {
            entries.add(entry);
          }
        }
      }
      return entries.reversed.toList();
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to read lifecycle events: ${e.message}',
      );
      return [];
    }
  }

  /// Clear persisted lifecycle diagnostics.
  Future<bool> clearLifecycleEvents() async {
    if (!Platform.isAndroid) return true;

    try {
      return await _channel.invokeMethod<bool>('clearLifecycleEvents') ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to clear lifecycle events: ${e.message}',
      );
      return false;
    }
  }

  /// Open the battery optimization settings page (Android only)
  ///
  /// Takes user to the system settings where they can manually disable
  /// battery optimization for this app.
  Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      LifecycleLogger.log(
        'ForegroundService',
        'openBatteryOptimizationSettings',
      );
      return await _channel.invokeMethod<bool>(
            'openBatteryOptimizationSettings',
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint(
        '[ForegroundService] Failed to open battery settings: ${e.message}',
      );
      return false;
    }
  }
}
