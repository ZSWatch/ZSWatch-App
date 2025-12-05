import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/permission_providers.dart';

/// Screen for requesting all permissions on first launch
/// 
/// This screen guides the user through granting all necessary permissions
/// with clear explanations for each one. It's shown when:
/// - First launch of the app
/// - Critical permissions are missing
/// - User navigates here from Settings
class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  /// Whether this is shown as part of initial onboarding (vs settings access)
  final bool isInitialOnboarding;
  
  /// Callback when onboarding is completed
  final VoidCallback? onComplete;

  const PermissionOnboardingScreen({
    super.key,
    this.isInitialOnboarding = true,
    this.onComplete,
  });

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen> {
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    final permissionState = ref.watch(permissionNotifierProvider);
    final status = permissionState.status;

    return Scaffold(
      appBar: widget.isInitialOnboarding
          ? null
          : AppBar(
              title: const Text('Permissions'),
            ),
      body: SafeArea(
        child: _isRequesting
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isInitialOnboarding) ...[
                      const SizedBox(height: AppTheme.spacingXl),
                      Text(
                        'Welcome to ZSWatch',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'To get the best experience, please grant the following permissions.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingXl),
                    ],

                    // Critical Permissions Section
                    _SectionHeader(
                      title: 'Required Permissions',
                      icon: Icons.warning_amber_rounded,
                      color: AppTheme.errorColor,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    
                    // Bluetooth Permission
                    _PermissionCard(
                      icon: Icons.bluetooth,
                      title: 'Bluetooth',
                      description:
                          'Required to communicate with your ZSWatch. Without this permission, the app cannot function.',
                      isGranted: status.bluetoothGranted,
                      isCritical: true,
                      onRequest: _requestBluetoothPermission,
                    ),

                    const SizedBox(height: AppTheme.spacingLg),

                    // Recommended Permissions Section
                    _SectionHeader(
                      title: 'Recommended Permissions',
                      icon: Icons.recommend_outlined,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),

                    // Notification Permission (Android 13+)
                    if (Platform.isAndroid) ...[
                      _PermissionCard(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        description:
                            'Allows the app to show a persistent notification when connected in the background, indicating connection status.',
                        isGranted: status.isNotificationGranted,
                        onRequest: _requestNotificationPermission,
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],

                    // Battery Optimization (Android only)
                    if (Platform.isAndroid) ...[
                      _PermissionCard(
                        icon: Icons.battery_full,
                        title: 'Battery Optimization',
                        description:
                            'Disable battery optimization for reliable background connection. Without this, Android may kill the app when in the background.',
                        isGranted: status.batteryOptimizationDisabled,
                        buttonText: status.batteryOptimizationDisabled
                            ? 'Disabled'
                            : 'Configure',
                        onRequest: _requestBatteryOptimization,
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],

                    const SizedBox(height: AppTheme.spacingLg),

                    // Optional Permissions Section
                    _SectionHeader(
                      title: 'Optional Permissions',
                      icon: Icons.add_circle_outline,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),

                    // Location Permission
                    _PermissionCard(
                      icon: Icons.location_on,
                      title: 'Location',
                      description:
                          'Enables the watch to request GPS location from your phone for weather forecasts and fitness tracking.',
                      isGranted: status.isLocationGranted,
                      statusText: _getLocationStatusText(status.locationPermission),
                      onRequest: _requestLocationPermission,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Notification Listener Service (Android only)
                    if (Platform.isAndroid) ...[
                      _PermissionCard(
                        icon: Icons.notifications_active,
                        title: 'Notification Access',
                        description:
                            'Allows the app to forward phone notifications to your watch. Requires enabling in Android Settings.',
                        isGranted: status.notificationListenerEnabled,
                        buttonText: status.notificationListenerEnabled
                            ? 'Enabled'
                            : 'Open Settings',
                        onRequest: _openNotificationListenerSettings,
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],

                    const SizedBox(height: AppTheme.spacingXl),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: status.hasCriticalPermissions
                            ? _completeOnboarding
                            : null,
                        child: Text(
                          widget.isInitialOnboarding ? 'Continue' : 'Done',
                        ),
                      ),
                    ),

                    if (!status.hasCriticalPermissions) ...[
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'Please grant the required Bluetooth permission to continue.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.errorColor,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: AppTheme.spacingLg),
                  ],
                ),
              ),
      ),
    );
  }

  String _getLocationStatusText(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return 'Always allowed';
      case LocationPermission.whileInUse:
        return 'While using app';
      case LocationPermission.denied:
        return 'Not allowed';
      case LocationPermission.deniedForever:
        return 'Denied - tap to open settings';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine';
    }
  }

  Future<void> _requestBluetoothPermission() async {
    setState(() => _isRequesting = true);
    try {
      await ref.read(permissionNotifierProvider.notifier).requestBluetoothPermission();
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _isRequesting = true);
    try {
      await ref.read(permissionNotifierProvider.notifier).requestNotificationPermission();
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = ref.read(permissionNotifierProvider).status;
    
    if (status.locationPermission == LocationPermission.deniedForever) {
      // Need to open settings
      await openAppSettings();
      return;
    }
    
    setState(() => _isRequesting = true);
    try {
      await ref.read(permissionNotifierProvider.notifier).requestLocationPermission();
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _requestBatteryOptimization() async {
    debugPrint('[PermissionOnboarding] _requestBatteryOptimization called');
    try {
      // Use openBatteryOptimizationSettings instead of requestExemption
      // because some OEMs (OnePlus, Xiaomi, etc.) block the direct request dialog
      await ref.read(permissionNotifierProvider.notifier).openBatteryOptimizationSettings();
      debugPrint('[PermissionOnboarding] openBatteryOptimizationSettings completed');
    } catch (e) {
      debugPrint('[PermissionOnboarding] Error opening battery optimization settings: $e');
    }
  }

  Future<void> _openNotificationListenerSettings() async {
    await ref.read(permissionNotifierProvider.notifier).openNotificationListenerSettings();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(permissionNotifierProvider.notifier).completeOnboarding();
    widget.onComplete?.call();
  }
}

/// Section header with icon
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppTheme.spacingSm),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

/// Card for displaying and requesting a permission
class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final bool isCritical;
  final String? statusText;
  final String? buttonText;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    this.isCritical = false,
    this.statusText,
    this.buttonText,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isGranted
        ? AppTheme.successColor
        : (isCritical ? AppTheme.errorColor : AppTheme.warningColor);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted
              ? AppTheme.successColor.withValues(alpha: 0.3)
              : (isCritical
                  ? AppTheme.errorColor.withValues(alpha: 0.3)
                  : Colors.transparent),
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: statusColor, size: 24),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isGranted ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText ?? (isGranted ? 'Granted' : 'Not granted'),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: statusColor,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isGranted || buttonText != null)
                TextButton(
                  onPressed: () {
                    debugPrint('[PermissionCard] Button pressed for: $title');
                    onRequest();
                  },
                  child: Text(buttonText ?? 'Grant'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
