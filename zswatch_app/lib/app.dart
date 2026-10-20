import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/lifecycle_logger.dart';
import 'data/models/connection_state.dart';
import 'providers/analytics_providers.dart';
import 'providers/ble_providers.dart';
import 'providers/companion_runtime_providers.dart';
import 'providers/companion_watch_providers.dart';
import 'providers/coredump_providers.dart';
import 'providers/demo_mode_provider.dart';
import 'providers/developer_providers.dart';
import 'providers/foreground_service_providers.dart';
import 'providers/gps_providers.dart';
import 'providers/http_providers.dart';
import 'providers/notification_providers.dart';
import 'providers/permission_providers.dart';
import 'providers/voice_memo_providers.dart';
import 'services/background/foreground_service.dart';
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

class _ZSWatchAppState extends ConsumerState<ZSWatchApp>
    with WidgetsBindingObserver {
  GoRouter? _nativeRouter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LifecycleLogger.log('AppLifecycle', 'initState');
    if (ref.read(nativeCompanionRuntimeProvider)) {
      _nativeRouter = AppRouter.createNativeRouter();
      // Observe the existing service; UI startup never sends Start, except
      // to undo the Stop of a Demo Mode session that the process outlived.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(demoModeControllerProvider)
            .recoverInterrupted()
            .catchError(
              (Object error) =>
                  debugPrint('[DemoMode] Resume after restart failed: $error'),
            );
      });
      return;
    }
    // Initialize BLE service after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeVoiceRecovery());
      _initializeBle();
    });
  }

  Future<void> _initializeVoiceRecovery() async {
    try {
      await ref.read(voiceMemoRecoveryProvider.future);
    } catch (error) {
      debugPrint('[VoiceMemoRecovery] Startup recovery failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    LifecycleLogger.log('AppLifecycle', state.name);
    unawaited(_syncForegroundServiceLifecycleState(state));
  }

  @override
  void dispose() {
    LifecycleLogger.log('AppLifecycle', 'dispose');
    WidgetsBinding.instance.removeObserver(this);
    _nativeRouter?.dispose();
    super.dispose();
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
      // Keep Android-owned background recovery preferences synchronized for
      // boot/package-replaced receiver scaffolding.
      ref.read(nativeBackgroundPreferencesSyncProvider);
      // Initialize watch info persistence to sync firmware version and lastConnectedAt to database
      // This listens to watch info and connection state changes and persists them
      ref.read(watchInfoPersistenceProvider);
      // Initialize voice memo sync service to handle recording sync from watch
      // This subscribes to watch messages for new recording notifications
      ref.read(voiceMemoSyncServiceProvider);
      ref.read(companionVoiceActionsSyncProvider);
      // Initialize analytics services (connection tracking, battery storage)
      // so events are recorded from app startup, not just when analytics screen is opened
      ref.read(analyticsServicesInitializedProvider);
      // Initialize crash report persistence to save crash summaries to DB
      ref.read(crashReportPersistenceProvider);
    } catch (e) {
      debugPrint('BLE initialization error: $e');
    }
  }

  Future<void> _syncForegroundServiceLifecycleState(
    AppLifecycleState state,
  ) async {
    if (ref.read(nativeCompanionRuntimeProvider)) return;
    if (!Platform.isAndroid) return;

    final foregroundService = ref.read(foregroundServiceProvider);
    if (!foregroundService.isRunning) return;

    final connection = ref.read(watchConnectionProvider);
    final watchName = connection.watchName ?? 'ZSWatch';

    if (state == AppLifecycleState.resumed) {
      await foregroundService.updateNotification(
        watchName: watchName,
        state: _foregroundStateForConnection(connection.state),
      );
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      await foregroundService.updateNotification(
        watchName: watchName,
        state: ForegroundConnectionState.watcher,
      );
    }
  }

  ForegroundConnectionState _foregroundStateForConnection(
    WatchConnectionState state,
  ) {
    switch (state) {
      case WatchConnectionState.connected:
      case WatchConnectionState.syncing:
        return ForegroundConnectionState.connected;
      case WatchConnectionState.reconnecting:
      case WatchConnectionState.connecting:
      case WatchConnectionState.bonding:
      case WatchConnectionState.discoveringServices:
      case WatchConnectionState.negotiating:
      case WatchConnectionState.scanning:
        return ForegroundConnectionState.reconnecting;
      case WatchConnectionState.disconnected:
      case WatchConnectionState.disconnecting:
      case WatchConnectionState.error:
        return ForegroundConnectionState.disconnected;
    }
  }

  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    if (ref.watch(nativeCompanionRuntimeProvider)) {
      ref.watch(companionWatchPersistenceProvider);
      ref.watch(companionTelemetryUpdatesProvider);
      // Make dropped (too large) watch messages visible so we notice if they happen.
      ref.listen(companionSnapshotProvider, (previous, next) {
        final previousSnapshot = previous?.asData?.value;
        final after = next.asData?.value.fields['incomplete_watch_messages'];
        if (previousSnapshot == null || after is! int) return;
        final before = previousSnapshot.fields['incomplete_watch_messages'];
        if (after > (before is int ? before : 0)) {
          _messenger.currentState?.showSnackBar(
            const SnackBar(
              content: Text('A message from the watch arrived incomplete'),
            ),
          );
        }
      });
    }

    return MaterialApp.router(
      title: 'ZSWatch',
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // Router configuration
      routerConfig: _nativeRouter ?? AppRouter.router,

      // Builder for global overlays/providers
      builder: (context, child) {
        return MediaQuery(
          // Prevent system text scaling from breaking layouts
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// App-level error widget
class AppErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;

  const AppErrorWidget({super.key, required this.details});

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
