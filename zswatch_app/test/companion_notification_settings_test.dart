import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_notification_status.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/notification_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/notifications/notification_settings_screen.dart';
import 'package:zswatch_app/ui/screens/developer/companion_prototype_app.dart';

Map<String, Object?> status({bool granted = true}) => {
  'version': 1,
  'access_granted': granted,
  'listener_connected': false,
  'apps': [
    {'packageName': 'com.zswatch.app', 'appName': 'ZSWatch'},
    {'packageName': 'com.example.messages', 'appName': 'Messages'},
  ],
};

Map<String, Object?> policy({bool enabled = true}) => {
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': false,
  'protocol_ready': false,
  'phase': 'stopped',
  'event_cursor': 1,
  'generation': 10,
  'events': <Object?>[],
  'recordings': <String, Object?>{},
  'notifications_enabled': enabled,
  'notification_blocked_packages': ['com.zswatch.app'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  test(
    'permission, live binding and app catalogue do not imply forwarding policy',
    () {
      final decoded = CompanionNotificationStatus.decode(status());
      expect(decoded.accessGranted, true);
      expect(decoded.listenerConnected, false);
      expect(decoded.apps.every((app) => !app.enabled), true);
      expect(() => decoded.apps.clear(), throwsUnsupportedError);
      for (final invalid in [
        {...status(), 'version': 2},
        {...status(), 'access_granted': null},
        {...status(), 'listener_connected': 'true'},
        {
          ...status(),
          'apps': List.filled(257, {
            'packageName': 'com.example',
            'appName': 'Example',
          }),
        },
        {
          ...status(),
          'apps': [
            {'packageName': '*', 'appName': 'All'},
          ],
        },
        {
          ...status(),
          'apps': [
            {'packageName': 'com.example', 'appName': null},
          ],
        },
        {
          ...status(),
          'apps': [
            {'packageName': 'com.example', 'appName': 'x' * 161},
          ],
        },
        {
          ...status(),
          'apps': List.filled(2, {
            'packageName': 'com.example',
            'appName': 'Example',
          }),
        },
      ]) {
        expect(
          () => CompanionNotificationStatus.decode(invalid),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'status uses the versioned read command and validates the native response',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return status();
      });
      final result = await const CompanionPrototypeClient()
          .notificationStatus();
      expect(result.apps.length, 2);
      expect(calls.single.method, 'notificationStatus');
      expect(calls.single.arguments, {'version': 1});
      messenger.setMockMethodCallHandler(
        methods,
        (call) async => {'version': 2},
      );
      await expectLater(
        const CompanionPrototypeClient().notificationStatus(),
        throwsFormatException,
      );
    },
  );

  Future<void> open(
    WidgetTester tester,
    Stream<CompanionPrototypeSnapshot> states,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => states),
          notificationForwardingProvider.overrideWith(
            (ref) => throw StateError('Unexpected Dart forwarding'),
          ),
          notificationServiceProvider.overrideWith(
            (ref) => throw StateError('Unexpected Dart listener'),
          ),
          watchServiceProvider.overrideWith(
            (ref) => throw StateError('Unexpected Dart BLE'),
          ),
        ],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'existing settings screen reads native policy; explicit edits preserve selections while stopped',
    (tester) async {
      final calls = <MethodCall>[];
      var saved = policy();
      final states = StreamController<CompanionPrototypeSnapshot>();
      addTearDown(() => unawaited(states.close()));
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        if (call.method == 'notificationStatus') return status();
        if (call.method == 'configureNotifications') {
          final args = call.arguments as Map;
          saved = {
            ...saved,
            'event_cursor': (saved['event_cursor'] as int) + 1,
            'notifications_enabled': args['enabled'],
            'notification_blocked_packages': args['blockedPackages'],
          };
          // Deliberately delay native stream delivery: the second edit must
          // retain the policy committed by the first command response.
          return saved;
        }
        throw StateError('Unexpected owner command ${call.method}');
      });
      states.add(CompanionPrototypeSnapshot.decode(saved));
      await open(tester, states.stream);
      expect(calls.map((c) => c.method), ['notificationStatus']);
      expect(find.text('Watch disconnected'), findsOneWidget);
      expect(find.text('Notification access granted'), findsOneWidget);
      expect(find.text('Notification listener disconnected'), findsOneWidget);
      expect(find.text('1 app blocked'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Messages'),
            )
            .value,
        true,
      );

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Messages'));
      await tester.pumpAndSettle();
      expect(calls.last.arguments, {
        'version': 1,
        'enabled': true,
        'blockedPackages': ['com.example.messages', 'com.zswatch.app'],
      });
      expect(find.text('2 apps blocked'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(calls.last.arguments, {
        'version': 1,
        'enabled': false,
        'blockedPackages': ['com.example.messages', 'com.zswatch.app'],
      });
      await tester.tap(find.byTooltip('Refresh notification apps'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'notificationStatus');
      expect(saved['notifications_enabled'], false);
      expect(saved['runtime_active'], false);
      expect(saved['generation'], 10);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'revoked permission permits disabling saved forwarding but blocks enabling; resume rereads access',
    (tester) async {
      var saved = policy();
      var granted = false;
      final calls = <MethodCall>[];
      final states = StreamController<CompanionPrototypeSnapshot>();
      addTearDown(() => unawaited(states.close()));
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        if (call.method == 'notificationStatus') {
          return status(granted: granted);
        }
        if (call.method == 'configureNotifications') {
          saved = {
            ...saved,
            'notifications_enabled': (call.arguments as Map)['enabled'],
          };
          states.add(CompanionPrototypeSnapshot.decode(saved));
          return saved;
        }
        if (call.method == 'requestNotificationAccess') {
          return {'version': 1, 'accepted': true};
        }
        throw StateError('Unexpected command');
      });
      states.add(CompanionPrototypeSnapshot.decode(saved));
      await open(tester, states.stream);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNotNull,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      await tester.tap(find.text('Grant notification access'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'requestNotificationAccess');
      granted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls.last.method, 'notificationStatus');
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNotNull,
      );
      expect(saved['notifications_enabled'], false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'failed access launch is shown without an uncaught platform exception or policy mutation',
    (tester) async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        if (call.method == 'notificationStatus') return status(granted: false);
        throw PlatformException(code: 'NO_SETTINGS');
      });
      await open(
        tester,
        Stream.value(CompanionPrototypeSnapshot.decode(policy(enabled: false))),
      );
      await tester.tap(find.text('Grant notification access'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open notification access settings'),
        findsOneWidget,
      );
      expect(calls, ['notificationStatus', 'requestNotificationAccess']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'developer toggle preserves blocked apps and synthetic actions require ZSWatch unblocked',
    (tester) async {
      final calls = <MethodCall>[];
      final saved = {
        ...policy(),
        'notification_blocked_packages': ['com.zswatch.app'],
      };
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return {
          ...saved,
          'notifications_enabled': (call.arguments as Map)['enabled'],
        };
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeCompanionRuntimeProvider.overrideWithValue(true),
            companionSnapshotProvider.overrideWith(
              (ref) => Stream.value(CompanionPrototypeSnapshot.decode(saved)),
            ),
          ],
          child: const CompanionPrototypeApp(),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(
        SwitchListTile,
        'Forward notifications',
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(calls.single.method, 'configureNotifications');
      expect(calls.single.arguments, {
        'version': 1,
        'enabled': false,
        'blockedPackages': ['com.zswatch.app'],
      });
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Post test notification'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'reopening settings rereads permission and app metadata in the same provider container',
    (tester) async {
      var granted = true;
      var reads = 0;
      messenger.setMockMethodCallHandler(methods, (call) async {
        expect(call.method, 'notificationStatus');
        reads++;
        return status(granted: granted);
      });
      final container = ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(CompanionPrototypeSnapshot.decode(policy())),
          ),
        ],
      );
      addTearDown(container.dispose);
      Widget page(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: child),
      );
      await tester.pumpWidget(page(const NotificationSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Notification access granted'), findsOneWidget);
      await tester.pumpWidget(page(const SizedBox()));
      await tester.pumpAndSettle();
      granted = false;
      await tester.pumpWidget(page(const NotificationSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Notification access required'), findsOneWidget);
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
