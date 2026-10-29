import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';

import 'companion_start_view.dart';

/// Start page showing stored watches and option to add new watch (FR-067 to FR-070)
///
/// This is the entry point of the app, displaying:
/// - List of previously paired watches with connection status
/// - Option to connect to a stored watch (tap to connect)
/// - Option to add a new watch (scan screen)
/// - Auto-reconnect status indicator when active
class StartPageScreen extends StatelessWidget {
  const StartPageScreen({super.key});
  @override
  Widget build(BuildContext context) => const CompanionStartView();
}

/// Individual watch list tile (FR-067, FR-068, T116)
class SavedWatchListTile extends StatelessWidget {
  final WatchEntity watch;
  final bool isConnecting;
  final VoidCallback onTap;
  final VoidCallback onConfig;
  final bool enabled;

  const SavedWatchListTile({
    super.key,
    required this.watch,
    required this.isConnecting,
    required this.onTap,
    required this.onConfig,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = watch.customName ?? watch.name;

    return ListTile(
      leading: _buildLeadingIcon(),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (watch.isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Primary',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      subtitle: _buildSubtitle(),
      trailing: _buildTrailing(),
      onTap: isConnecting || !enabled ? null : onTap,
    );
  }

  Widget _buildTrailing() {
    if (isConnecting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Config/Settings button (T116)
        IconButton(
          icon: const Icon(
            Icons.settings,
            color: AppTheme.textSecondary,
            size: 28,
          ),
          onPressed: onConfig,
          tooltip: 'Watch Settings',
        ),
        const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ],
    );
  }

  Widget _buildLeadingIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: isConnecting
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/ZSWatch_Logo.svg',
                  width: 28,
                  height: 28,
                ),
                if (watch.batteryLevel != null)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: _buildBatteryIndicator(),
                  ),
              ],
            ),
    );
  }

  Widget _buildBatteryIndicator() {
    final level = watch.batteryLevel ?? 0;
    final color = AppTheme.getBatteryColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$level%',
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    final parts = <String>[];

    // Show firmware version if available
    if (watch.firmwareVersion != null) {
      parts.add('v${watch.firmwareVersion}');
    }

    // Show last connected time
    if (watch.lastConnectedAt != null) {
      parts.add(_formatLastConnected(watch.lastConnectedAt!));
    }

    // Show ID as fallback
    if (parts.isEmpty) {
      parts.add(watch.id);
    }

    return Text(
      parts.join(' • '),
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
    );
  }

  String _formatLastConnected(DateTime lastConnected) {
    final now = DateTime.now();
    final diff = now.difference(lastConnected);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${lastConnected.day}/${lastConnected.month}/${lastConnected.year}';
    }
  }
}
