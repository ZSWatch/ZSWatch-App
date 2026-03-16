import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification.freezed.dart';

/// Notification model for phone → watch notification forwarding
///
/// Represents a phone notification that will be forwarded to the watch
/// via the Gadgetbridge protocol.

/// Notification category types
enum NotificationCategory {
  message,
  email,
  call,
  social,
  news,
  promo,
  reminder,
  system,
  other;

  /// Determine category from Android notification category
  static NotificationCategory fromAndroidCategory(String? category) {
    switch (category?.toLowerCase()) {
      case 'msg':
      case 'message':
        return NotificationCategory.message;
      case 'email':
        return NotificationCategory.email;
      case 'call':
        return NotificationCategory.call;
      case 'social':
        return NotificationCategory.social;
      case 'news':
        return NotificationCategory.news;
      case 'promo':
        return NotificationCategory.promo;
      case 'reminder':
      case 'alarm':
        return NotificationCategory.reminder;
      case 'sys':
      case 'system':
      case 'service':
      case 'progress':
        return NotificationCategory.system;
      default:
        return NotificationCategory.other;
    }
  }
}

/// Phone notification to be forwarded to watch
@freezed
abstract class PhoneNotification with _$PhoneNotification {
  const PhoneNotification._();

  const factory PhoneNotification({
    /// Stable positive ID (mapped from Android StatusBarNotification.id)
    required int id,

    /// Package name of the source app
    required String packageName,

    /// Human-readable app name
    required String appName,

    /// Notification title (may be null for some apps)
    String? title,

    /// Notification body text
    String? body,

    /// Sender name (for messaging apps)
    String? sender,

    /// Subject (for email apps)
    String? subject,

    /// Phone number (for calls/SMS)
    String? phoneNumber,

    /// Notification category
    @Default(NotificationCategory.other) NotificationCategory category,

    /// Whether this notification supports reply action
    @Default(false) bool canReply,

    /// Whether this notification is a group summary
    @Default(false) bool isGroupSummary,

    /// Timestamp when the notification was posted
    required DateTime postedAt,

    /// Android notification key for dismissal
    String? key,
  }) = _PhoneNotification;

  /// Create from Android notification data (via MethodChannel)
  factory PhoneNotification.fromMap(Map<String, dynamic> map) {
    return PhoneNotification(
      id: map['id'] as int? ?? 0,
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? 'Unknown',
      title: map['title'] as String?,
      body: map['body'] as String?,
      sender: map['sender'] as String?,
      subject: map['subject'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      category: NotificationCategory.fromAndroidCategory(
        map['category'] as String?,
      ),
      canReply: map['canReply'] as bool? ?? false,
      isGroupSummary: map['isGroupSummary'] as bool? ?? false,
      postedAt: map['postedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['postedAt'] as int)
          : DateTime.now(),
      key: map['key'] as String?,
    );
  }

  /// Convert to map for storage/transfer
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'title': title,
      'body': body,
      'sender': sender,
      'subject': subject,
      'phoneNumber': phoneNumber,
      'category': category.name,
      'canReply': canReply,
      'isGroupSummary': isGroupSummary,
      'postedAt': postedAt.millisecondsSinceEpoch,
      'key': key,
    };
  }
}

/// Notification filter settings for an app
@freezed
abstract class AppNotificationFilter with _$AppNotificationFilter {
  const AppNotificationFilter._();

  const factory AppNotificationFilter({
    /// Package name of the app
    required String packageName,

    /// Human-readable app name
    required String appName,

    /// Whether notifications from this app should be forwarded
    @Default(true) bool enabled,

    /// App icon (base64 encoded, if available)
    String? iconBase64,
  }) = _AppNotificationFilter;

  factory AppNotificationFilter.fromMap(Map<String, dynamic> map) {
    return AppNotificationFilter(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? 'Unknown',
      enabled: map['enabled'] as bool? ?? true,
      iconBase64: map['iconBase64'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'enabled': enabled,
      'iconBase64': iconBase64,
    };
  }
}
