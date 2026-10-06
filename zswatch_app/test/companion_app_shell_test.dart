import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zswatch_app/app.dart';
import 'package:zswatch_app/providers/ai_providers.dart';
import 'package:zswatch_app/providers/auto_reconnect_provider.dart';
import 'package:zswatch_app/providers/chat_providers.dart';
import 'package:zswatch_app/providers/dfu_providers.dart';
import 'package:zswatch_app/providers/developer_providers.dart';
import 'package:zswatch_app/providers/filesystem_providers.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/companion_recording_import_providers.dart';
import 'package:zswatch_app/providers/companion_watch_providers.dart';
import 'package:zswatch_app/services/background/companion_watch_catalogue.dart';
import 'package:zswatch_app/providers/foreground_service_providers.dart';
import 'package:zswatch_app/providers/health_providers.dart';
import 'package:zswatch_app/providers/notification_providers.dart';
import 'package:zswatch_app/providers/permission_providers.dart';
import 'package:zswatch_app/providers/voice_memo_providers.dart';
import 'package:zswatch_app/providers/watch_providers.dart' as database;
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/ui/navigation/app_router.dart';
import 'package:zswatch_app/ui/screens/dashboard/dashboard_screen.dart';

Map<String, Object?> snapshot({bool active = false, bool ready = false}) => {
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': active,
  'protocol_ready': ready,
  'phase': ready
      ? 'ready'
      : active
      ? 'connecting'
      : 'stopped',
  'desired_running': active,
  'event_cursor': ready
      ? 3
      : active
      ? 2
      : 1,
  'generation': active ? 10 : 11,
  'address': 'AA:BB:CC:DD:EE:FF',
  'events': <Object?>[],
  'recordings': <String, Object?>{},
  'recording_sync_enabled': false,
  'notifications_enabled': true,
  'notification_packages': ['com.zswatch.app'],
  'watch_info': {
    'address': 'AA:BB:CC:DD:EE:FF',
    'first_seen_ms': 1000,
    'firmware_version': '0.8.1',
    'hardware_version': 'watchdk',
    'battery_level': 87,
    'status_generation': 10,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  const events = MethodChannel('dev.zswatch.app/companion_events_v1');
  const logs = MethodChannel('dev.zswatch.app/companion_logs_v1');
  const traffic = MethodChannel('dev.zswatch.app/companion_traffic_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final metadataWrites = <CompanionWatchMetadata>[];
  final subscriptions = <String>[];
  final logSubscriptions = <String>[];
  final trafficSubscriptions = <String>[];
  final forbidden = <String>[];
  late Map<String, Object?> saved;
  var permissionRequests = 0;
  var denyPermission = false;

  Never legacy(String name) {
    forbidden.add(name);
    throw StateError('Unexpected $name');
  }

  Future<void> emit(WidgetTester tester, Map<String, Object?> state) async {
    saved = state;
    await messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope(state),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester, Map<String, Object?> state) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionRecordingImportsProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          database.allWatchesProvider.overrideWith((ref) => Stream.value([])),
          companionWatchCatalogueWriterProvider.overrideWithValue((
            metadata,
          ) async {
            metadataWrites.add(metadata);
          }),
          companionConnectionPermissionsProvider.overrideWithValue(() async {
            permissionRequests++;
            if (denyPermission) throw StateError('Permission denied');
          }),
          dfuServiceProvider.overrideWith((ref) => legacy('legacy DFU')),
          filesystemUploadServiceProvider.overrideWith(
            (ref) => legacy('legacy FS'),
          ),
          database.databaseProvider.overrideWith((ref) => legacy('Drift')),
          watchServiceProvider.overrideWith(
            (ref) => legacy('Dart WatchService'),
          ),
          bleConnectionServiceProvider.overrideWith(
            (ref) => legacy('Dart BLE'),
          ),
          autoReconnectServiceProvider.overrideWith(
            (ref) => legacy('Dart reconnect'),
          ),
          permissionNotifierProvider.overrideWith(
            (ref) => legacy('legacy onboarding'),
          ),
          foregroundServiceNotifierProvider.overrideWith(
            (ref) => legacy('legacy FGS notifier'),
          ),
          foregroundServiceProvider.overrideWith((ref) => legacy('legacy FGS')),
          watchChatServiceProvider.overrideWith((ref) => legacy('watch chat')),
          voiceMemoRecoveryProvider.overrideWith(
            (ref) => legacy('legacy voice recovery'),
          ),
          voiceMemoSyncServiceProvider.overrideWith(
            (ref) => legacy('legacy voice sync'),
          ),
          transcriptionEngineProvider.overrideWith(
            (ref) => legacy('transcription'),
          ),
          llmServiceProvider.overrideWith((ref) => legacy('LLM')),
          notificationForwardingProvider.overrideWith(
            (ref) => legacy('Dart forwarding'),
          ),
          mediaControlProvider.overrideWith((ref) => legacy('media')),
          healthSummaryProvider.overrideWith((ref) => legacy('health')),
        ],
        child: const ZSWatchApp(),
      ),
    );
    await tester.pump();
    await emit(tester, state);
    if (state['runtime_active'] != true || state['protocol_ready'] == true) {
      await tester.pumpAndSettle();
    }
  }

  GoRouter router(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
          as GoRouter;

  setUp(() {
    calls.clear();
    metadataWrites.clear();
    subscriptions.clear();
    logSubscriptions.clear();
    trafficSubscriptions.clear();
    forbidden.clear();
    permissionRequests = 0;
    denyPermission = false;
    saved = snapshot();
    messenger.setMockMethodCallHandler(events, (call) async {
      subscriptions.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(logs, (call) async {
      logSubscriptions.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(traffic, (call) async {
      trafficSubscriptions.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'start') return {'version': 1, 'accepted': true};
      if (call.method == 'notificationStatus') {
        return {
          'version': 1,
          'access_granted': true,
          'listener_connected': true,
          'apps': [
            {'packageName': 'com.zswatch.app', 'appName': 'ZSWatch'},
          ],
        };
      }
      return saved;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
    messenger.setMockMethodCallHandler(logs, null);
    messenger.setMockMethodCallHandler(traffic, null);
    expect(forbidden, isEmpty);
  });

  testWidgets(
    'existing Comm Log observes native protocol traffic and detaches',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      router(tester).go(AppRoutes.developer);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comm Log'));
      await tester.pumpAndSettle();
      expect(find.text('Communication Log'), findsOneWidget);
      expect(trafficSubscriptions, ['listen']);
      final scope = ProviderScope.containerOf(
        tester.element(find.text('Communication Log')),
      );
      final before = calls.length;
      for (final direction in ['rx', 'tx']) {
        await messenger.handlePlatformMessage(
          traffic.name,
          const StandardMethodCodec().encodeSuccessEnvelope({
            'version': 1,
            'direction': direction,
            'data': 'räven 🦊',
            'size_bytes': 11,
            'chunk_count': direction == 'tx' ? 2 : 1,
            'utc_ms': 1700000000123,
            'generation': 10,
          }),
          (_) {},
        );
        await tester.pump();
      }
      final entries = scope.read(commLogEntriesProvider);
      expect(entries, hasLength(2));
      expect(entries.map((entry) => entry.sizeBytes), [11, 11]);
      expect(entries.last.wasChunked, isTrue);
      expect(entries.last.chunkCount, 2);
      expect(entries.last.timestamp.millisecondsSinceEpoch, 1700000000123);
      expect(scope.read(commLogStatsProvider).totalTxBytes, 11);
      scope.read(commLogRepositoryProvider.notifier).clear();
      expect(scope.read(commLogEntriesProvider), isEmpty);
      router(tester).pop();
      await tester.pumpAndSettle();
      expect(trafficSubscriptions, ['listen', 'cancel']);
      expect(
        calls.length,
        before,
      ); // Observing/closing neither commands nor stops BLE.
      await tester.tap(find.text('Comm Log'));
      await tester.pumpAndSettle();
      expect(scope.read(commLogEntriesProvider), isEmpty);
      expect(trafficSubscriptions, ['listen', 'cancel', 'listen']);
    },
  );

  testWidgets(
    'existing log view observes native logs and detaches without stopping BLE',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      router(tester).go(AppRoutes.developer);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Viewer'));
      await tester.pumpAndSettle();
      expect(logSubscriptions, ['listen']);
      expect(calls, isEmpty);

      Future<void> logEvent(Map<String, Object?> event) async {
        await messenger.handlePlatformMessage(
          logs.name,
          const StandardMethodCodec().encodeSuccessEnvelope({
            'version': 1,
            ...event,
          }),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await logEvent({
        'kind': 'state',
        'requested': false,
        'written': false,
        'pending': false,
      });
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(calls.single.method, 'setLogStreaming');
      expect(calls.single.arguments, {'version': 1, 'enabled': true});
      await logEvent({
        'kind': 'state',
        'requested': true,
        'written': true,
        'pending': false,
      });
      expect(find.text('Enabled'), findsOneWidget);
      await logEvent({
        'kind': 'log',
        'message': '<inf> genuine native fixture räven 🦊',
      });
      final scope = ProviderScope.containerOf(
        tester.element(find.text('Log Viewer')),
      );
      expect(
        scope.read(logEntriesProvider).single.message,
        '<inf> genuine native fixture räven 🦊',
      );
      scope.read(logEntriesProvider.notifier).clear();
      expect(scope.read(logEntriesProvider), isEmpty);
      await logEvent({
        'kind': 'state',
        'requested': false,
        'written': false,
        'pending': false,
      });
      expect(find.text('Disabled'), findsOneWidget);
      router(tester).pop();
      await tester.pumpAndSettle();
      expect(logSubscriptions, ['listen', 'cancel']);
      expect(calls.map((call) => call.method), ['setLogStreaming']);
      expect(find.text('Developer Tools'), findsOneWidget);
    },
  );

  testWidgets(
    'app projects a historical Ready receipt without starting a stopped owner',
    (tester) async {
      final savedState = snapshot();
      savedState['last_ready'] = {
        'address': savedState['address'],
        'generation': 10,
        'utc_ms': 1700000000123,
      };
      await mount(tester, savedState);
      expect(find.text('Watch disconnected'), findsOneWidget);
      expect(metadataWrites, hasLength(1));
      expect(
        metadataWrites.single.readyAt.millisecondsSinceEpoch,
        1700000000000,
      );
      expect(calls, isEmpty);
      expect(permissionRequests, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'cold startup, safe navigation and lifecycle observe without starting legacy services or BLE',
    (tester) async {
      await mount(tester, snapshot());
      expect(find.text('Watch disconnected'), findsOneWidget);
      expect(calls, isEmpty);
      expect(permissionRequests, 0);
      final routes = router(tester);
      routes.go(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      routes.go(AppRoutes.notifications);
      await tester.pumpAndSettle();
      expect(find.text('Notification listener connected'), findsOneWidget);
      routes.go(AppRoutes.voiceMemos);
      await tester.pumpAndSettle();
      expect(find.text('Voice Notes'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['notificationStatus']);
      expect(subscriptions, ['listen']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(subscriptions, ['listen', 'cancel']);
      expect(calls.where((c) => c.method == 'stop'), isEmpty);
    },
  );

  testWidgets(
    'Settings manages saved watches with the existing connection view and observes without changing ownership',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      final routes = router(tester);
      routes.push(AppRoutes.settings);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watch connection'));
      await tester.pumpAndSettle();
      expect(find.text('Saved watches'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('Cancel connection'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Companion prototype'), findsNothing);
      expect(find.text('Connection setup'), findsNothing);
      expect(calls, isEmpty);
      expect(permissionRequests, 0);

      routes.pop();
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.tap(find.text('Watch connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['stop']);
      await emit(tester, snapshot());
      await tester.pumpAndSettle();
      expect(find.text('Connect'), findsOneWidget);
      expect(permissionRequests, 0);
    },
  );

  testWidgets(
    'existing Developer actions use the single native owner without legacy BLE',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, snapshot(active: true, ready: true));
      router(tester).go(AppRoutes.developer);
      await tester.pumpAndSettle();
      expect(find.text('Developer Tools'), findsOneWidget);
      for (final label in ['Find watch', 'Sync Time', 'Device Info']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(
        calls
            .where(
              (call) => [
                'findWatch',
                'syncTime',
                'requestDeviceInfo',
              ].contains(call.method),
            )
            .map((call) => call.method),
        ['findWatch', 'syncTime', 'requestDeviceInfo'],
      );
      expect(
        calls.singleWhere((call) => call.method == 'findWatch').arguments,
        {'version': 1, 'generation': 10},
      );
      expect(
        calls.where((call) => call.method == 'start' || call.method == 'stop'),
        isEmpty,
      );
      expect(permissionRequests, 0);
    },
  );

  testWidgets(
    'explicit Connect acceptance stays on connection view until Ready; Disconnect persists native Stop',
    (tester) async {
      await mount(tester, snapshot());
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(permissionRequests, 1);
      expect(calls.single.method, 'start');
      expect(calls.single.arguments, {
        'version': 1,
        'address': 'AA:BB:CC:DD:EE:FF',
      });
      expect(find.byType(DashboardScreen), findsNothing);
      await emit(tester, snapshot(active: true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Cancel connection'), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      await emit(tester, snapshot(active: true, ready: true));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('87%'), findsOneWidget);
      expect(find.text('Health'), findsNothing);
      expect(find.text('Update Firmware'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'stop');
      await emit(tester, snapshot());
      await tester.pumpAndSettle();
      expect(find.text('Connect'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'permission denial never sends Start or displays a connected dashboard',
    (tester) async {
      denyPermission = true;
      await mount(tester, snapshot());
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(permissionRequests, 1);
      expect(
        find.text('Could not change the watch connection'),
        findsOneWidget,
      );
      expect(find.byType(DashboardScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'native Add Watch route only observes until the user starts discovery',
    (tester) async {
      await mount(tester, snapshot());
      router(tester).go(AppRoutes.scan);
      await tester.pumpAndSettle();
      expect(find.text('Add Watch'), findsOneWidget);
      expect(find.text('Find watch'), findsOneWidget);
      expect(calls, isEmpty);
      expect(permissionRequests, 0);
      expect(forbidden, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'native dashboard opens the existing watchface gallery without a legacy owner',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      await tester.ensureVisible(find.text('Watchface'));
      await tester.tap(find.text('Watchface'));
      await tester.pumpAndSettle();
      expect(find.text('Watchface Background'), findsOneWidget);
      expect(find.text('Fume Guilloche'), findsOneWidget);
      expect(forbidden, isEmpty);
    },
  );

  testWidgets(
    'native firmware route preserves selection UI without legacy transport',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      router(tester).go(AppRoutes.firmware);
      await tester.pumpAndSettle();
      expect(find.text('Firmware Update'), findsOneWidget);
      expect(find.text('Available Releases'), findsOneWidget);
      expect(find.text('Select .zip or .bin file'), findsOneWidget);
      expect(forbidden, isEmpty);
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'deep links to unmigrated health and DB detail features stay unavailable',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      final routes = router(tester);
      for (final path in [AppRoutes.health, AppRoutes.voiceMemoDetail(12)]) {
        routes.go(path);
        await tester.pumpAndSettle();
        expect(
          find.text('This feature is not available in this build'),
          findsOneWidget,
        );
      }
      expect(calls, isEmpty);
      routes.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'reconnection and observer failures remove live dashboard; cancel goes only to native Stop',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      await emit(tester, {...snapshot(active: true), 'phase': 'disconnected'});
      await tester.pump();
      expect(find.byType(DashboardScreen), findsNothing);
      await tester.tap(find.text('Cancel connection'));
      await tester.pump();
      expect(calls.single.method, 'stop');
      await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeErrorEnvelope(
          code: 'SNAPSHOT_FAILED',
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Watch connection status is unavailable'),
        findsOneWidget,
      );
      expect(find.byType(DashboardScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
