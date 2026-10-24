import 'notification.dart';

/// Live Android permission/listener observation, separate from saved policy.
/// The app catalogue contains metadata only, not notification content or keys.
class CompanionNotificationStatus {
  final bool accessGranted;
  final bool listenerConnected;
  final List<AppNotificationFilter> apps;

  const CompanionNotificationStatus._(
    this.accessGranted,
    this.listenerConnected,
    this.apps,
  );

  factory CompanionNotificationStatus.decode(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['access_granted'] is! bool ||
        value['listener_connected'] is! bool ||
        value['apps'] is! List ||
        (value['apps'] as List).length > 512) {
      throw const FormatException('Unsupported notification status');
    }
    final seen = <String>{};
    final apps = <AppNotificationFilter>[];
    for (final app in value['apps'] as List) {
      if (app is! Map ||
          app['packageName'] is! String ||
          app['appName'] is! String ||
          !RegExp(
            r'^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$',
          ).hasMatch(app['packageName'] as String) ||
          (app['appName'] as String).length > 160 ||
          !seen.add(app['packageName'] as String)) {
        throw const FormatException('Invalid notification app metadata');
      }
      apps.add(
        AppNotificationFilter(
          packageName: app['packageName'] as String,
          appName: app['appName'] as String,
          enabled: false,
        ),
      );
    }
    return CompanionNotificationStatus._(
      value['access_granted'] as bool,
      value['listener_connected'] as bool,
      List.unmodifiable(apps),
    );
  }
}
