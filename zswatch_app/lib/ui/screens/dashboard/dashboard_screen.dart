import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/watch.dart';
import '../../../providers/auto_reconnect_provider.dart';
import '../../../providers/watch_service_provider.dart';
import '../../widgets/battery_ring.dart';

/// Dashboard screen showing connected watch information
///
/// Displays:
/// - Watch name and connection status
/// - Battery level with visual indicator
/// - Firmware version
/// - Quick actions (disconnect, settings, etc.)
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(currentWatchProvider);
    final connection = ref.watch(watchConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(watch?.displayName ?? 'ZSWatch'),
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

                  // Battery and info row
                  Row(
                    children: [
                      // Battery card
                      Expanded(
                        child: _InfoCard(
                          title: 'Battery',
                          child: BatteryRing(
                            level: watch?.batteryLevel ?? 0,
                            size: 80,
                            strokeWidth: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      // Firmware card
                      Expanded(
                        child: _InfoCard(
                          title: 'Firmware',
                          child: Column(
                            children: [
                              Icon(
                                Icons.memory,
                                size: 40,
                                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                watch?.shortFirmwareVersion ?? 'Unknown',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                      ref.read(autoReconnectNotifierProvider.notifier).suppressForSession();
                      final notifier = ref.read(watchNotifierProvider.notifier);
                      await notifier.disconnect();
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
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

  const _ConnectionStatusCard({
    required this.isConnected,
    this.rssi,
    this.mtu,
  });

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
                color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
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

  const _InfoCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            child,
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
            _InfoRow(label: 'Name', value: watch?.name ?? 'Unknown'),
            _InfoRow(label: 'Device ID', value: watch?.id ?? 'Unknown'),
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

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onFirmwareUpdate;
  final VoidCallback onDisconnect;

  const _QuickActionsSection({
    required this.onFirmwareUpdate,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        Text(
          'Features',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
              Icon(
                icon,
                size: 32,
                color: AppTheme.primaryColor,
              ),
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

