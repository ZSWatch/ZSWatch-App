import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/companion_runtime_providers.dart';
import '../../providers/demo_mode_provider.dart';
import '../../providers/permission_providers.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/connection/scan_screen.dart';
import '../screens/crash_report/crash_report_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/developer/comm_log_screen.dart';
import '../screens/developer/companion_prototype_app.dart';
import '../screens/developer/developer_screen.dart';
import '../screens/developer/file_system_screen.dart';
import '../screens/developer/log_viewer_screen.dart';
import '../screens/developer/sensor_debug_screen.dart';
import '../screens/developer/shell_screen.dart';
import '../screens/firmware/firmware_update_screen.dart';
import '../screens/health/health_screen.dart';
import '../screens/health/heart_rate_screen.dart';
import '../screens/notifications/notification_settings_screen.dart';
import '../screens/onboarding/companion_onboarding_screen.dart';
import '../screens/settings/ai_models_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/start/start_page_screen.dart';
import '../screens/voice_memos/alarms_timers_screen.dart';
import '../screens/voice_memos/voice_memos_screen.dart';
import '../screens/watchface/watchface_background_screen.dart';

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
  static const String fileSystem = '/developer/file-system';
  static const String companionRuntime = '/developer/companion-runtime';

  // Settings sub-routes
  static const String aiModels = '/settings/ai-models';

  // Watchface
  static const String watchfaceBackground = '/watchface-background';

  // Crash report
  static const String crashReport = '/crash-report';

  // Voice routes
  static const String voiceMemos = '/voice-memos';
  static const String alarmsTimers = '/voice-memos/alarms-timers';

  static String voiceMemoDetail(int id) => '$voiceMemos/$id';
}

/// App router configuration using go_router
class AppRouter {
  AppRouter._();

  /// Routes for the mobile companion UI. Each app instance owns and disposes
  /// its router independently of the native watch connection.
  static GoRouter createNativeRouter() => GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.health,
        builder: (context, state) => const HealthScreen(),
        routes: [
          GoRoute(
            path: 'heart-rate',
            builder: (context, state) => const HeartRateScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.analytics,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const _HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const _HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.voiceMemos,
        builder: (context, state) => const VoiceMemosScreen(),
      ),
      GoRoute(
        path: AppRoutes.alarmsTimers,
        builder: (context, state) => const AlarmsTimersScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiModels,
        builder: (context, state) => const AiModelsSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.companionRuntime,
        builder: (context, state) => const CompanionPrototypeApp(),
      ),
      GoRoute(
        path: AppRoutes.savedWatches,
        builder: (context, state) => const StartPageScreen(),
      ),
      GoRoute(
        path: AppRoutes.developer,
        builder: (context, state) => const DeveloperScreen(),
      ),
      GoRoute(
        path: AppRoutes.logViewer,
        builder: (context, state) => const LogViewerScreen(),
      ),
      GoRoute(
        path: AppRoutes.commLog,
        builder: (context, state) => const CommLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.crashReport,
        builder: (context, state) => const CrashReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.sensors,
        builder: (context, state) => const SensorDebugScreen(),
      ),
      GoRoute(
        path: AppRoutes.shell,
        builder: (context, state) => const ShellScreen(),
      ),
      GoRoute(
        path: AppRoutes.fileSystem,
        builder: (context, state) => const FileSystemScreen(),
      ),
      GoRoute(
        path: AppRoutes.firmware,
        builder: (context, state) => const FirmwareUpdateScreen(),
      ),
      GoRoute(
        path: AppRoutes.watchfaceBackground,
        builder: (context, state) => const WatchfaceBackgroundScreen(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('This feature is not available in this build')),
    ),
  );
}

/// Home screen - entry point that shows permission onboarding, start page or dashboard based on state
class _HomeScreen extends ConsumerWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(demoModeProvider)) return const DashboardScreen();

    final onboarding = ref.watch(permissionOnboardingCompletedProvider);
    if (onboarding.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (onboarding.hasError) {
      return Scaffold(
        body: Center(
          child: OutlinedButton(
            onPressed: () =>
                ref.invalidate(permissionOnboardingCompletedProvider),
            child: const Text('Retry loading setup'),
          ),
        ),
      );
    }
    if (onboarding.asData?.value != true) {
      return const CompanionOnboardingScreen();
    }
    final snapshot = ref.watch(companionSnapshotProvider);
    return snapshot.when(
      skipLoadingOnRefresh: false,
      data: (state) => state.protocolReady
          ? const DashboardScreen()
          : const StartPageScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Watch connection status is unavailable'),
              OutlinedButton(
                onPressed: () => ref.invalidate(companionSnapshotProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
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

  /// Navigate to watchface background
  void goToWatchfaceBackground() => go(AppRoutes.watchfaceBackground);

  /// Navigate to saved watches
  void goToSavedWatches() => go(AppRoutes.savedWatches);
}
