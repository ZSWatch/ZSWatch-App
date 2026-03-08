import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/ble_providers.dart';
import 'providers/developer_providers.dart';
import 'providers/foreground_service_providers.dart';
import 'providers/gps_providers.dart';
import 'providers/http_providers.dart';
import 'providers/notification_providers.dart';
import 'providers/permission_providers.dart';
import 'providers/ai_providers.dart';
import 'providers/voice_memo_providers.dart';
import 'providers/watch_service_provider.dart';
import 'ui/navigation/app_router.dart';

/// Main application widget
///
/// Configures theming, routing, and global providers.
class ZSWatchApp extends ConsumerStatefulWidget {
  const ZSWatchApp({super.key});

  @override
  ConsumerState<ZSWatchApp> createState() => _ZSWatchAppState();
}

class _ZSWatchAppState extends ConsumerState<ZSWatchApp> {
  @override
  void initState() {
    super.initState();
    // Initialize BLE service after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBle();
    });
  }

  Future<void> _initializeBle() async {
    try {
      // Initialize permission notifier first to check/track permission state
      // This also sets up the lifecycle observer to re-check on app resume
      ref.read(permissionNotifierProvider);
      
      await ref.read(bleNotifierProvider.notifier).initialize();
      // Initialize notification forwarding so it works even when the
      // notification settings screen hasn't been opened yet
      // This is a read to trigger the provider initialization
      ref.read(notificationForwardingProvider);
      // Initialize media control for music info forwarding
      ref.read(mediaControlProvider);
      // Initialize GPS handler to respond to watch GPS power requests
      ref.read(gpsNotifierProvider);
      // Initialize HTTP relay handler to process watch HTTP requests
      ref.read(httpRelayNotifierProvider);
      // Initialize comm log and log viewer to start collecting data in background
      // These subscribe to watch service streams for BLE traffic logging
      ref.read(commLogRepositoryProvider);
      ref.read(logEntriesProvider);
      // Initialize foreground service manager to handle background connection (FR-089 to FR-092)
      // This subscribes to connection state changes and manages the Android foreground service
      ref.read(foregroundServiceNotifierProvider);
      // Initialize watch info persistence to sync firmware version and lastConnectedAt to database
      // This listens to watch info and connection state changes and persists them
      ref.read(watchInfoPersistenceProvider);
      // Initialize voice memo sync service to handle recording sync from watch
      // This subscribes to watch messages for new recording notifications
      ref.read(voiceMemoSyncServiceProvider);

      // [DEV] Run AI pipeline self-test on startup to validate model / inference
      // TODO: Remove before release — this is a development-time smoke test
      unawaited(runAiStartupTest(ref));
    } catch (e) {
      debugPrint('BLE initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZSWatch',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // Router configuration
      routerConfig: AppRouter.router,

      // Builder for global overlays/providers
      builder: (context, child) {
        return MediaQuery(
          // Prevent system text scaling from breaking layouts
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// App-level error widget
class AppErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;

  const AppErrorWidget({
    super.key,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  details.exceptionAsString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
