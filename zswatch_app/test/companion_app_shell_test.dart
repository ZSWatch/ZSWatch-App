import 'dart:async';
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zswatch_app/app.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/providers/ai_providers.dart';
import 'package:zswatch_app/providers/analytics_providers.dart';
import 'package:zswatch_app/ui/screens/health/health_screen.dart';
import 'package:zswatch_app/ui/screens/health/heart_rate_screen.dart';
import 'package:zswatch_app/ui/screens/analytics/analytics_screen.dart';
import 'package:zswatch_app/providers/auto_reconnect_provider.dart';
import 'package:zswatch_app/providers/dfu_providers.dart';
import 'package:zswatch_app/providers/developer_providers.dart';
import 'package:zswatch_app/providers/filesystem_providers.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/demo_mode_provider.dart';
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

import 'support/host_sqlite.dart';

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
  configureHostSqlite();
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  const events = MethodChannel('dev.zswatch.app/companion_events_v1');
  const logs = MethodChannel('dev.zswatch.app/companion_logs_v1');
  const traffic = MethodChannel('dev.zswatch.app/companion_traffic_v1');
  const sensors = MethodChannel('dev.zswatch.app/companion_sensors_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final metadataWrites = <CompanionWatchMetadata>[];
  final subscriptions = <String>[];
  final logSubscriptions = <String>[];
  final trafficSubscriptions = <String>[];
  final sensorSubscriptions = <String>[];
  final nativeJobDetails = <String, Map<String, Object?>>{};
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

  Future<void> mount(
    WidgetTester tester,
    Map<String, Object?> state, {
    AppDatabase? crashDb,
  }) async {
    final db =
        crashDb ??
        AppDatabase.forTesting(
          NativeDatabase.memory(),
          recoverLegacyProcessing: false,
        );
    if (crashDb == null) addTearDown(db.close);
    await tester.runAsync(() => db.getAllWatches());
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
          database.databaseProvider.overrideWith((ref) => db),
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
          lifecycleLogEntriesProvider.overrideWith((ref, id) async => []),
          batteryStorageServiceProvider.overrideWith(
            (ref) => legacy('Dart battery collector'),
          ),
          connectionAnalyticsServiceProvider.overrideWith(
            (ref) => legacy('Dart connection collector'),
          ),
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
    sensorSubscriptions.clear();
    nativeJobDetails.clear();
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
    messenger.setMockMethodCallHandler(sensors, (call) async {
      sensorSubscriptions.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'voiceJob') {
        final id = (call.arguments as Map)['job_id'] as String;
        return {'version': 1, 'job_id': id, 'job': nativeJobDetails[id]!};
      }
      if (call.method == 'sensorState') {
        return {
          'version': 1,
          'kind': 'state',
          'generation': 10,
          'available': ['temperature', 'fusion'],
          'enabled': <String>[],
        };
      }
      if (call.method == 'setSensor') return {'version': 1, 'completed': true};
      if (call.method == 'restartWatch') {
        return {'version': 1, 'acknowledged': true};
      }
      if (call.method == 'processRecording') {
        return {'version': 1, 'job_id': 'a' * 64};
      }
      if (call.method == 'start') return {'version': 1, 'accepted': true};
      if (call.method == 'inspectCoredump') {
        return {'version': 1, 'completed': true};
      }
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
      if (call.method == 'permissionStatus') {
        return {
          'version': 1,
          'bluetooth': true,
          'notifications': true,
          'notification_access': false,
          'location': true,
          'background_location': false,
          'battery_exemption': false,
        };
      }
      return saved;
    });
  });
  testWidgets('native connection error ends spinner and exposes cancellation failure', (tester) async {
    final failed = {...snapshot(active: true), 'phase': 'error', 'last_error': 'Previous Bluetooth session has not finished disconnecting. Cancel connection and try again.'};
    await mount(tester, failed); await tester.pumpAndSettle();
    expect(find.text(failed['last_error'] as String), findsOneWidget);
    expect(find.text('Cancel connection'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Cancel connection')); await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'stop'), hasLength(1));
    expect(calls.where((c) => c.method == 'start'), isEmpty);
  });

  testWidgets('native settings enters isolated demo and all six entrances remain usable', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, snapshot());
    router(tester).go(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.text('Demo Mode'), findsOneWidget);
    await tester.ensureVisible(find.text('Demo Mode'));
    final toggle = find.descendant(of: find.ancestor(of: find.text('Demo Mode'), matching: find.byType(ListTile)), matching: find.byType(Switch));
    final target = toggle.evaluate().isNotEmpty ? toggle : find.byType(Switch).last;
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    final scope = ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    expect(scope.read(demoModeProvider), true);
    expect(calls.where((c) => c.method == 'stop'), hasLength(1));
    calls.clear(); metadataWrites.clear();
    for (final route in [AppRoutes.health, AppRoutes.notifications, AppRoutes.analytics, AppRoutes.watchfaceBackground, AppRoutes.developer, AppRoutes.voiceMemos]) {
      router(tester).go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
    expect(calls, isEmpty); expect(metadataWrites, isEmpty); expect(forbidden, isEmpty);
    await scope.read(demoModeControllerProvider).set(false);
    await tester.pump();
    await emit(tester, snapshot());
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'start'), isEmpty);
  });

  testWidgets(
    'Restart confirmation uses only the native owner and generation',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      await tester.ensureVisible(find.text('Restart Watch'));
      await tester.tap(find.text('Restart Watch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'restartWatch'), isEmpty);
      await tester.tap(find.text('Restart Watch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'restartWatch').single.arguments, {
        'version': 1,
        'generation': 10,
      });
      expect(find.text('Restart command sent to watch'), findsOneWidget);
      expect(
        calls.where((c) => c.method == 'start' || c.method == 'stop'),
        isEmpty,
      );
      expect(forbidden, isEmpty);
    },
  );

  testWidgets('Permission overview observes native status without prompting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, snapshot(active: true, ready: true));
    unawaited(router(tester).push(AppRoutes.settings));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('App Permissions'));
    await tester.tap(find.text('App Permissions'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 6 granted'), findsOneWidget);
    expect(find.text('Bluetooth connection'), findsOneWidget);
    expect(find.text('Notification access'), findsOneWidget);
    expect(find.text('Background location'), findsOneWidget);
    expect(find.text('Battery optimization'), findsOneWidget);
    expect(permissionRequests, 0);
    expect(calls.where((c) => c.method == 'permissionStatus'), isNotEmpty);
    expect(calls.where((c) => c.method == 'notificationDiagnostic'), isEmpty);
    expect(forbidden, isEmpty);
  });

  testWidgets('Transcribe-only and batch controls queue natively without an LLM', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1000, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = snapshot(active: true, ready: true);
    const identity = 'AA:BB:CC:DD:EE:FF:memo_001:1700000000:100:1000';
    state['recordings'] = {identity: {
      'address': state['address'], 'filename': 'memo_001', 'timestamp': 1700000000,
      'size_bytes': 100, 'duration_ms': 1000, 'state': 'downloaded',
      'local_path': '/private/test.zsw_opus', 'sha256': 'b' * 64,
    }};
    await mount(tester, state);
    router(tester).go(AppRoutes.voiceMemos);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Transcription actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transcribe only'));
    await tester.pumpAndSettle();
    expect(find.text('Transcribe recording'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'processRecording'), isEmpty);
    await tester.tap(find.byTooltip('Transcription actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transcribe only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transcribe'));
    await tester.pumpAndSettle();
    final queued = calls.where((c) => c.method == 'processRecording').single;
    expect((queued.arguments as Map)['operation'], 'transcribe');
    expect((queued.arguments as Map)['identity'], identity);
    await tester.tap(find.text('Transcribe all untranscribed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'processRecording'), hasLength(2));
    final id = 'a' * 64;
    nativeJobDetails[id] = {'state': 'transcribed', 'result': {
      'transcript': 'Stored speech', 'summary': '', 'category': '', 'actions': <Object?>[],
    }};
    await emit(tester, {...state, 'voice_jobs': [{
      'job_id': id, 'recording_id': identity, 'watch_id': state['address'],
      'generation': 1, 'state': 'transcribed', 'selected': true, 'transcript_saved': true,
    }]});
    await tester.pumpAndSettle();
    await tester.tap(find.text('memo_001'));
    await tester.pumpAndSettle();
    expect(find.text('Stored speech'), findsOneWidget);
    expect(find.text('Summary'), findsNothing);
    expect(forbidden, isEmpty);
    expect(calls.where((c) => c.method == 'start' || c.method == 'stop'), isEmpty);
    expect(subscriptions.where((s) => s == 'listen'), hasLength(1));
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
    messenger.setMockMethodCallHandler(logs, null);
    messenger.setMockMethodCallHandler(traffic, null);
    messenger.setMockMethodCallHandler(sensors, null);
    expect(forbidden, isEmpty);
  });

  testWidgets(
    'Health and Analytics reuse stored native data and one snapshot owner',
    (tester) async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        recoverLegacyProcessing: false,
      );
      addTearDown(db.close);
      final now = DateTime.now();
      const address = 'AA:BB:CC:DD:EE:FF';
      await tester.runAsync(() async {
        await db.upsertWatch(
          WatchesCompanion.insert(
            id: address,
            name: 'Owned watch',
            createdAt: now,
          ),
        );
        for (final entry in {
          'steps': 1234.0,
          'heartRate': 72.0,
          'activity': 7.0,
        }.entries) {
          await db.insertHealthSample(
            HealthSamplesCompanion.insert(
              watchId: address,
              type: entry.key,
              value: entry.value,
              timestamp: now.subtract(const Duration(minutes: 5)),
              granularity: 'realtime',
              syncedAt: now,
            ),
          );
        }
        await db.insertBatteryReading(
          BatteryReadingsCompanion.insert(
            watchId: address,
            level: 87,
            timestamp: now,
          ),
        );
        await db.insertConnectionEvent(
          ConnectionEventsCompanion.insert(
            watchId: address,
            eventType: 'connected',
            timestamp: now.subtract(const Duration(minutes: 5)),
          ),
        );
      });
      await mount(tester, snapshot(active: true, ready: true), crashDb: db);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );
      expect(container.read(healthSummaryProvider).todaySteps, 1234);
      expect(container.read(healthSummaryProvider).latestHeartRate, 72);
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      final routes = router(tester);
      routes.go(AppRoutes.health);
      await tester.pumpAndSettle();
      expect(find.byType(HealthScreen), findsOneWidget);
      for (final tab in ['Week', 'Month', 'Today']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
      }
      expect(container.read(stepsHistoryProvider).totalSteps, 1234);
      container.read(heartRateStreamingProvider);
      await tester.runAsync(() async {
        // External native writes are deliberately invisible to Drift until the snapshot.
        for (final entry in {'steps': 2345.0, 'heartRate': 76.0}.entries) {
          await db.customStatement(
            'INSERT INTO health_samples(watch_id,type,value,timestamp,granularity,synced_at) VALUES(?,?,?,?,?,?)',
            [
              address,
              entry.key,
              entry.value,
              now.millisecondsSinceEpoch ~/ 1000,
              'realtime',
              now.millisecondsSinceEpoch ~/ 1000,
            ],
          );
        }
      });
      final live = snapshot(active: true, ready: true)
        ..['latest_health'] = {
          'address': address,
          'generation': 10,
          'sequence': 77,
          'ts': now.millisecondsSinceEpoch,
          'stp': 2345,
          'hrm': 76,
        };
      await emit(tester, live);
      await tester.pumpAndSettle();
      expect(container.read(healthSummaryProvider).todaySteps, 2345);
      expect(container.read(healthSummaryProvider).latestHeartRate, 76);
      final samples = await tester.runAsync(
        () => db.select(db.healthSamples).get(),
      );
      expect(
        samples,
        hasLength(5),
      ); // UI projection did not persist duplicates.
      final readings = container
          .read(heartRateStreamingProvider)
          .recentReadings
          .length;
      await emit(tester, {...live, 'event_cursor': 88});
      await tester.pumpAndSettle();
      expect(
        container.read(heartRateStreamingProvider).recentReadings,
        hasLength(readings),
      );
      routes.go(AppRoutes.heartRate);
      await tester.pumpAndSettle();
      expect(find.byType(HeartRateScreen), findsOneWidget);
      expect(find.text('76'), findsNWidgets(4));
      routes.go(AppRoutes.analytics);
      await tester.pumpAndSettle();
      expect(find.byType(AnalyticsScreen), findsOneWidget);
      expect(
        await container.read(batteryReadings24HoursProvider(address).future),
        hasLength(1),
      );
      await tester.tap(find.text('Connection'));
      await tester.pumpAndSettle();
      expect(
        container.read(connectionStats24HoursProvider(address)).hasValue,
        isTrue,
      );
      expect(forbidden, isEmpty);
      expect(calls, isEmpty);
      expect(subscriptions.where((kind) => kind == 'listen'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'existing Crash Reports uses native summary and keeps UI history after absence',
    (tester) async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        recoverLegacyProcessing: false,
      );
      addTearDown(db.close);
      await tester.runAsync(
        () => db.upsertWatch(
          WatchesCompanion.insert(
            id: 'AA:BB:CC:DD:EE:FF',
            name: 'Owned watch',
            createdAt: DateTime.now(),
          ),
        ),
      );
      final state = snapshot(active: true, ready: true);
      state['watch_info'] =
          Map<String, Object?>.from(state['watch_info'] as Map)..addAll({
            'firmware_sha': 'owned-sha',
            'firmware_debug': true,
            'coredump': {
              'file': 'owned.c',
              'line': 123,
              'time': '2026-10-06 22:00:00',
            },
          });
      await mount(tester, state, crashDb: db);
      router(tester).go(AppRoutes.developer);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crash Reports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crash Reports'));
      await tester.pumpAndSettle();
      expect(find.text('owned.c'), findsOneWidget);
      expect(
        calls.where((call) => call.method == 'inspectCoredump'),
        hasLength(1),
      );
      expect(subscriptions.where((kind) => kind == 'listen'), hasLength(1));
      final rows = await tester.runAsync(
        () => db.getCrashReports(watchId: 'AA:BB:CC:DD:EE:FF'),
      );
      expect(rows, hasLength(1));
      expect(rows!.single.file, 'owned.c');
      final absent = snapshot(active: true, ready: true);
      await emit(tester, absent);
      await tester.pumpAndSettle();
      expect(find.text('No active crash'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('owned.c:123'), findsOneWidget);
      expect(calls.where((call) => call.method == 'downloadCoredump'), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'existing Alarms & Timers reads saved native actions without processing',
    (tester) async {
      final current = 'a' * 64;
      final previous = 'b' * 64;
      final other = 'c' * 64;
      final processing = 'd' * 64;
      nativeJobDetails[current] = {
        'selected': true,
        'state': 'delivered',
        'result': {
          'actions': [
            {'type': 'reminder', 'title': 'Owned reminder'},
            {'type': 'timer', 'title': 'Owned timer', 'duration_seconds': 60},
          ],
        },
      };
      nativeJobDetails[previous] = {
        'selected': false,
        'state': 'cancelled',
        'result': {
          'actions': [
            {'type': 'alarm', 'title': 'Old unused suggestion'},
            {
              'type': 'timer',
              'title': 'Owned prior timer',
              'duration_seconds': 30,
            },
          ],
        },
        'action_states': {
          '1': {'state': 'dispatched'},
        },
      };
      final state = snapshot(active: true, ready: true);
      state['voice_jobs'] = [
        for (final id in [current, previous, other, processing])
          {
            'job_id': id,
            'recording_id': id,
            'generation': 1,
            'watch_id': id == other ? 'OTHER' : state['address'],
            'state': id == processing
                ? 'ready'
                : id == previous
                ? 'cancelled'
                : 'delivered',
            'selected': id != previous,
            'action_revision': id == previous ? 1 : 0,
          },
      ];
      await mount(tester, state);
      router(tester).go(AppRoutes.voiceMemos);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Alarms & Timers'));
      await tester.pumpAndSettle();
      expect(find.text('Alarms & Timers'), findsOneWidget);
      expect(find.text('Owned timer'), findsOneWidget);
      expect(find.text('Owned prior timer'), findsOneWidget);
      expect(find.text('Old unused suggestion'), findsNothing);
      expect(find.text('Owned reminder'), findsNothing);
      expect(
        find.text('Sent to Clock. Manage or remove it in the Clock app.'),
        findsOneWidget,
      );
      final reads = calls.where((call) => call.method == 'voiceJob').toList();
      expect(reads, hasLength(2));
      await emit(tester, {...state, 'unrelated_battery_status': 90});
      await tester.pumpAndSettle();
      expect(calls.where((call) => call.method == 'voiceJob'), hasLength(2));
      expect(
        calls.where(
          (call) => [
            'processRecording',
            'start',
            'cancelVoiceJob',
          ].contains(call.method),
        ),
        isEmpty,
      );
      expect(subscriptions.where((kind) => kind == 'listen'), hasLength(1));
      router(tester).pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('existing Sensors route observes native owner and detaches', (
    tester,
  ) async {
    await mount(tester, snapshot(active: true, ready: true));
    router(tester).go(AppRoutes.developer);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sensors'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sensors'));
    await tester.pumpAndSettle();
    expect(find.text('Sensor Debug'), findsOneWidget);
    expect(sensorSubscriptions, ['listen']);
    expect(
      tester.widget<Switch>(find.byType(Switch).first).onChanged,
      isNotNull,
    );
    expect(subscriptions.where((kind) => kind == 'listen'), hasLength(1));
    await tester.scrollUntilVisible(
      find.text('Temperature'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    final card = find
        .ancestor(of: find.text('Temperature'), matching: find.byType(Card))
        .first;
    final toggle = find.descendant(of: card, matching: find.byType(Switch));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pump(const Duration(milliseconds: 300));
    await messenger.handlePlatformMessage(
      sensors.name,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'version': 1,
        'kind': 'sample',
        'generation': 10,
        'sensor': 'temperature',
        'bytes': Uint8List.fromList([0, 0, 176, 65]),
      }),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('1 samples'), findsOneWidget);
    final commands = calls.where((call) => call.method == 'setSensor').toList();
    expect(commands, hasLength(1));
    final args = commands.single.arguments as Map;
    expect(args['sensor'], 'temperature');
    expect(args['generation'], 10);
    expect(args['enabled'], true);
    router(tester).pop();
    await tester.pumpAndSettle();
    expect(sensorSubscriptions, ['listen', 'cancel']);
    expect(calls.where((call) => call.method == 'stop'), isEmpty);
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
      expect(calls.map((c) => c.method), [
        'permissionStatus',
        'notificationStatus',
      ]);
      expect(subscriptions, ['listen']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(subscriptions, ['listen', 'cancel']);
      expect(calls.where((c) => c.method == 'stop'), isEmpty);
    },
  );

  testWidgets(
    'native Settings keeps common preferences without legacy startup or automatic permission requests',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const permissions = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      final permissionCalls = <String>[];
      messenger.setMockMethodCallHandler(permissions, (call) async {
        permissionCalls.add(call.method);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(permissions, null));
      await mount(tester, snapshot(active: true, ready: true));
      final routes = router(tester);
      unawaited(routes.push<void>(AppRoutes.settings));
      await tester.pumpAndSettle();
      expect(permissionCalls, isEmpty);
      expect(calls.map((c) => c.method), ['permissionStatus']);
      expect(find.text('Persistent Connection'), findsNothing);
      expect(find.text('Demo Mode'), findsOneWidget);
      await tester.ensureVisible(find.text('App Permissions'));
      await tester.tap(find.text('App Permissions'));
      await tester.pumpAndSettle();
      expect(permissionCalls, isEmpty);
      await tester.tap(find.text('Open Android app settings'));
      await tester.pumpAndSettle();
      expect(permissionCalls, ['openAppSettings']);
      await tester.tap(find.text('App Permissions'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Keep Screen On During DFU'));
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Keep Screen On During DFU'),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Coredump Server'));
      await tester.tap(find.text('Coredump Server'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'http://127.0.0.1:18879');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('keep_screen_on_during_dfu'), isFalse);
      expect(prefs.getString('coredump_server_url'), 'http://127.0.0.1:18879');
      routes.pop();
      await tester.pumpAndSettle();
      unawaited(routes.push<void>(AppRoutes.settings));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Coredump Server'));
      expect(find.text('http://127.0.0.1:18879'), findsOneWidget);
      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('Licenses'), findsOneWidget);
      expect(calls.every((c) => c.method == 'permissionStatus'), isTrue);
      expect(permissionRequests, 0);
      expect(subscriptions.where((kind) => kind == 'listen'), hasLength(1));
    },
  );

  testWidgets(
    'Settings manages saved watches with the existing connection view and observes without changing ownership',
    (tester) async {
      await mount(tester, snapshot(active: true, ready: true));
      final routes = router(tester);
      unawaited(routes.push(AppRoutes.settings));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watch connection'));
      await tester.pumpAndSettle();
      expect(find.text('Saved watches'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('Cancel connection'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Companion prototype'), findsNothing);
      expect(find.text('Connection setup'), findsNothing);
      expect(calls.every((c) => c.method == 'permissionStatus'), isTrue);
      expect(permissionRequests, 0);

      routes.pop();
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(calls.every((c) => c.method == 'permissionStatus'), isTrue);
      await tester.tap(find.text('Watch connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['permissionStatus', 'stop']);
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
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
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

  testWidgets('unmigrated legacy voice-memo DB detail links stay unavailable', (
    tester,
  ) async {
    await mount(tester, snapshot(active: true, ready: true));
    final routes = router(tester);
    for (final path in [AppRoutes.voiceMemoDetail(12)]) {
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
  });

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
  testWidgets('Ready transitions preserve an open Voice route above disconnected Home', (tester) async {
    await mount(tester, snapshot());
    final routes = router(tester);
    unawaited(routes.push<void>(AppRoutes.voiceMemos));
    await tester.pumpAndSettle();
    expect(find.text('Voice Notes'), findsOneWidget);
    await emit(tester, snapshot(active: true, ready: true));
    await tester.pumpAndSettle();
    expect(find.text('Voice Notes'), findsOneWidget);
    await emit(tester, {...snapshot(active: true), 'phase': 'disconnected'});
    await tester.pumpAndSettle();
    await emit(tester, snapshot(active: true, ready: true));
    await tester.pumpAndSettle();
    expect(find.text('Voice Notes'), findsOneWidget);
    expect(calls.where((c) => c.method == 'start' || c.method == 'stop'), isEmpty);
    expect(forbidden, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

}
