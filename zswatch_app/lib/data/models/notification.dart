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
class PhoneNotification {
  /// Unique notification ID (from Android StatusBarNotification.id)
  final int id;

  /// Package name of the source app
  final String packageName;

  /// Human-readable app name
  final String appName;

  /// Notification title (may be null for some apps)
  final String? title;

  /// Notification body text
  final String? body;

  /// Sender name (for messaging apps)
  final String? sender;

  /// Subject (for email apps)
  final String? subject;

  /// Phone number (for calls/SMS)
  final String? phoneNumber;

  /// Notification category
  final NotificationCategory category;

  /// Whether this notification supports reply action
  final bool canReply;

  /// Whether this notification is a group summary
  final bool isGroupSummary;

  /// Timestamp when the notification was posted
  final DateTime postedAt;

  /// Android notification key for dismissal
  final String? key;

  const PhoneNotification({
    required this.id,
    required this.packageName,
    required this.appName,
    this.title,
    this.body,
    this.sender,
    this.subject,
    this.phoneNumber,
    this.category = NotificationCategory.other,
    this.canReply = false,
    this.isGroupSummary = false,
    required this.postedAt,
    this.key,
  });

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

  @override
  String toString() {
    return 'PhoneNotification(id: $id, app: $appName, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhoneNotification &&
        other.id == id &&
        other.packageName == packageName;
  }

  @override
  int get hashCode => id.hashCode ^ packageName.hashCode;
}

/// Notification filter settings for an app
class AppNotificationFilter {
  /// Package name of the app
  final String packageName;

  /// Human-readable app name
  final String appName;

  /// Whether notifications from this app should be forwarded
  final bool enabled;

  /// App icon (base64 encoded, if available)
  final String? iconBase64;

  const AppNotificationFilter({
    required this.packageName,
    required this.appName,
    this.enabled = true,
    this.iconBase64,
  });

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

  AppNotificationFilter copyWith({
    String? packageName,
    String? appName,
    bool? enabled,
    String? iconBase64,
  }) {
    return AppNotificationFilter(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      enabled: enabled ?? this.enabled,
      iconBase64: iconBase64 ?? this.iconBase64,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotificationFilter &&
        other.packageName == packageName;
  }

  @override
  int get hashCode => packageName.hashCode;
}


