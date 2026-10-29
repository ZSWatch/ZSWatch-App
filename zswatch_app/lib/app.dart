import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/lifecycle_logger.dart';

import 'providers/analytics_providers.dart';

import 'providers/companion_runtime_providers.dart';
import 'providers/companion_permission_setup_providers.dart';
import 'providers/companion_voice_policy_providers.dart';
import 'providers/companion_watch_providers.dart';

import 'providers/demo_mode_provider.dart';

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
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LifecycleLogger.log('AppLifecycle', 'initState');

    _router = AppRouter.createNativeRouter();
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    LifecycleLogger.log('AppLifecycle', state.name);
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(companionPermissionsStatusProvider);
    }
  }

  @override
  void dispose() {
    LifecycleLogger.log('AppLifecycle', 'dispose');
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    ref.watch(companionWatchPersistenceProvider);
    ref.watch(companionTelemetryUpdatesProvider);
    ref.watch(companionVoicePolicySyncProvider);
    ref.watch(companionPermissionsStatusProvider);
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

    return MaterialApp.router(
      title: 'ZSWatch',
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // Router configuration
      routerConfig: _router,

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
