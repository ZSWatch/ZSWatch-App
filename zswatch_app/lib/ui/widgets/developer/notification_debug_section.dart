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
  ConsumerState<NotificationDebugSection> createState() => _NotificationDebugSectionState();
}

class _NotificationDebugSectionState extends ConsumerState<NotificationDebugSection> {
  final _titleController = TextEditingController(text: 'Test Notification');
  final _bodyController = TextEditingController(text: 'This is a debug notification from the companion app.');
  String _selectedApp = 'Messages';
  int _notificationId = 1000; // Start from 1000 to avoid conflicts with real notifications
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
      _showSnackBar('Native notification testing is only available on Android', isError: true);
      return;
    }

    final notificationService = ref.read(notificationServiceProvider);

    setState(() => _isPostingNative = true);

    try {
      final result = await notificationService.sendNativeTestNotification(
        title: _titleController.text.isNotEmpty ? _titleController.text : 'ZSWatch Debug',
        body: _bodyController.text.isNotEmpty ? _bodyController.text : 'Debug notification from ZSWatch app',
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Notification Debug',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            
            // App selector dropdown
            DropdownButtonFormField<String>(
              value: _selectedApp,
              decoration: const InputDecoration(
                labelText: 'App Source',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSm,
                  vertical: AppTheme.spacingSm,
                ),
              ),
              items: _appOptions.map((app) {
                return DropdownMenuItem(
                  value: app,
                  child: Text(app),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedApp = value);
                }
              },
            ),
            
            const SizedBox(height: AppTheme.spacingMd),

            // Title input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'Notification title',
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Body input
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'Notification message',
              ),
              maxLines: 3,
              minLines: 2,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isConnected && !_isSending ? _sendNotification : null,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Send'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                IconButton(
                  onPressed: isConnected ? _clearNotifications : null,
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear last notification',
                  style: IconButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingSm),

            // Post native Android notification (uses system-assigned ID)
            ElevatedButton.icon(
              onPressed: _isPostingNative ? null : _sendNativeAndroidNotification,
              icon: _isPostingNative
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.phone_android),
              label: const Text('Send Android Notification'),
            ),

            if (_nativeNotificationId != null) ...[
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                'Last Android notification ID: $_nativeNotificationId'
                '${_nativeNotificationTag != null ? ' (tag: $_nativeNotificationTag)' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            if (!isConnected) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Connect to watch to send notifications',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.warningColor,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
