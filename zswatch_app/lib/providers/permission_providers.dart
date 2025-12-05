import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/background/foreground_service.dart';
import '../services/permission/permission_service.dart';
import 'notification_providers.dart';

/// Key for storing whether onboarding has been completed
const _onboardingCompletedKey = 'permission_onboarding_completed';

/// Provider for the permission service
final permissionServiceProvider = Provider<PermissionService>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final foregroundService = ForegroundService.instance;
  return PermissionService(
    notificationService: notificationService,
    foregroundService: foregroundService,
  );
});

/// Provider for all permission statuses
/// 
/// This provider checks all permissions and returns the combined status.
/// Use ref.invalidate() to refresh after requesting permissions.
final permissionsStatusProvider = FutureProvider<AppPermissionsStatus>((ref) async {
  final service = ref.watch(permissionServiceProvider);
  return service.checkAllPermissions();
});

/// Provider for whether permission onboarding has been completed
final permissionOnboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompletedKey) ?? false;
});

/// State for the permission notifier
class PermissionState {
  final AppPermissionsStatus status;
  final bool isChecking;
  final bool onboardingCompleted;

  const PermissionState({
    this.status = const AppPermissionsStatus(),
    this.isChecking = false,
    this.onboardingCompleted = false,
  });

  PermissionState copyWith({
    AppPermissionsStatus? status,
    bool? isChecking,
    bool? onboardingCompleted,
  }) {
    return PermissionState(
      status: status ?? this.status,
      isChecking: isChecking ?? this.isChecking,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  /// Whether the app should show the permission onboarding screen
  bool get shouldShowOnboarding {
    // Show onboarding if not completed yet
    return !onboardingCompleted;
  }
}

/// Notifier that manages permission state and lifecycle
/// 
/// This notifier:
/// - Checks permissions on app startup
/// - Re-checks permissions when app resumes from background
/// - Provides methods to request individual permissions
/// - Tracks onboarding completion state
class PermissionNotifier extends StateNotifier<PermissionState> with WidgetsBindingObserver {
  final PermissionService _service;
  Timer? _debounceTimer;

  PermissionNotifier(this._service) : super(const PermissionState()) {
    _initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _initialize() async {
    await _checkAllPermissions();
    await _loadOnboardingState();
  }

  Future<void> _checkAllPermissions() async {
    state = state.copyWith(isChecking: true);
    try {
      final status = await _service.checkAllPermissions();
      state = state.copyWith(status: status, isChecking: false);
    } catch (e) {
      debugPrint('[PermissionNotifier] Error checking permissions: $e');
      state = state.copyWith(isChecking: false);
    }
  }

  Future<void> _loadOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_onboardingCompletedKey) ?? false;
    state = state.copyWith(onboardingCompleted: completed);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Re-check permissions when app resumes from background
    // User may have changed permissions in system settings
    if (state == AppLifecycleState.resumed) {
      debugPrint('[PermissionNotifier] App resumed, re-checking permissions...');
      // Debounce to avoid multiple rapid checks
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkAllPermissions();
      });
    }
  }

  /// Refresh all permission statuses
  Future<void> refreshPermissions() async {
    await _checkAllPermissions();
  }

  /// Request Bluetooth permission
  Future<bool> requestBluetoothPermission() async {
    final result = await _service.requestBluetoothPermission();
    await _checkAllPermissions();
    return result;
  }

  /// Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    final result = await _service.requestLocationPermission();
    await _checkAllPermissions();
    return result;
  }

  /// Request notification permission (POST_NOTIFICATIONS)
  Future<PermissionStatus> requestNotificationPermission() async {
    final result = await _service.requestNotificationPermission();
    await _checkAllPermissions();
    return result;
  }

  /// Open Notification Listener Service settings
  Future<void> openNotificationListenerSettings() async {
    await _service.openNotificationListenerSettings();
    // Check after a delay to allow user to change settings
  }

  /// Request battery optimization exemption
  Future<void> requestBatteryOptimizationExemption() async {
    debugPrint('[PermissionNotifier] requestBatteryOptimizationExemption called');
    final result = await _service.requestBatteryOptimizationExemption();
    debugPrint('[PermissionNotifier] requestBatteryOptimizationExemption result: $result');
    // Re-check after a delay
    await Future<void>.delayed(const Duration(seconds: 1));
    await _checkAllPermissions();
  }

  /// Open battery optimization settings
  Future<void> openBatteryOptimizationSettings() async {
    await _service.openBatteryOptimizationSettings();
  }

  /// Open app settings (for permanently denied permissions)
  Future<void> openAppSettingsPage() async {
    await _service.openAppSettingsPage();
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await _service.openLocationSettings();
  }

  /// Mark permission onboarding as completed
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    state = state.copyWith(onboardingCompleted: true);
  }

  /// Reset onboarding state (for testing or re-requesting permissions)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, false);
    state = state.copyWith(onboardingCompleted: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for the permission notifier
final permissionNotifierProvider =
    StateNotifierProvider<PermissionNotifier, PermissionState>((ref) {
  final service = ref.watch(permissionServiceProvider);
  return PermissionNotifier(service);
});

/// Provider for checking if Bluetooth permission is granted
final isBluetoothPermissionGrantedProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionNotifierProvider);
  return state.status.bluetoothGranted;
});

/// Provider for checking if location permission is granted
final isLocationPermissionGrantedProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionNotifierProvider);
  return state.status.isLocationGranted;
});

/// Provider for checking if notification permission is granted
final isNotificationPermissionGrantedProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionNotifierProvider);
  return state.status.isNotificationGranted;
});

/// Provider for checking if notification listener is enabled
final isNotificationListenerEnabledProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionNotifierProvider);
  return state.status.notificationListenerEnabled;
});

/// Provider for checking if battery optimization is disabled
final isBatteryOptimizationDisabledProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionNotifierProvider);
  return state.status.batteryOptimizationDisabled;
});

/// Provider for whether we should show permission onboarding
final shouldShowPermissionOnboardingProvider = Provider<bool>((ref) {
  final state = ref.watch(permissionNotifierProvider);
  // Only show onboarding if not completed and missing critical permissions
  return !state.onboardingCompleted && !state.status.hasCriticalPermissions;
});

/// Provider for missing permission count (for badges/indicators)
final missingPermissionsCountProvider = Provider<int>((ref) {
  final state = ref.watch(permissionNotifierProvider);
  return state.status.missingPermissions.length;
});
