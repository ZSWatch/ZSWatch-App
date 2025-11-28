import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/developer_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../widgets/developer/music_debug_section.dart';
import '../../widgets/developer/notification_debug_section.dart';

/// Developer tools hub screen
///
/// Provides access to:
/// - BLE diagnostics (MTU, PHY, RSSI, reconnection count)
/// - Log viewer (all incoming BLE NUS data)
/// - Sensor debug (real-time sensor charts)
/// - Communication log (TX/RX traffic)
/// - Shell terminal (not implemented - mcumgr doesn't support it)
class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(bleDiagnosticsProvider);
    final connection = ref.watch(watchConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          // BLE Diagnostics Card
          _DiagnosticsCard(diagnostics: diagnostics),

          const SizedBox(height: AppTheme.spacingMd),

          // Connection status
          if (!connection.isConnected)
            Card(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        'Watch not connected. Some features require an active connection.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: AppTheme.spacingMd),

          // Developer tools grid
          Text(
            'Tools',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTheme.spacingSm),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppTheme.spacingSm,
            crossAxisSpacing: AppTheme.spacingSm,
            childAspectRatio: 1.3,
            children: [
              _ToolCard(
                icon: Icons.article_outlined,
                title: 'Log Viewer',
                subtitle: 'All BLE data',
                onTap: () => context.push('/developer/logs'),
              ),
              _ToolCard(
                icon: Icons.sensors,
                title: 'Sensors',
                subtitle: 'Real-time data',
                onTap: () => context.push('/developer/sensors'),
                enabled: connection.isConnected,
              ),
              _ToolCard(
                icon: Icons.swap_horiz,
                title: 'Comm Log',
                subtitle: 'TX/RX traffic',
                onTap: () => context.push('/developer/comm-log'),
              ),
              _ToolCard(
                icon: Icons.terminal,
                title: 'Shell',
                subtitle: 'Not available',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Shell commands not supported by mcumgr library'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                enabled: false,
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingLg),

          // Quick actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTheme.spacingSm),

          _QuickActionTile(
            icon: Icons.vibration,
            title: 'Find Watch',
            subtitle: 'Vibrate the watch',
            onTap: connection.isConnected
                ? () async {
                    final watchService = ref.read(watchServiceProvider);
                    await watchService.findDevice(true);
                    await Future<void>.delayed(const Duration(seconds: 2));
                    await watchService.findDevice(false);
                  }
                : null,
          ),

          const SizedBox(height: AppTheme.spacingXs),

          _QuickActionTile(
            icon: Icons.sync,
            title: 'Sync Time',
            subtitle: 'Update watch time',
            onTap: connection.isConnected
                ? () async {
                    final watchService = ref.read(watchServiceProvider);
                    await watchService.syncTime();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Time synced'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  }
                : null,
          ),

          const SizedBox(height: AppTheme.spacingXs),

          _QuickActionTile(
            icon: Icons.info_outline,
            title: 'Request Device Info',
            subtitle: 'Query firmware version',
            onTap: connection.isConnected
                ? () async {
                    final watchService = ref.read(watchServiceProvider);
                    await watchService.requestDeviceInfo();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Device info requested'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  }
                : null,
          ),

          const SizedBox(height: AppTheme.spacingLg),

          // Debug Tools Section (collapsible)
          const _DebugToolsSection(),
        ],
      ),
    );
  }
}

class _DiagnosticsCard extends ConsumerWidget {
  final BleDiagnostics diagnostics;

  const _DiagnosticsCard({required this.diagnostics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(currentWatchProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: diagnostics.isConnected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Device Diagnostics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: diagnostics.isConnected
                        ? AppTheme.successColor.withValues(alpha: 0.2)
                        : AppTheme.errorColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    diagnostics.isConnected ? 'Connected' : 'Disconnected',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: diagnostics.isConnected
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                  ),
                ),
              ],
            ),
            const Divider(),
            _DiagnosticRow(
              label: 'Firmware',
              value: watch?.firmwareVersion ?? '-',
              icon: Icons.memory,
            ),
            _DiagnosticRow(
              label: 'Hardware',
              value: watch?.hardwareVersion ?? '-',
              icon: Icons.developer_board,
            ),
            _DiagnosticRow(
              label: 'MTU',
              value: diagnostics.mtuDisplay,
              icon: Icons.swap_vert,
            ),
            _DiagnosticRow(
              label: 'RSSI',
              value: '${diagnostics.rssiDisplay} (${diagnostics.signalStrength})',
              icon: Icons.signal_cellular_alt,
            ),
            _DiagnosticRow(
              label: 'Connected',
              value: diagnostics.connectionDurationDisplay,
              icon: Icons.timer_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DiagnosticRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onTap != null;

    return Card(
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isEnabled ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: 0,
        ),
        leading: Icon(
          icon,
          size: 20,
          color: onTap != null ? AppTheme.primaryColor : AppTheme.textSecondary,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: AppTheme.textSecondary,
        ),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}

/// Collapsible debug tools section
class _DebugToolsSection extends StatefulWidget {
  const _DebugToolsSection();

  @override
  State<_DebugToolsSection> createState() => _DebugToolsSectionState();
}

class _DebugToolsSectionState extends State<_DebugToolsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
        leading: Icon(
          Icons.bug_report,
          color: AppTheme.primaryColor,
        ),
        title: const Text('Debug Tools'),
        subtitle: Text(
          'Notification & Music testing',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spacingMd,
              0,
              AppTheme.spacingMd,
              AppTheme.spacingMd,
            ),
            child: Column(
              children: [
                NotificationDebugSection(),
                SizedBox(height: AppTheme.spacingMd),
                MusicDebugSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
