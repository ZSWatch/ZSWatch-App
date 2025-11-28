import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/gps_providers.dart';
import '../../../providers/settings_providers.dart';

/// Settings screen for app configuration
///
/// Displays:
/// - DFU settings (keep screen on)
/// - About section (app version, links)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // TODO: Update these URLs to point to the correct repositories
  static const String _appGithubUrl = 'https://github.com/ZSWatch/ZSWatch';  // <-- Change to app repo
  static const String _firmwareGithubUrl = 'https://github.com/ZSWatch/ZSWatch';  // <-- Change to firmware repo
  static const String _appVersion = '1.0.0';
  static const String _buildNumber = '1';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Firmware Update Settings
          _SectionHeader(title: 'Firmware Update'),
          _SettingsTile(
            leading: const Icon(Icons.screen_lock_portrait, color: AppTheme.textSecondary),
            title: 'Keep Screen On During DFU',
            subtitle: 'Prevent screen timeout during firmware updates',
            trailing: Switch(
              value: ref.watch(keepScreenOnDuringDfuProvider),
              onChanged: (value) {
                ref.read(keepScreenOnDuringDfuProvider.notifier).setEnabled(value);
              },
            ),
          ),

          const Divider(height: 32),

          // GPS / Location Settings
          _SectionHeader(title: 'Location'),
          _GpsPermissionTile(),

          const Divider(height: 32),

          // About Section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            leading: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
            title: 'App Version',
            subtitle: '$_appVersion ($_buildNumber)',
            onTap: () => _showVersionDialog(context),
          ),
          _SettingsTile(
            leading: const Icon(Icons.phone_android, color: AppTheme.textSecondary),
            title: 'Companion App Source',
            subtitle: 'View app source code on GitHub',
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => _launchUrl(_appGithubUrl),
          ),
          _SettingsTile(
            leading: SvgPicture.asset(
              'assets/images/ZSWatch_Logo.svg',
              width: 24,
              height: 24,
            ),
            title: 'ZSWatch Firmware',
            subtitle: 'Open-source smartwatch firmware',
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => _launchUrl(_firmwareGithubUrl),
          ),
          _SettingsTile(
            leading: const Icon(Icons.description_outlined, color: AppTheme.textSecondary),
            title: 'Licenses',
            subtitle: 'Open source licenses',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLicensesPage(context),
          ),

          const SizedBox(height: 32),

          // App description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/images/ZSWatch_Logo.svg',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'ZSWatch Companion',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Companion app for the open-source ZSWatch smartwatch',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showVersionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Version', value: _appVersion),
            _InfoRow(label: 'Build', value: _buildNumber),
            const _InfoRow(label: 'Platform', value: 'Flutter'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLicensesPage(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'ZSWatch Companion',
      applicationVersion: '$_appVersion ($_buildNumber)',
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SvgPicture.asset(
          'assets/images/ZSWatch_Logo.svg',
          width: 48,
          height: 48,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingSm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Provider for GPS permission status
final _gpsPermissionProvider = FutureProvider<LocationPermission>((ref) async {
  return Geolocator.checkPermission();
});

/// GPS permission settings tile
class _GpsPermissionTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(_gpsPermissionProvider);

    return permissionAsync.when(
      data: (permission) {
        final isGranted = permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;
        final statusText = _getPermissionStatusText(permission);
        final statusColor = isGranted ? AppTheme.successColor : AppTheme.warningColor;

        return _SettingsTile(
          leading: Icon(
            isGranted ? Icons.location_on : Icons.location_off,
            color: statusColor,
          ),
          title: 'Watch GPS Requests',
          subtitle: statusText,
          trailing: TextButton(
            onPressed: () async {
              if (permission == LocationPermission.deniedForever) {
                // Open app settings
                await ref.read(gpsNotifierProvider.notifier).openAppSettings();
              } else if (!isGranted) {
                // Request permission
                await Geolocator.requestPermission();
              } else {
                // Already granted - open settings to revoke if desired
                await ref.read(gpsNotifierProvider.notifier).openAppSettings();
              }
              // Refresh permission status
              ref.invalidate(_gpsPermissionProvider);
            },
            child: Text(isGranted ? 'Settings' : 'Enable'),
          ),
          onTap: () => _showGpsInfoDialog(context, permission),
        );
      },
      loading: () => _SettingsTile(
        leading: const Icon(Icons.location_searching, color: AppTheme.textSecondary),
        title: 'Watch GPS Requests',
        subtitle: 'Checking permission...',
      ),
      error: (_, __) => _SettingsTile(
        leading: const Icon(Icons.location_off, color: AppTheme.errorColor),
        title: 'Watch GPS Requests',
        subtitle: 'Unable to check permission',
      ),
    );
  }

  String _getPermissionStatusText(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return 'Allowed (always)';
      case LocationPermission.whileInUse:
        return 'Allowed (while using app)';
      case LocationPermission.denied:
        return 'Not allowed - tap to enable';
      case LocationPermission.deniedForever:
        return 'Denied - tap to open settings';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine';
    }
  }

  void _showGpsInfoDialog(BuildContext context, LocationPermission permission) {
    final isGranted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Watch GPS Requests'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When enabled, your watch can request GPS location from your phone '
              'for features like weather (location-based forecasts) and fitness tracking.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isGranted ? Icons.check_circle : Icons.cancel,
                  color: isGranted ? AppTheme.successColor : AppTheme.warningColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ${_getPermissionStatusText(permission)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (!isGranted) ...[
              const SizedBox(height: 16),
              Text(
                'To enable, tap "Enable" or go to your phone\'s Settings > Apps > ZSWatch > Permissions > Location.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
