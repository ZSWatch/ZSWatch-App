import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../background/foreground_service.dart';
import '../notification/notification_service.dart';

/// Represents the status of all app permissions
class AppPermissionsStatus {
  /// Bluetooth permissions (scan/connect)
  final bool bluetoothGranted;

  /// Location permission for GPS relay feature
  final LocationPermission locationPermission;

  /// POST_NOTIFICATIONS permission (Android 13+) for foreground service
  final PermissionStatus notificationPermission;

  /// Notification Listener Service access for forwarding notifications to watch
  final bool notificationListenerEnabled;

  /// Battery optimization exemption for reliable background operation
  final bool batteryOptimizationDisabled;

  const AppPermissionsStatus({
    this.bluetoothGranted = false,
    this.locationPermission = LocationPermission.denied,
    this.notificationPermission = PermissionStatus.denied,
    this.notificationListenerEnabled = false,
    this.batteryOptimizationDisabled = false,
  });

  /// Whether location is granted (while in use or always)
  bool get isLocationGranted =>
      locationPermission == LocationPermission.always ||
      locationPermission == LocationPermission.whileInUse;

  /// Whether notification permission is granted
  bool get isNotificationGranted => notificationPermission.isGranted;

  /// Whether all critical permissions are granted (needed for basic app function)
  bool get hasCriticalPermissions => bluetoothGranted;

  /// Whether all recommended permissions are granted
  bool get hasAllRecommendedPermissions =>
      bluetoothGranted &&
      isNotificationGranted &&
      (Platform.isIOS || batteryOptimizationDisabled);

  /// Whether all permissions are granted
  bool get hasAllPermissions =>
      bluetoothGranted &&
      isLocationGranted &&
      isNotificationGranted &&
      notificationListenerEnabled &&
      (Platform.isIOS || batteryOptimizationDisabled);

  /// Get list of missing critical permissions
  List<String> get missingCriticalPermissions {
    final missing = <String>[];
    if (!bluetoothGranted) missing.add('Bluetooth');
    return missing;
  }

  /// Get list of missing recommended permissions
  List<String> get missingRecommendedPermissions {
    final missing = <String>[];
    if (!bluetoothGranted) missing.add('Bluetooth');
    if (!isNotificationGranted && Platform.isAndroid)
      missing.add('Notifications');
    if (!batteryOptimizationDisabled && Platform.isAndroid) {
      missing.add('Battery Optimization');
    }
    return missing;
  }

  /// Get list of all missing permissions
  List<String> get missingPermissions {
    final missing = <String>[];
    if (!bluetoothGranted) missing.add('Bluetooth');
    if (!isLocationGranted) missing.add('Location');
    if (!isNotificationGranted && Platform.isAndroid)
      missing.add('Notifications');
    if (!notificationListenerEnabled && Platform.isAndroid) {
      missing.add('Notification Access');
    }
    if (!batteryOptimizationDisabled && Platform.isAndroid) {
      missing.add('Battery Optimization');
    }
    return missing;
  }

  AppPermissionsStatus copyWith({
    bool? bluetoothGranted,
    LocationPermission? locationPermission,
    PermissionStatus? notificationPermission,
    bool? notificationListenerEnabled,
    bool? batteryOptimizationDisabled,
  }) {
    return AppPermissionsStatus(
      bluetoothGranted: bluetoothGranted ?? this.bluetoothGranted,
      locationPermission: locationPermission ?? this.locationPermission,
      notificationPermission:
          notificationPermission ?? this.notificationPermission,
      notificationListenerEnabled:
          notificationListenerEnabled ?? this.notificationListenerEnabled,
      batteryOptimizationDisabled:
          batteryOptimizationDisabled ?? this.batteryOptimizationDisabled,
    );
  }

  @override
  String toString() {
    return 'AppPermissionsStatus('
        'bluetooth: $bluetoothGranted, '
        'location: $locationPermission, '
        'notification: $notificationPermission, '
        'notificationListener: $notificationListenerEnabled, '
        'batteryOptDisabled: $batteryOptimizationDisabled)';
  }
}

/// Service for checking and requesting all app permissions
class PermissionService {
  final NotificationService _notificationService;
  final ForegroundService _foregroundService;

  PermissionService({
    NotificationService? notificationService,
    ForegroundService? foregroundService,
  }) : _notificationService = notificationService ?? NotificationService(),
       _foregroundService = foregroundService ?? ForegroundService.instance;

