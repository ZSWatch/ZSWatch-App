import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/connection.dart';
import '../../../data/models/crash_summary.dart';
import '../../../providers/developer_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../widgets/developer/music_debug_section.dart';
import '../../widgets/developer/notification_debug_section.dart';

class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(bleDiagnosticsProvider);
    final connection = ref.watch(watchConnectionProvider);
    final crashSummary = ref.watch(crashSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools')),
      body: _DeveloperToolsBody(
        diagnostics: diagnostics,
        connection: connection,
        crashSummary: crashSummary,
      ),
    );
  }
}

class _DeveloperToolsBody extends ConsumerWidget {
  final BleDiagnostics diagnostics;
  final Connection connection;
  final CrashSummary? crashSummary;

  const _DeveloperToolsBody({
    required this.diagnostics,
    required this.connection,
    this.crashSummary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolTiles = [
      _BlendToolTile(
        icon: Icons.article_outlined,
        title: 'Log Viewer',
        subtitle: 'Firmware logs',
        accent: AppTheme.primaryColor,
        onTap: () => context.push(AppRoutes.logViewer),
      ),
      _BlendToolTile(
        icon: Icons.swap_horiz,
        title: 'Comm Log',
        subtitle: 'BLE traffic',
        accent: Colors.amberAccent.shade400,
        onTap: () => context.push(AppRoutes.commLog),
      ),
      _BlendToolTile(
        icon: Icons.terminal,
        title: 'Shell',
        subtitle: 'SMP commands',
        accent: Colors.lightGreenAccent.shade400,
        onTap: connection.isConnected
            ? () => context.push(AppRoutes.shell)
            : null,
      ),
      _BlendToolTile(
        icon: Icons.bug_report_outlined,
        title: 'Crash Reports',
        subtitle: 'History & stats',
        accent: Colors.redAccent.shade200,
        onTap: () => context.push(AppRoutes.crashReport),
      ),
      _BlendToolTile(
        icon: Icons.sensors,
        title: 'Sensors',
        subtitle: 'Real-time data',
        accent: Colors.tealAccent.shade400,
        onTap: connection.isConnected
            ? () => context.push(AppRoutes.sensors)
            : null,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        _DiagnosticsCard(diagnostics: diagnostics),
        const SizedBox(height: AppTheme.spacingMd),
        if (!connection.isConnected) ...[
          _DisconnectedBanner(),
          const SizedBox(height: AppTheme.spacingMd),
        ],
        const _BlendTerminalSectionTitle('TOOLS'),
        const SizedBox(height: AppTheme.spacingSm),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
          children: toolTiles,
        ),
        const SizedBox(height: AppTheme.spacingLg),
        const _BlendTerminalSectionTitle('ACTIONS'),
        const SizedBox(height: AppTheme.spacingSm),
        Row(
          children: [
            Expanded(
              child: _BlendActionChip(
                icon: Icons.vibration,
                label: 'Find',
                onTap: connection.isConnected
                    ? () async {
                        final watchService = ref.read(watchServiceProvider);
                        await watchService.findDevice(true);
                        await Future<void>.delayed(const Duration(seconds: 2));
                        await watchService.findDevice(false);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BlendActionChip(
                icon: Icons.sync,
                label: 'Sync Time',
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
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BlendActionChip(
                icon: Icons.info_outline,
                label: 'Device Info',
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
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingLg),
        const _BlendTerminalSectionTitle('DEBUG'),
        const SizedBox(height: AppTheme.spacingSm),
        const _CompactDebugToolsHub(),
      ],
    );
  }
}

class _BlendTerminalSectionTitle extends StatelessWidget {
  final String label;

  const _BlendTerminalSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      '< $label',
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppTheme.primaryColor,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
      ),
    );
  }
}

class _BlendToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  const _BlendToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 22, color: accent),
                    ),
                    const Spacer(),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlendActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _BlendActionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: enabled
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            color: Colors.white.withValues(alpha: 0.02),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDebugToolsHub extends StatelessWidget {
  const _CompactDebugToolsHub();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tune,
                size: 18,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Debug Tools',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showDebugToolsSheet(context),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDebugToolsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: DefaultTabController(
              length: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Tools',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.textSecondary,
                        tabs: const [
                          Tab(text: 'Notifications'),
                          Tab(text: 'Music'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Expanded(
                      child: TabBarView(
                        children: [
                          _DebugToolSheetPage(
                            child: NotificationDebugSection(),
                          ),
                          _DebugToolSheetPage(child: MusicDebugSection()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DebugToolSheetPage extends StatelessWidget {
  final Widget child;

  const _DebugToolSheetPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      child: SingleChildScrollView(child: child),
    );
  }
}

class _DisconnectedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.warningColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            const Icon(
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
              value:
                  '${diagnostics.rssiDisplay} (${diagnostics.signalStrength})',
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
