import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification.dart';
import '../../../providers/notification_providers.dart';

/// Notification settings screen for Android.
///
/// Features:
/// - Enable/disable notification forwarding
/// - Request notification access permission
/// - Filter apps that can forward notifications
///
/// On iOS, shows a message explaining that ANCS is used.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  List<AppNotificationFilter>? _apps;
  bool _loadingApps = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh permission status when app resumes (user may have granted permission)
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationForwardingProvider.notifier).refreshPermission();
      _loadApps();
    }
  }

  Future<void> _loadApps() async {
    if (_loadingApps) return;
    setState(() => _loadingApps = true);

    try {
      final apps = await ref
          .read(notificationForwardingProvider.notifier)
          .getNotificationApps();
      if (mounted) {
        setState(() {
          _apps = apps;
          _loadingApps = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingApps = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSupported = ref.watch(isNotificationForwardingSupported);

    if (!isSupported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: _buildIosMessage(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _buildAndroidContent(),
    );
  }

  Widget _buildIosMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_active,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            const Text(
              'ANCS Notification Forwarding',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const Text(
              'On iOS, notifications are forwarded directly from your iPhone to ZSWatch using Apple Notification Center Service (ANCS).\n\n'
              'No app configuration is needed - just make sure your watch is connected and paired.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAndroidContent() {
    final state = ref.watch(notificationForwardingProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(notificationForwardingProvider.notifier)
            .refreshPermission();
        await _loadApps();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          // Permission status card
          if (!state.hasPermission) _buildPermissionCard(),

          // Main toggle
          _buildMainToggle(state),

          const SizedBox(height: AppTheme.spacingMd),

          // Statistics
          if (state.hasPermission && state.isEnabled)
            _buildStatisticsCard(state),

          const SizedBox(height: AppTheme.spacingMd),

          // App filter list
          if (state.hasPermission && state.isEnabled)
            _buildAppFilterSection(state),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      color: AppTheme.warningColor.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
                SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    'Notification Access Required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            const Text(
              'ZSWatch needs notification access to forward phone notifications to your watch.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref
                      .read(notificationForwardingProvider.notifier)
                      .requestPermission();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Grant Permission'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainToggle(NotificationForwardingState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forward Notifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Send phone notifications to watch',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.isEnabled,
                  onChanged: state.hasPermission
                      ? (value) {
                          ref
                              .read(notificationForwardingProvider.notifier)
                              .setEnabled(value);
                        }
                      : null,
                ),
              ],
            ),
            if (!state.hasPermission) ...[
              const SizedBox(height: AppTheme.spacingSm),
              const Text(
                'Grant notification access to enable this feature',
                style: TextStyle(fontSize: 12, color: AppTheme.warningColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(NotificationForwardingState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Statistics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                _buildStatItem(
                  icon: Icons.send,
                  label: 'Forwarded',
                  value: state.forwardedCount.toString(),
                  color: AppTheme.successColor,
                ),
                const SizedBox(width: AppTheme.spacingLg),
                _buildStatItem(
                  icon: Icons.close,
                  label: 'Dismissed',
                  value: state.dismissedCount.toString(),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppTheme.spacingSm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppFilterSection(NotificationForwardingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'App Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (_loadingApps)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        const Text(
          'Choose which apps can send notifications to your watch',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        if (_apps == null || _apps!.isEmpty)
          _buildEmptyAppsMessage()
        else
          _buildAppList(state),
      ],
    );
  }

  Widget _buildEmptyAppsMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            Icon(
              Icons.apps,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const Text(
              'No apps with notifications yet',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            const Text(
              'Apps will appear here as they send notifications',
              style: TextStyle(fontSize: 12, color: AppTheme.textDisabled),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppList(NotificationForwardingState state) {
    return Card(
      child: Column(
        children: _apps!.asMap().entries.map((entry) {
          final index = entry.key;
          final app = entry.value;
          final isBlocked = state.blockedApps.contains(app.packageName);
          final isLast = index == _apps!.length - 1;

          return Column(
            children: [
              _AppFilterTile(
                app: app,
                isEnabled: !isBlocked,
                onChanged: (enabled) {
                  final notifier = ref.read(
                    notificationForwardingProvider.notifier,
                  );
                  if (enabled) {
                    notifier.unblockApp(app.packageName);
                  } else {
                    notifier.blockApp(app.packageName);
                  }
                },
              ),
              if (!isLast) const Divider(height: 1, indent: 72),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _AppFilterTile extends StatelessWidget {
  final AppNotificationFilter app;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _AppFilterTile({
    required this.app,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAppIcon(),
      title: Text(
        app.appName,
        style: TextStyle(
          color: isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
      subtitle: Text(
        app.packageName,
        style: const TextStyle(fontSize: 11, color: AppTheme.textDisabled),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Switch(value: isEnabled, onChanged: onChanged),
    );
  }

  Widget _buildAppIcon() {
    if (app.iconBase64 != null && app.iconBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(app.iconBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 40,
            height: 40,
            errorBuilder: (_, _, _) => _buildDefaultIcon(),
          ),
        );
      } catch (_) {
        return _buildDefaultIcon();
      }
    }
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.android, color: AppTheme.textSecondary, size: 24),
    );
  }
}
