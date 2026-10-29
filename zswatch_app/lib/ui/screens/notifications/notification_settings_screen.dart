import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/companion_runtime_providers.dart';
import 'companion_notification_settings_view.dart';

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
    extends ConsumerState<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: _buildIosMessage(),
      );
    }
    return const CompanionNotificationSettingsView();
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
            Text(
              ref
                          .watch(companionSnapshotProvider)
                          .asData
                          ?.value
                          .fields['ancs_authorized'] ==
                      true
                  ? 'System notification sharing is authorized'
                  : 'System notification sharing is not authorized for the current connection',
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const Text(
              'On iOS, notifications are forwarded directly from your iPhone to ZSWatch using Apple Notification Center Service (ANCS).\n\n'
              'Pair your watch and allow it to share system notifications. You can change this in iPhone Settings > Bluetooth > ZSWatch > Share System Notifications. iOS controls which notifications are shared.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
