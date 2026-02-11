import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/watch.dart';
import '../../../providers/auto_reconnect_provider.dart';
import '../../../providers/health_providers.dart';
import '../../../providers/watch_service_provider.dart';

/// Dashboard screen showing connected watch information
///
/// Displays:
/// - Watch name and connection status
/// - Battery level with visual indicator
/// - Firmware version
/// - Quick actions (disconnect, settings, etc.)

Future<void> _restartWatch(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restart Watch'),
      content: const Text('Are you sure you want to restart the watch?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Restart'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final connection = ref.read(watchConnectionProvider);
  final deviceId = connection.watchId;
  if (deviceId.isEmpty) return;

  try {
    await OsManager.reset(deviceId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restart command sent to watch')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restart watch: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(currentWatchProvider);
    final connection = ref.watch(watchConnectionProvider);
    final healthSummary = ref.watch(healthSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset('assets/images/ZSWatch_Text.svg', height: 24),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status card
            _ConnectionStatusCard(
              isConnected: connection.isConnected,
              rssi: connection.rssi,
              mtu: connection.mtu,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Stats row - 4 compact cards
            _StatsRow(
              batteryLevel: watch?.batteryLevel,
              firmwareVersion: watch?.shortFirmwareVersion,
              todaySteps: healthSummary.todaySteps,
              latestHeartRate: healthSummary.latestHeartRate,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Device info card
            _DeviceInfoCard(watch: watch),

            const SizedBox(height: AppTheme.spacingLg),

            // Quick actions
            _QuickActionsSection(
              onFirmwareUpdate: () => context.push('/firmware'),
              onDisconnect: () async {
                // Suppress auto-reconnect when user manually disconnects
                ref
                    .read(autoReconnectNotifierProvider.notifier)
                    .suppressForSession();
                final notifier = ref.read(watchNotifierProvider.notifier);
                await notifier.disconnect();
                if (context.mounted) {
                  context.go('/');
                }
              },
              onRestartWatch: ref.watch(hasSmpServiceProvider)
                  ? () => _restartWatch(context, ref)
                  : null,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Feature shortcuts
            _FeatureShortcuts(),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  final bool isConnected;
  final int? rssi;
  final int? mtu;

  const _ConnectionStatusCard({required this.isConnected, this.rssi, this.mtu});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                boxShadow: isConnected
                    ? [
                        BoxShadow(
                          color: AppTheme.successColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isConnected
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                  ),
                  if (isConnected && (rssi != null || mtu != null))
                    Text(
                      [
                        if (rssi != null) '$rssi dBm',
                        if (mtu != null) 'MTU: $mtu',
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (isConnected)
              const Icon(
                Icons.bluetooth_connected,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            child,
          ],
        ),
      ),
    );
  }
}

/// Compact stats row with 4 mini cards
class _StatsRow extends StatelessWidget {
  final int? batteryLevel;
  final String? firmwareVersion;
  final int todaySteps;
  final int? latestHeartRate;

  const _StatsRow({
    this.batteryLevel,
    this.firmwareVersion,
    this.todaySteps = 0,
    this.latestHeartRate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.memory,
            label: 'Firmware',
            value: firmwareVersion ?? '--',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: _StatCard(
            icon: Icons.battery_std,
            label: 'Battery',
            value: batteryLevel != null ? '$batteryLevel%' : '--',
            color: batteryLevel != null
                ? AppTheme.getBatteryColor(batteryLevel!)
                : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: _StatCard(
            icon: Icons.directions_walk,
            label: 'Steps',
            value: _formatSteps(todaySteps),
            color: AppTheme.secondaryColor,
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite,
            label: 'Heart Rate',
            value: latestHeartRate != null ? '$latestHeartRate' : '--',
            color: AppTheme.errorColor,
          ),
        ),
      ],
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '$steps';
  }
}

/// Compact stat card for the stats row
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final Watch? watch;

  const _DeviceInfoCard({this.watch});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _InfoRow(label: 'Name', value: watch?.displayName ?? 'Unknown'),
            _InfoRow(
              label: 'Bluetooth MAC',
              value: watch?.id != null
                  ? _truncateDeviceId(watch!.id)
                  : 'Unknown',
            ),
            _InfoRow(
              label: 'Hardware',
              value: watch?.hardwareVersion ?? 'Unknown',
            ),
            _InfoRow(
              label: 'Last Connected',
              value: watch?.lastConnectedAt != null
                  ? _formatDateTime(watch!.lastConnectedAt!)
                  : 'Never',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Truncate device ID for display (iOS UUIDs are very long)
  String _truncateDeviceId(String id) {
    // On iOS, device IDs are UUIDs like "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
    // On Android, they're MAC addresses like "XX:XX:XX:XX:XX:XX"
    // Truncate to max 20 characters and add ellipsis if longer
    if (id.length <= 20) return id;
    return '${id.substring(0, 17)}...';
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onFirmwareUpdate;
  final VoidCallback onDisconnect;
  final VoidCallback? onRestartWatch;

  const _QuickActionsSection({
    required this.onFirmwareUpdate,
    required this.onDisconnect,
    this.onRestartWatch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingSm),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onFirmwareUpdate,
                  icon: const Icon(Icons.system_update, size: 18),
                  label: const Text('Update Firmware'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onDisconnect,
                  icon: const Icon(Icons.bluetooth_disabled, size: 18),
                  label: const Text('Disconnect'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (onRestartWatch != null) ...[
          const SizedBox(height: AppTheme.spacingSm),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onRestartWatch,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restart Watch'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeatureShortcuts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Features', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spacingSm),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppTheme.spacingSm,
          crossAxisSpacing: AppTheme.spacingSm,
          children: [
            _FeatureTile(
              icon: Icons.favorite,
              label: 'Health',
              onTap: () => context.push('/health'),
            ),
            _FeatureTile(
              icon: Icons.notifications,
              label: 'Notifications',
              onTap: () => context.push('/notifications'),
            ),
            _FeatureTile(
              icon: Icons.analytics,
              label: 'Analytics',
              onTap: () => context.push('/analytics'),
            ),
            _FeatureTile(
              icon: Icons.code,
              label: 'Developer',
              onTap: () => context.push('/developer'),
            ),
            _FeatureTile(
              icon: Icons.mic,
              label: 'Voice',
              onTap: () => context.push('/voice-memos'),
            ),
            _FeatureTile(
              icon: Icons.settings,
              label: 'Settings',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingSm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: AppTheme.primaryColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
