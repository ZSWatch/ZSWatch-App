import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/notification.dart';

/// Service for forwarding phone notifications to the watch.
///
/// On Android:
/// - Uses NotificationListenerService via MethodChannel
/// - Requires user to grant notification access permission
///
/// On iOS:
/// - Not applicable - ANCS handles notifications directly between iOS and watch
/// - This service provides a no-op implementation
class NotificationService {
  static const _methodChannel = MethodChannel('com.example.zswatch_app/notifications');
  static const _eventChannel = EventChannel('com.example.zswatch_app/notification_events');

  final _notificationPostedController = StreamController<PhoneNotification>.broadcast();
  final _notificationRemovedController = StreamController<int>.broadcast();
  final _permissionStatusController = StreamController<bool>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  bool _initialized = false;
  bool _permissionGranted = false;

  /// Stream of posted notifications
  Stream<PhoneNotification> get notificationPosted => _notificationPostedController.stream;

  /// Stream of removed notification IDs
  Stream<int> get notificationRemoved => _notificationRemovedController.stream;

  /// Stream of permission status changes
  Stream<bool> get permissionStatus => _permissionStatusController.stream;

  /// Whether the service has been initialized
  bool get isInitialized => _initialized;

  /// Whether notification access permission is granted
  bool get hasPermission => _permissionGranted;

  /// Whether this platform supports notification forwarding
  bool get isSupported => Platform.isAndroid;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isAndroid) {
      // iOS uses ANCS directly between watch and iOS - app not involved
      debugPrint('NotificationService: iOS uses ANCS, not initializing');
      _initialized = true;
      return;
    }

    try {
      // Check initial permission status
      _permissionGranted = await isNotificationAccessEnabled();
      _permissionStatusController.add(_permissionGranted);

      // Start listening to notification events
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (Object error) {
          debugPrint('NotificationService event error: $error');
        },
      );

      _initialized = true;
      debugPrint('NotificationService initialized, permission: $_permissionGranted');
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
      rethrow;
    }
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;

    final eventType = event['event'] as String?;
    final notificationData = event['notification'] as Map?;

    switch (eventType) {
      case 'posted':
        if (notificationData != null) {
          try {
            final notification = PhoneNotification.fromMap(
              Map<String, dynamic>.from(notificationData),
            );
            _notificationPostedController.add(notification);
            debugPrint('Notification posted: ${notification.appName} - ${notification.title}');
          } catch (e) {
            debugPrint('Error parsing notification: $e');
          }
        }
        break;

      case 'removed':
        final id = notificationData?['id'] as int?;
        if (id != null) {
          _notificationRemovedController.add(id);
          debugPrint('Notification removed: $id');
        }
        break;
    }
  }

  /// Check if notification access permission is enabled
  Future<bool> isNotificationAccessEnabled() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>('isNotificationAccessEnabled');
      _permissionGranted = result ?? false;
      return _permissionGranted;
    } catch (e) {
      debugPrint('Error checking notification access: $e');
      return false;
    }
  }

  /// Request notification access permission (opens system settings)
  Future<void> requestNotificationAccess() async {
    if (!Platform.isAndroid) return;

    try {
      await _methodChannel.invokeMethod<void>('requestNotificationAccess');
    } catch (e) {
      debugPrint('Error requesting notification access: $e');
    }
  }

  /// Check if the notification listener service is running
  Future<bool> isServiceRunning() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking service status: $e');
      return false;
    }
  }

  /// Get currently active notifications
  Future<List<PhoneNotification>> getActiveNotifications() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getActiveNotifications');
      if (result == null) return [];

      return result
          .whereType<Map<Object?, Object?>>()
          .map((map) => PhoneNotification.fromMap(Map<String, dynamic>.from(map)))
          .toList();
    } catch (e) {
      debugPrint('Error getting active notifications: $e');
      return [];
    }
  }

  /// Dismiss a notification on the phone
  Future<void> dismissNotification(String key) async {
    if (!Platform.isAndroid) return;

    try {
      await _methodChannel.invokeMethod<void>('dismissNotification', {'key': key});
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
    }
  }

  /// Get list of apps that have posted notifications
  Future<List<AppNotificationFilter>> getNotificationApps() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getNotificationApps');
      if (result == null) return [];

      return result
          .whereType<Map<Object?, Object?>>()
          .map((map) => AppNotificationFilter.fromMap(Map<String, dynamic>.from(map)))
          .toList();
    } catch (e) {
      debugPrint('Error getting notification apps: $e');
      return [];
    }
  }

  /// Post a native Android notification for debugging and return its metadata.
  Future<Map<String, dynamic>?> sendNativeTestNotification({
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
        'sendTestNotification',
        {
          'title': title,
          'body': body,
        },
      );

      return result;
    } on PlatformException catch (e) {
      debugPrint('Error sending test notification: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      rethrow;
    }
  }

  /// Refresh permission status
  Future<void> refreshPermissionStatus() async {
    if (!Platform.isAndroid) return;

    final enabled = await isNotificationAccessEnabled();
    if (enabled != _permissionGranted) {
      _permissionGranted = enabled;
      _permissionStatusController.add(enabled);
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _notificationPostedController.close();
    await _notificationRemovedController.close();
    await _permissionStatusController.close();
    _initialized = false;
  }
}