  /// Check all permission statuses
  Future<AppPermissionsStatus> checkAllPermissions() async {
    debugPrint('[PermissionService] Checking all permissions...');

    final results = await Future.wait([
      _checkBluetoothPermission(),
      _checkLocationPermission(),
      _checkNotificationPermission(),
      _checkNotificationListenerPermission(),
      _checkBatteryOptimization(),
    ]);

    final status = AppPermissionsStatus(
      bluetoothGranted: results[0] as bool,
      locationPermission: results[1] as LocationPermission,
      notificationPermission: results[2] as PermissionStatus,
      notificationListenerEnabled: results[3] as bool,
      batteryOptimizationDisabled: results[4] as bool,
    );

    debugPrint('[PermissionService] Permission status: $status');
    return status;
  }

  /// Check Bluetooth permission
  Future<bool> _checkBluetoothPermission() async {
    try {
      if (Platform.isAndroid) {
        // On Android 12+, we need BLUETOOTH_SCAN and BLUETOOTH_CONNECT
        // On older Android, we need BLUETOOTH and location
        final state = await FlutterBluePlus.adapterState.first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => BluetoothAdapterState.unknown,
        );

        if (state == BluetoothAdapterState.unauthorized) {
          return false;
        }

        final scanStatus = await Permission.bluetoothScan.status;
        final connectStatus = await Permission.bluetoothConnect.status;

        if (scanStatus == PermissionStatus.permanentlyDenied ||
            connectStatus == PermissionStatus.permanentlyDenied) {
          return false;
        }

        final bluetoothStatus = await Permission.bluetooth.status;
        return scanStatus.isGranted ||
            connectStatus.isGranted ||
            bluetoothStatus.isGranted;
      } else {
        // iOS — permission_handler's Permission.bluetooth does NOT reliably
        // reflect CoreBluetooth (CBCentralManager) authorization. It often
        // returns "denied" even when BT is authorized. The only reliable
        // source on iOS is FlutterBluePlus.adapterState which wraps
        // CBCentralManager.
        //
        // However, .first returns the last *cached* BehaviorSubject value
        // which can be stale after returning from Settings. To get a fresh
        // value we skip the first (potentially stale) emission and wait for
        // the next one, with a fallback to the immediate value if no update
        // arrives within the timeout.
        final state = await _getIosBluetoothState();
        debugPrint('[PermissionService] iOS BT adapter state: $state');
        return state != BluetoothAdapterState.unauthorized &&
            state != BluetoothAdapterState.unknown;
      }
    } catch (e) {
      debugPrint('[PermissionService] Bluetooth permission check error: $e');
      return false;
    }
  }

  /// Get the current iOS Bluetooth adapter state reliably.
  ///
  /// On iOS, `FlutterBluePlus.adapterState` is backed by a `BehaviorSubject`
  /// whose initial/cached value may be `unknown` (cold start, before
  /// `CBCentralManagerDelegate` fires) or a stale `unauthorized` (after the
  /// user granted permission in Settings and iOS restarted the app).
  ///
  /// Strategy:
  ///  • Subscribe to the stream and collect values for a short window.
  ///  • Return the first value that is NOT `unknown` (i.e. a definitive
  ///    answer from CoreBluetooth).
  ///  • If no definitive answer arrives within the timeout, return the last
  ///    value we saw.
  Future<BluetoothAdapterState> _getIosBluetoothState() async {
    // Listen for a definitive (non-unknown) state from CoreBluetooth.
    // On cold start the stream typically goes unknown → on/off/unauthorized
    // within a few hundred milliseconds.
    try {
      final state = await FlutterBluePlus.adapterState
          .firstWhere((s) => s != BluetoothAdapterState.unknown)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => BluetoothAdapterState.unknown,
          );
      return state;
    } catch (_) {
      return BluetoothAdapterState.unknown;
    }
  }

  /// Check location permission
  Future<LocationPermission> _checkLocationPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('[PermissionService] Location permission check error: $e');
      return LocationPermission.denied;
    }
  }

  /// Check notification permission (POST_NOTIFICATIONS on Android 13+)
  Future<PermissionStatus> _checkNotificationPermission() async {
    if (!Platform.isAndroid) {
      return PermissionStatus.granted;
    }

    try {
      return await Permission.notification.status;
    } catch (e) {
      debugPrint('[PermissionService] Notification permission check error: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check Notification Listener Service access
  Future<bool> _checkNotificationListenerPermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS uses ANCS
    }

    try {
      await _notificationService.initialize();
      return await _notificationService.isNotificationAccessEnabled();
    } catch (e) {
      debugPrint('[PermissionService] Notification listener check error: $e');
      return false;
    }
  }

  /// Check battery optimization status
  Future<bool> _checkBatteryOptimization() async {
    if (!Platform.isAndroid) {
      return true; // iOS doesn't have this
    }

    try {
      return await _foregroundService.isBatteryOptimizationDisabled();
    } catch (e) {
      debugPrint('[PermissionService] Battery optimization check error: $e');
      return false;
    }
  }

  /// Request Bluetooth permissions
  Future<bool> requestBluetoothPermission() async {
    debugPrint('[PermissionService] Requesting Bluetooth permission...');

    try {
      if (Platform.isAndroid) {
        // Request scan and connect permissions
        final results = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetooth,
        ].request();

        final hasBluetooth =
            (results[Permission.bluetoothScan]?.isGranted ?? false) ||
            (results[Permission.bluetooth]?.isGranted ?? false);
        final hasConnect =
            results[Permission.bluetoothConnect]?.isGranted ?? true;

        return hasBluetooth && hasConnect;
      } else {
        // iOS - Bluetooth permission is triggered by CoreBluetooth initialization.
        // Check the current adapter state to decide the best action.
        final state = await FlutterBluePlus.adapterState.first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => BluetoothAdapterState.unknown,
        );

        if (state == BluetoothAdapterState.unauthorized) {
          // Permission was already denied — iOS won't show the dialog again.
          // The only option is to send the user to Settings.
          debugPrint(
            '[PermissionService] iOS BT unauthorized, opening app settings',
          );
          await openAppSettings();
          // openAppSettings() returns immediately — the user is still in
          // Settings at this point. Return false; the PermissionNotifier's
          // lifecycle resume handler will re-check permissions when the user
          // comes back to the app.
          return false;
        }

        // Permission not yet determined or already granted — trigger the
        // system dialog by briefly starting a scan (this initialises
        // CBCentralManager which prompts the user on first access).
        try {
          await FlutterBluePlus.startScan(timeout: const Duration(seconds: 1));
          await FlutterBluePlus.stopScan();
        } catch (_) {
          // Scan may throw if BT is off; that's fine — the permission
          // dialog is still shown independently of scan success.
        }

        // Wait a moment for the permission state to propagate
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final newState = await _getIosBluetoothState();
        return newState != BluetoothAdapterState.unauthorized;
      }
    } catch (e) {
      debugPrint('[PermissionService] Bluetooth permission request error: $e');
      return false;
    }
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    debugPrint('[PermissionService] Requesting Location permission...');

    try {
      final current = await Geolocator.checkPermission();
      if (current == LocationPermission.deniedForever) {
        // Can't request, need to open settings
        return current;
      }

      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('[PermissionService] Location permission request error: $e');
      return LocationPermission.denied;
    }
  }

  /// Request notification permission (POST_NOTIFICATIONS)
  Future<PermissionStatus> requestNotificationPermission() async {
    debugPrint('[PermissionService] Requesting Notification permission...');

    if (!Platform.isAndroid) {
      return PermissionStatus.granted;
    }

    try {
      return await Permission.notification.request();
    } catch (e) {
      debugPrint(
        '[PermissionService] Notification permission request error: $e',
      );
      return PermissionStatus.denied;
    }
  }

  /// Open Notification Listener Service settings
  Future<void> openNotificationListenerSettings() async {
    debugPrint('[PermissionService] Opening notification listener settings...');

    if (Platform.isAndroid) {
      await _notificationService.requestNotificationAccess();
    }
  }

  /// Request battery optimization exemption
  Future<bool> requestBatteryOptimizationExemption() async {
    debugPrint(
      '[PermissionService] Requesting battery optimization exemption...',
    );

    if (Platform.isAndroid) {
      try {
        return await _foregroundService.requestDisableBatteryOptimization();
      } catch (e) {
        debugPrint(
          '[PermissionService] Error requesting battery exemption: $e',
        );
        return false;
      }
    }
    return true;
  }

  /// Open battery optimization settings
  Future<bool> openBatteryOptimizationSettings() async {
    debugPrint('[PermissionService] Opening battery optimization settings...');

    if (Platform.isAndroid) {
      try {
        return await _foregroundService.openBatteryOptimizationSettings();
      } catch (e) {
        debugPrint('[PermissionService] Error opening battery settings: $e');
        return false;
      }
    }
    return true;
  }

  /// Open app settings (for permanently denied permissions)
  Future<void> openAppSettingsPage() async {
    debugPrint('[PermissionService] Opening app settings...');
    await openAppSettings();
  }

  /// Open location settings (if location services are disabled)
  Future<void> openLocationSettings() async {
    debugPrint('[PermissionService] Opening location settings...');
    await Geolocator.openLocationSettings();
  }
}
