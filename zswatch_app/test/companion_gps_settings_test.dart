import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zswatch_app/providers/companion_permission_setup_providers.dart';
import 'package:zswatch_app/providers/settings_providers.dart';
import 'package:zswatch_app/data/models/companion_gps_status.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/gps_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/settings/companion_gps_settings_tile.dart';

Map<String, Object?> fields({bool enabled = false, int cursor = 1}) => {
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': false,
  'protocol_ready': false,
  'phase': 'stopped',
  'generation': 7,
  'event_cursor': cursor,
  'events': <Object?>[],
  'recordings': <String, Object?>{},
  'gps_enabled': enabled,
  'gps_permissions': {'foreground': true, 'background': true, 'services': true},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'location consent enables sharing once and preserves a later off choice',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return fields(enabled: (call.arguments as Map?)?['enabled'] == true);
      });
      CompanionGpsSetup setup() => CompanionGpsSetup(
        const CompanionPrototypeClient(),
        () async => prefs,
      );
      final owner = setup();
      await owner.enableDefaultIfGranted({
        'location': true,
        'background_location': false,
      });
      expect(calls, isEmpty);
      const granted = {'location': true, 'background_location': true};
      await Future.wait([
        owner.enableDefaultIfGranted(granted),
        owner.enableDefaultIfGranted(granted),
      ]);
      expect(calls.map((call) => call.method), ['snapshot', 'configureGps']);
      expect((calls.last.arguments as Map)['enabled'], true);
      await owner.configure(false);
      expect((calls.last.arguments as Map)['enabled'], false);
      // A new owner represents restarting the app with permission still granted.
      await setup().enableDefaultIfGranted(granted);
      expect(
        calls.where((call) => call.method == 'configureGps'),
        hasLength(2),
      );
      expect(prefs.getBool(SettingsKeys.watchLocationDefaultApplied), true);
    },
  );

  test(
    'explicit off during a permission refresh wins over the default',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = Completer<Map<String, Object?>>();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'snapshot') return snapshot.future;
        return fields();
      });
      final owner = CompanionGpsSetup(
        const CompanionPrototypeClient(),
        () async => prefs,
      );
      final pending = owner.enableDefaultIfGranted({
        'location': true,
        'background_location': true,
      });
      await Future<void>.delayed(Duration.zero);
      await owner.configure(false);
      snapshot.complete(fields());
      await pending;
      expect(
        calls.where((call) => call.method == 'configureGps'),
        hasLength(1),
      );
      expect((calls.last.arguments as Map)['enabled'], false);
    },
  );

  test('failed permission default remains retryable', () async {
    final prefs = await SharedPreferences.getInstance();
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'configureGps' && ++attempts == 1) {
        throw PlatformException(code: 'LOCATION_SERVICES_OFF');
      }
      return fields(enabled: call.method == 'configureGps');
    });
    final owner = CompanionGpsSetup(
      const CompanionPrototypeClient(),
      () async => prefs,
    );
    const granted = {'location': true, 'background_location': true};
    await expectLater(
      owner.enableDefaultIfGranted(granted),
      throwsA(isA<PlatformException>()),
    );
    expect(prefs.getBool(SettingsKeys.watchLocationDefaultApplied), isNull);
    await owner.enableDefaultIfGranted(granted);
    expect(attempts, 2);
    expect(prefs.getBool(SettingsKeys.watchLocationDefaultApplied), true);
  });

  test(
    'old journals default to sharing off; stale active state is not live',
    () {
      final old = fields()
        ..remove('gps_enabled')
        ..remove('gps_permissions');
      expect(CompanionGpsStatus.decode(old).enabled, false);
      expect(CompanionGpsStatus.decode(old).backgroundPermission, false);
      final stale = fields(enabled: true)
        ..['gps_runtime'] = {
          'generation': 6,
          'state': 'acquiring',
          'requested': true,
        };
      expect(CompanionGpsStatus.decode(stale).state, 'idle');
      stale['runtime_active'] = true;
      stale['protocol_ready'] = true;
      expect(CompanionGpsStatus.decode(stale).state, 'idle');
      (stale['gps_runtime'] as Map)['generation'] = 7;
      expect(CompanionGpsStatus.decode(stale).state, 'acquiring');
    },
  );

  test(
    'location policy and runtime fields are typed; coordinates are not projected',
    () {
      for (final bad in [
        {...fields(), 'gps_enabled': 'true'},
        {
          ...fields(),
          'gps_permissions': {
            'foreground': 'true',
            'background': true,
            'services': true,
          },
        },
        {
          ...fields(),
          'gps_runtime': {
            'generation': 7,
            'state': 'unknown',
            'requested': true,
          },
        },
        {
          ...fields(),
          'gps_runtime': {
            'generation': 7.0,
            'state': 'idle',
            'requested': false,
          },
        },
      ]) {
        expect(() => CompanionGpsStatus.decode(bad), throwsFormatException);
      }
      final location = {
        ...fields(enabled: true),
        'latitude': 'PRIVATE',
        'longitude': 'PRIVATE',
      };
      expect(
        CompanionGpsStatus.decode(location).description,
        'Waiting for a watch location request',
      );
    },
  );

  test(
    'iOS When In Use location remains usable with an honest background label',
    () {
      final status = CompanionGpsStatus.decode({
        ...fields(enabled: true),
        'owner': 'ios_companion_native',
        'gps_permissions': {
          'foreground': true,
          'background': false,
          'services': true,
        },
      });
      expect(status.foregroundPermission, isTrue);
      expect(status.description, contains('while this app is open'));
      expect(status.description, contains('Always'));
      final denied = CompanionGpsStatus.decode({
        ...fields(enabled: true),
        'owner': 'ios_companion_native',
        'gps_permissions': {
          'foreground': false,
          'background': false,
          'services': true,
        },
      });
      expect(denied.description, 'Allow location access in iPhone settings');
    },
  );

  test(
    'configure uses native policy confirmation and cannot invent a commit',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return fields(enabled: true);
      });
      await const CompanionPrototypeClient().configureGps(true);
      expect(calls.single.method, 'configureGps');
      expect(calls.single.arguments, {'version': 1, 'enabled': true});
      await expectLater(
        const CompanionPrototypeClient().configureGps(false),
        throwsFormatException,
      );
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Stream<CompanionPrototypeSnapshot> stream,
    Future<void> Function() permission,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => stream),
          companionGpsPermissionsProvider.overrideWithValue(permission),
          gpsServiceProvider.overrideWith(
            (ref) => throw StateError('No Dart location acquisition'),
          ),
          watchServiceProvider.overrideWith(
            (ref) => throw StateError('No Dart BLE'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CompanionGpsSettingsTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cancelled opt-in sends neither a permission request nor native command',
    (tester) async {
      var permissions = 0;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return fields();
      });
      await mount(
        tester,
        Stream.value(CompanionPrototypeSnapshot.decode(fields())),
        () async {
          permissions++;
        },
      );
      await tester.tap(find.byKey(const ValueKey('companion-gps-switch')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Share location with your watch?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(permissions, 0);
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'explicit opt-in requests permission before committing; turning off needs no prompt',
    (tester) async {
      var permissions = 0;
      final calls = <MethodCall>[];
      final values = StreamController<CompanionPrototypeSnapshot>.broadcast();
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(permissions, 1);
        calls.add(call);
        return fields(
          enabled: (call.arguments as Map)['enabled'] as bool,
          cursor: calls.length + 1,
        );
      });
      await mount(tester, values.stream, () async {
        permissions++;
      });
      values.add(CompanionPrototypeSnapshot.decode(fields()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('companion-gps-switch')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('companion-gps-switch')))
            .value,
        true,
      );
      // An old observation cannot revert a committed command.
      values.add(CompanionPrototypeSnapshot.decode(fields()));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('companion-gps-switch')))
            .value,
        true,
      );
      await tester.tap(find.byKey(const ValueKey('companion-gps-switch')));
      await tester.pumpAndSettle();
      expect(permissions, 1);
      expect(calls.map((call) => (call.arguments as Map)['enabled']), [
        true,
        false,
      ]);
      await tester.pumpWidget(const SizedBox());
      await values.close();
    },
  );

  testWidgets(
    'denied background permission leaves policy off without sending a native command',
    (tester) async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return fields();
      });
      await mount(
        tester,
        Stream.value(CompanionPrototypeSnapshot.decode(fields())),
        () async {
          throw StateError('PRIVATE_PLATFORM_ERROR');
        },
      );
      await tester.tap(find.byKey(const ValueKey('companion-gps-switch')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.textContaining('PRIVATE_PLATFORM_ERROR'), findsNothing);
      expect(
        find.textContaining('Allow location all the time and turn on'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('companion-gps-switch')))
            .value,
        false,
      );
    },
  );
}
