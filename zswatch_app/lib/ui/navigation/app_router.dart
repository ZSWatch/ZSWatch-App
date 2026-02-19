import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/connection_state.dart';
import '../../providers/auto_reconnect_provider.dart';
import '../../providers/ble_providers.dart';
import '../../providers/foreground_service_providers.dart';
import '../../providers/permission_providers.dart';
import '../../providers/watch_service_provider.dart';
import '../screens/apps/apps_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/connection/scan_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/developer/comm_log_screen.dart';
import '../screens/developer/developer_screen.dart';
import '../screens/developer/log_viewer_screen.dart';
import '../screens/developer/sensor_debug_screen.dart';
import '../screens/firmware/firmware_update_screen.dart';
import '../screens/health/health_screen.dart';
import '../screens/health/heart_rate_screen.dart';
import '../screens/notifications/notification_settings_screen.dart';
import '../screens/onboarding/permission_onboarding_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/start/start_page_screen.dart';

/// Route names for the app
abstract final class AppRoutes {
  // Main routes
  static const String home = '/';
  static const String dashboard = '/dashboard';
  static const String scan = '/scan';
  static const String settings = '/settings';

  // Connection routes
  static const String deviceList = '/devices';
  static const String savedWatches = '/saved-watches';

  // Feature routes
  static const String firmware = '/firmware';
  static const String apps = '/apps';
  static const String health = '/health';
  static const String heartRate = '/health/heart-rate';
  static const String notifications = '/notifications';
  static const String analytics = '/analytics';

  // Developer routes
  static const String developer = '/developer';
  static const String logViewer = '/developer/logs';
  static const String shell = '/developer/shell';
  static const String sensors = '/developer/sensors';
  static const String commLog = '/developer/comm-log';

  // Voice routes (placeholder)
  static const String voiceMemos = '/voice-memos';
}

/// App router configuration using go_router
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  /// The main router instance
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    routes: [
      // Home/Dashboard route
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const _HomeScreen(),
        routes: [
          // Scan for devices
          GoRoute(
            path: 'scan',
            name: 'scan',
            builder: (context, state) => const ScanScreen(),
          ),
          // Saved watches
          GoRoute(
            path: 'saved-watches',
            name: 'saved-watches',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Saved Watches'),
          ),
        ],
      ),

      // Dashboard (main connected view)
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),

      // Settings
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Firmware update
      GoRoute(
        path: AppRoutes.firmware,
        name: 'firmware',
        builder: (context, state) => const FirmwareUpdateScreen(),
      ),

      // LLEXT Apps management
      GoRoute(
        path: AppRoutes.apps,
        name: 'apps',
        builder: (context, state) => const AppsScreen(),
      ),

      // Health routes
      GoRoute(
        path: AppRoutes.health,
        name: 'health',
        builder: (context, state) => const HealthScreen(),
        routes: [
          GoRoute(
            path: 'heart-rate',
            name: 'heart-rate',
            builder: (context, state) => const HeartRateScreen(),
          ),
        ],
      ),

      // Notifications
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      // Analytics
      GoRoute(
        path: AppRoutes.analytics,
        name: 'analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),

      // Developer routes
      GoRoute(
        path: AppRoutes.developer,
        name: 'developer',
        builder: (context, state) => const DeveloperScreen(),
        routes: [
          GoRoute(
            path: 'logs',
            name: 'logs',
            builder: (context, state) => const LogViewerScreen(),
          ),
          GoRoute(
            path: 'shell',
            name: 'shell',
            builder: (context, state) =>
                const _PlaceholderScreen(title: 'Shell Terminal (Not Available)'),
          ),
          GoRoute(
            path: 'sensors',
            name: 'sensors',
            builder: (context, state) => const SensorDebugScreen(),
          ),
          GoRoute(
            path: 'comm-log',
            name: 'comm-log',
            builder: (context, state) => const CommLogScreen(),
          ),
        ],
      ),

      // Voice memos (placeholder)
      GoRoute(
        path: AppRoutes.voiceMemos,
        name: 'voice-memos',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Voice Memos'),
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
}

/// Home screen - entry point that shows permission onboarding, start page or dashboard based on state
class _HomeScreen extends ConsumerWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(permissionNotifierProvider);
    final connection = ref.watch(watchConnectionProvider);
    final isConnected = connection.state == WatchConnectionState.connected;
    final isConnecting = connection.state.isConnectingOrReconnecting;

    // Show permission onboarding if critical permissions missing and not completed
    if (permissionState.shouldShowOnboarding) {
      return PermissionOnboardingScreen(
        isInitialOnboarding: true,
        onComplete: () {
          // Trigger rebuild by invalidating the provider
          ref.invalidate(permissionNotifierProvider);
        },
      );
    }

    // If connected, show dashboard
    if (isConnected) {
      return const DashboardScreen();
    }

    // If connecting, show progress
    if (isConnecting) {
      final isReconnecting = connection.state == WatchConnectionState.reconnecting;
      return Scaffold(
        appBar: AppBar(
          title: SvgPicture.asset(
            'assets/images/ZSWatch_Text.svg',
            height: 24,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  connection.state.statusText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (isReconnecting && connection.reconnectionCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Attempt ${connection.reconnectionCount} of 3',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.6),
                        ),
                  ),
                ],
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () {
                    // Mark as user-initiated disconnect so foreground service stops
                    ref.read(foregroundServiceNotifierProvider.notifier).markUserDisconnect();
                    // Cancel auto-reconnect and suppress for session
                    ref.read(autoReconnectNotifierProvider.notifier).cancel();
                    // Also cancel any pending connection on WatchService
                    ref.read(watchServiceProvider).cancelPendingConnection();
                    // Also cancel on BleConnectionManager (in case it was used)
                    ref.read(bleNotifierProvider.notifier).cancelPendingConnection();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Not connected - show start page with stored watches (FR-067)
    return const StartPageScreen();
  }
}

/// Placeholder screen for routes not yet implemented
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error screen for navigation errors
class _ErrorScreen extends StatelessWidget {
  final Exception? error;

  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigation extensions for BuildContext
extension NavigationExtensions on BuildContext {
  /// Navigate to scan screen
  void goToScan() => go(AppRoutes.scan);

  /// Navigate to dashboard
  void goToDashboard() => go(AppRoutes.dashboard);

  /// Navigate to settings
  void goToSettings() => go(AppRoutes.settings);

  /// Navigate to firmware update
  void goToFirmware() => go(AppRoutes.firmware);

  /// Navigate to health screen
  void goToHealth() => go(AppRoutes.health);

  /// Navigate to heart rate screen
  void goToHeartRate() => go(AppRoutes.heartRate);

  /// Navigate to notifications
  void goToNotifications() => go(AppRoutes.notifications);

  /// Navigate to analytics
  void goToAnalytics() => go(AppRoutes.analytics);

  /// Navigate to developer tools
  void goToDeveloper() => go(AppRoutes.developer);

  /// Navigate to log viewer
  void goToLogViewer() => go(AppRoutes.logViewer);

  /// Navigate to shell terminal
  void goToShell() => go(AppRoutes.shell);

  /// Navigate to sensor debug
  void goToSensors() => go(AppRoutes.sensors);

  /// Navigate to comm log
  void goToCommLog() => go(AppRoutes.commLog);

  /// Navigate to voice memos
  void goToVoiceMemos() => go(AppRoutes.voiceMemos);

  /// Navigate to saved watches
  void goToSavedWatches() => go(AppRoutes.savedWatches);
}

