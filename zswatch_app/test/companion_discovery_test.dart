import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zswatch_app/data/models/companion_watch_selection.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/connection/scan_screen.dart';

const address = 'AA:BB:CC:DD:EE:FF';
Map<String, Object?> selection() => {
  'version': 1,
  'associated': true,
  'address': address,
  'generation': 7,
};
CompanionPrototypeSnapshot state({bool active = false, bool running = false}) =>
    CompanionPrototypeSnapshot.decode({
      'version': 1,
      'owner': 'android_service_native',
      'runtime_active': active,
      'protocol_ready': false,
      'phase': active ? 'connecting' : 'stopped',
      'desired_running': running,
      'generation': 7,
      'event_cursor': 1,
      'events': <Object?>[],
      'recordings': <String, Object?>{},
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var permissions = 0;
  late Future<void> Function() requestPermissions;
  late Future<Object?> Function(MethodCall) handler;

  setUp(() {
    calls.clear();
    permissions = 0;
    requestPermissions = () async {
      permissions++;
    };
    handler = (call) async => call.method == 'discoverWatch'
        ? selection()
        : {'version': 1, 'accepted': true};
    messenger.setMockMethodCallHandler(methods, (call) {
      calls.add(call);
      return handler(call);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  Future<void> open(
    WidgetTester tester, {
    bool active = false,
    bool running = false,
    bool accessorySetup = false,
  }) async {
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(
              CompanionPrototypeSnapshot.decode({
                ...state(active: active, running: running).fields,
                if (accessorySetup) ...{
                  'owner': 'ios_companion_native',
                  'platform': 'ios',
                  'accessory_setup_available': true,
                },
              }),
            ),
          ),
          companionConnectionPermissionsProvider.overrideWithValue(
            () => requestPermissions(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'selection validates association, MAC and generation without claiming Ready',
    () {
      final value = CompanionWatchSelection.decode(selection());
      expect(value.address, address);
      expect(value.generation, 7);
      for (final patch in [
        {'version': 2},
        {'associated': false},
        {'associated': 'true'},
        {'address': address.toLowerCase()},
        {'address': 'bad'},
        {'generation': -1},
        {'generation': true},
        {'generation': 7.0},
      ]) {
        expect(
          () => CompanionWatchSelection.decode({...selection(), ...patch}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'client uses only versioned discovery and generation-fenced start commands',
    () async {
      final selected = await const CompanionPrototypeClient().discoverWatch();
      await const CompanionPrototypeClient().startDiscovered(selected);
      expect(calls.map((c) => c.method), ['discoverWatch', 'startDiscovered']);
      expect(calls.first.arguments, {'version': 1});
      expect(calls.last.arguments, {
        'version': 1,
        'address': address,
        'generation': 7,
      });
      handler = (_) async => {'version': 1, 'accepted': false};
      await expectLater(
        const CompanionPrototypeClient().startDiscovered(selected),
        throwsFormatException,
      );
      final count = calls.length;
      await expectLater(
        const CompanionPrototypeClient().startDiscovered(
          const CompanionWatchSelection('bad', 7),
        ),
        throwsFormatException,
      );
      expect(calls.length, count);
    },
  );

  testWidgets(
    'opening Add Watch starts nothing; explicit choice hands off once and returns home',
    (tester) async {
      await open(tester);
      expect(find.text('Add Watch'), findsOneWidget);
      expect(calls, isEmpty);
      expect(permissions, 0);
      final picked = Completer<Object?>();
      handler = (call) async => call.method == 'discoverWatch'
          ? await picked.future
          : {'version': 1, 'accepted': true};
      await tester.tap(find.text('Find watch'));
      await tester.pump();
      await tester.tap(find.text('Find watch'));
      await tester.pump();
      expect(permissions, 1);
      expect(calls.map((c) => c.method), ['discoverWatch']);
      picked.complete(selection());
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['discoverWatch', 'startDiscovered']);
      expect(calls.last.arguments, {
        'version': 1,
        'address': address,
        'generation': 7,
      });
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets('active owner and saved running intent disable discovery', (
    tester,
  ) async {
    for (final flags in [(true, true), (false, true)]) {
      await open(tester, active: flags.$1, running: flags.$2);
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((w) => w is FilledButton),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text('Disconnect your watch before adding another.'),
        findsOneWidget,
      );
      expect(calls, isEmpty);
      expect(permissions, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'denied permission and cancelled picker send no connection command',
    (tester) async {
      await open(tester);
      requestPermissions = () async {
        permissions++;
        throw StateError('PRIVATE_DENIAL');
      };
      await tester.tap(find.text('Find watch'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(
        find.text('Could not find or connect to your watch'),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE_DENIAL'), findsNothing);
      requestPermissions = () async {
        permissions++;
      };
      handler = (_) async =>
          throw PlatformException(code: 'CANCELLED', message: 'PRIVATE_CANCEL');
      await tester.tap(find.text('Find watch'));
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['discoverWatch']);
      expect(
        find.text('Could not find or connect to your watch'),
        findsNothing,
      );
      expect(find.textContaining('PRIVATE_CANCEL'), findsNothing);
    },
  );

  testWidgets(
    'view disposal before permission or picker completion cannot start or stop BLE',
    (tester) async {
      final permission = Completer<void>();
      requestPermissions = () => permission.future;
      await open(tester);
      await tester.tap(find.text('Find watch'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      permission.complete();
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(tester.takeException(), isNull);
      requestPermissions = () async {};
      final picked = Completer<Object?>();
      handler = (_) async => await picked.future;
      await open(tester);
      await tester.tap(find.text('Find watch'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      picked.complete(selection());
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['discoverWatch']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired selection remains on Add Watch and never falls back to unfenced Start',
    (tester) async {
      await open(tester);
      handler = (call) async {
        if (call.method == 'discoverWatch') return selection();
        throw PlatformException(
          code: 'START_FAILED',
          message: 'PRIVATE_EXPIRED',
        );
      };
      await tester.tap(find.text('Find watch'));
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['discoverWatch', 'startDiscovered']);
      expect(find.text('Add Watch'), findsOneWidget);
      expect(
        find.text('Could not find or connect to your watch'),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE_EXPIRED'), findsNothing);
    },
  );

  testWidgets(
    'iOS accessory picker replaces raw scanning and starts only after selection',
    (tester) async {
      const uuid = 'FE88C737-593F-DB9B-732D-E11FF4C463F5';
      final picked = Completer<Object?>();
      handler = (call) async => call.method == 'discoverWatch'
          ? await picked.future
          : {'version': 1, 'accepted': true};
      await open(tester, accessorySetup: true);
      expect(calls, isEmpty);
      await tester.tap(find.text('Find watch'));
      await tester.pump();
      expect(calls.map((c) => c.method), ['discoverWatch']);
      expect(permissions, 1);
      picked.complete({
        'version': 1,
        'platform': 'ios',
        'selected': true,
        'address': uuid,
        'generation': 7,
      });
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['discoverWatch', 'startDiscovered']);
      expect(calls.last.arguments, {
        'version': 1,
        'address': uuid,
        'generation': 7,
      });
      expect(find.text('Home'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'iOS Bluetooth denial offers Settings and retries without Start',
    (tester) async {
      const settings = MethodChannel(
        'flutter.baseflow.com/permissions/methods',
      );
      var settingsOpens = 0;
      messenger.setMockMethodCallHandler(settings, (call) async {
        expect(call.method, 'openAppSettings');
        settingsOpens++;
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(settings, null));
      var granted = false;
      requestPermissions =
          const CompanionPrototypeClient().requestIosConnectionPermissions;
      handler = (call) async {
        if (call.method == 'requestConnectionPermissions') {
          return {'version': 1, 'bluetooth': granted};
        }
        if (call.method == 'scanStart') {
          return {...state().fields, 'owner': 'ios_companion_native'};
        }
        throw StateError('Unexpected command ${call.method}');
      };
      await open(tester);
      expect(calls, isEmpty);
      await tester.tap(find.text('Find watch'));
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['requestConnectionPermissions']);
      expect(
        find.textContaining('Bluetooth access is disabled.'),
        findsOneWidget,
      );
      expect(find.text('Open iPhone Settings'), findsOneWidget);
      expect(settingsOpens, 0);
      await tester.tap(find.text('Open iPhone Settings'));
      await tester.pumpAndSettle();
      expect(settingsOpens, 1);
      expect(calls.length, 1);
      granted = true;
      await tester.tap(find.text('Find watch'));
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), [
        'requestConnectionPermissions',
        'requestConnectionPermissions',
        'scanStart',
      ]);
      expect(find.text('Open iPhone Settings'), findsNothing);
      expect(
        find.textContaining('Bluetooth access is disabled.'),
        findsNothing,
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
