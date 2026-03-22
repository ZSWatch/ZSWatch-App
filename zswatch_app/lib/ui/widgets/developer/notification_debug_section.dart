import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/notification_providers.dart';
import '../../../providers/watch_service_provider.dart';

/// Debug section for sending test notifications to the watch.
///
/// Features (FR-093 to FR-097):
/// - App name dropdown/selector (FR-094)
/// - Notification title and body input fields (FR-095)
/// - "Send Debug Notification" button (FR-096)
/// - Creates test notification that goes through Gadgetbridge protocol (FR-097)
class NotificationDebugSection extends ConsumerStatefulWidget {
  const NotificationDebugSection({super.key});

  @override
  ConsumerState<NotificationDebugSection> createState() =>
      _NotificationDebugSectionState();
}

class _NotificationDebugSectionState
    extends ConsumerState<NotificationDebugSection> {
  final _titleController = TextEditingController(text: 'Test Notification');
  final _bodyController = TextEditingController(
    text: 'This is a debug notification from the companion app.',
  );
  String _selectedApp = 'Messages';
  int _notificationId =
      1000; // Start from 1000 to avoid conflicts with real notifications
  int? _nativeNotificationId;
  String? _nativeNotificationTag;
  bool _isSending = false;
  bool _isPostingNative = false;

  // App sources supported by ZSWatch firmware (zsw_notification_manager.c)
  static const List<String> _appOptions = [
    'Messages',
    'WhatsApp',
    'Messenger',
    'Gmail',
    'Calendar',
    'Discord',
    'LinkedIn',
    'Reddit',
    'YouTube',
    'Home Assistant',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_isSending) return;

    final watchService = ref.read(watchServiceProvider);
    if (!watchService.isConnected) {
      _showSnackBar('Watch not connected', isError: true);
      return;
    }

    setState(() => _isSending = true);

    try {
      await watchService.sendNotification(
        id: _notificationId,
        source: _selectedApp,
        title: _titleController.text.isNotEmpty ? _titleController.text : null,
        body: _bodyController.text.isNotEmpty ? _bodyController.text : null,
      );

      _notificationId++; // Increment for next notification
      _showSnackBar('Notification sent (ID: ${_notificationId - 1})');
    } catch (e) {
      _showSnackBar('Failed to send: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _clearNotifications() async {
    final watchService = ref.read(watchServiceProvider);
    if (!watchService.isConnected) {
      _showSnackBar('Watch not connected', isError: true);
      return;
    }

    try {
      // Remove the last sent notification
      await watchService.removeNotification(_notificationId - 1);
      _showSnackBar('Cleared notification ${_notificationId - 1}');
    } catch (e) {
      _showSnackBar('Failed to clear: $e', isError: true);
    }
  }

  Future<void> _sendNativeAndroidNotification() async {
    if (_isPostingNative) return;
    if (!Platform.isAndroid) {
      _showSnackBar(
        'Native notification testing is only available on Android',
        isError: true,
      );
      return;
    }

    final notificationService = ref.read(notificationServiceProvider);

    setState(() => _isPostingNative = true);

    try {
      final result = await notificationService.sendNativeTestNotification(
        title: _titleController.text.isNotEmpty
            ? _titleController.text
            : 'ZSWatch Debug',
        body: _bodyController.text.isNotEmpty
            ? _bodyController.text
            : 'Debug notification from ZSWatch app',
      );

      final id = result?['id'] as int?;
      final tag = result?['tag'] as String?;

      setState(() {
        _nativeNotificationId = id;
        _nativeNotificationTag = tag;
      });

      if (id != null) {
        final suffix = tag != null ? ' (tag: $tag)' : '';
        _showSnackBar('Android notification posted (ID: $id$suffix)');
      } else {
        _showSnackBar('Android notification posted');
      }
    } on PlatformException catch (e) {
      _showSnackBar(e.message ?? 'Failed to post notification', isError: true);
    } catch (e) {
      _showSnackBar('Failed to post notification: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isPostingNative = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(watchConnectionProvider);
    final isConnected = connection.isConnected;
    final theme = Theme.of(context);

    const compactButtonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 34)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Text('Notification Debug', style: theme.textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '#$_notificationId',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              'Notification Details',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            DropdownButtonFormField<String>(
              initialValue: _selectedApp,
              decoration: const InputDecoration(
                labelText: 'Source',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: 11,
                ),
              ),
              items: _appOptions.map((app) {
                return DropdownMenuItem<String>(value: app, child: Text(app));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedApp = value);
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: 11,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
                isDense: true,
                alignLabelWithHint: true,
                contentPadding: EdgeInsets.all(AppTheme.spacingSm),
              ),
              minLines: 2,
              maxLines: 2,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: [
                FilledButton.icon(
                  onPressed: isConnected && !_isSending
                      ? _sendNotification
                      : null,
                  style: compactButtonStyle,
                  icon: _isSending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 16),
                  label: const Text('Send'),
                ),
                OutlinedButton.icon(
                  onPressed: isConnected ? _clearNotifications : null,
                  style: compactButtonStyle,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                ),
                OutlinedButton.icon(
                  onPressed: _isPostingNative
                      ? null
                      : _sendNativeAndroidNotification,
                  style: compactButtonStyle,
                  icon: _isPostingNative
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.phone_android, size: 16),
                  label: const Text('Android'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              isConnected
                  ? 'Send directly to the watch or post a local Android notification.'
                  : 'Connect to watch to send notification data.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isConnected
                    ? AppTheme.textSecondary
                    : AppTheme.warningColor,
              ),
            ),
            if (_nativeNotificationId != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Android ID $_nativeNotificationId'
                      '${_nativeNotificationTag != null ? ' · $_nativeNotificationTag' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
