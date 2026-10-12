import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_http_status.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/http_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/settings/settings_screen.dart';

Map<String, Object?> fields({
  bool enabled = true,
  int cursor = 1,
  bool active = false,
}) => {
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': active,
  'protocol_ready': active,
  'phase': active ? 'ready' : 'stopped',
  'generation': 5,
  'event_cursor': cursor,
  'events': <Object?>[],
  'recordings': <String, Object?>{},
  'http_enabled': enabled,
  'http_pending_count': 0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  test(
    'old journals retain enabled default; absent owners have no live work or result',
    () {
      final old = fields()
        ..remove('http_enabled')
        ..remove('http_pending_count');
      final status = CompanionHttpStatus.decode(old);
      expect(status.enabled, true);
      expect(status.ready, false);
      expect(status.pendingCount, 0);
      final stale = {
        ...fields(),
        'http_pending_count': 2,
        'last_http': {'generation': 5, 'utc_ms': 123, 'outcome': 'written'},
      };
      expect(CompanionHttpStatus.decode(stale).pendingCount, 0);
      expect(CompanionHttpStatus.decode(stale).lastOutcome, null);
      expect(
        CompanionHttpStatus.decode({
          ...stale,
          'runtime_active': true,
          'generation': 6,
        }).lastOutcome,
        null,
      );
    },
  );

  test(
    'HTTP metadata validates types and does not project URL/body history',
    () {
      final live = {
        ...fields(active: true),
        'http_pending_count': 2,
        'last_http': {
          'generation': 5,
          'utc_ms': 123,
          'outcome': 'written',
          'url': 'PRIVATE_URL',
          'body': 'PRIVATE_BODY',
        },
      };
      final status = CompanionHttpStatus.decode(live);
      expect(status.ready, true);
      expect(status.pendingCount, 2);
      expect(status.lastOutcome, 'written');
      for (final invalid in [
        {...live, 'http_enabled': null},
        {...live, 'http_enabled': 'true'},
        {...live, 'http_pending_count': null},
        {...live, 'http_pending_count': 5},
        {...live, 'http_pending_count': -1},
        {...live, 'http_pending_count': 1.5},
        {
          ...live,
          'last_http': {
            'generation': 5,
            'utc_ms': 123,
            'outcome': 'PRIVATE_BODY',
          },
        },
        {
          ...live,
          'last_http': {'generation': '5', 'utc_ms': 123, 'outcome': 'written'},
        },
      ]) {
        expect(
          () => CompanionHttpStatus.decode(invalid),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'HTTP command requires the exact committed policy in its versioned response',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        if (call.method == 'permissionStatus') {
          return {
            'version': 1,
            'bluetooth': false,
            'notifications': false,
            'notification_access': false,
            'location': false,
            'background_location': false,
            'battery_exemption': false,
          };
        }
        calls.add(call);
        return fields(enabled: false, cursor: 2);
      });
      final result = await const CompanionPrototypeClient().configureHttp(
        false,
      );
      expect(result.fields['http_enabled'], false);
      expect(calls.single.method, 'configureHttp');
      expect(calls.single.arguments, {'version': 1, 'enabled': false});
      await expectLater(
        const CompanionPrototypeClient().configureHttp(true),
        throwsFormatException,
      );
      messenger.setMockMethodCallHandler(
        methods,
        (call) async => fields()..remove('http_enabled'),
      );
      await expectLater(
        const CompanionPrototypeClient().configureHttp(true),
        throwsFormatException,
      );
    },
  );

  test(
    'existing HTTP read providers use native metadata and guard the Dart executor/listener',
    () async {
      final container = ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(
              CompanionPrototypeSnapshot.decode({
                ...fields(active: true),
                'http_pending_count': 2,
              }),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(companionSnapshotProvider.future);
      expect(container.read(httpRelayEnabledProvider), true);
      expect(container.read(httpRelayPendingCountProvider), 2);
      expect(container.read(httpRelayRecentRequestsProvider), isEmpty);
      expect(() => container.read(httpRelayServiceProvider), throwsStateError);
      expect(() => container.read(httpRelayNotifierProvider), throwsStateError);
    },
  );

  Future<void> open(
    WidgetTester tester,
    Stream<CompanionPrototypeSnapshot> values,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => values),
          watchServiceProvider.overrideWith(
            (ref) => throw StateError('No Dart BLE'),
          ),
          httpRelayServiceProvider.overrideWith(
            (ref) => throw StateError('No Dart HTTP'),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'stopped Settings edits are durable commands; delayed stream cannot revert accepted policy',
    (tester) async {
      final values = StreamController<CompanionPrototypeSnapshot>.broadcast();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        if (call.method == 'permissionStatus') {
          return {
            'version': 1,
            'bluetooth': false,
            'notifications': false,
            'notification_access': false,
            'location': false,
            'background_location': false,
            'battery_exemption': false,
          };
        }
        calls.add(call);
        return fields(
          enabled: (call.arguments as Map)['enabled'] as bool,
          cursor: calls.length + 1,
        );
      });
      await open(tester, values.stream);
      values.add(CompanionPrototypeSnapshot.decode(fields()));
      await tester.pumpAndSettle();
      expect(find.text('Watch internet requests'), findsOneWidget);
      expect(find.text('Waiting for watch connection'), findsOneWidget);
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      // The old observation remains behind the acknowledged cursor.
      values.add(CompanionPrototypeSnapshot.decode(fields()));
      await tester.pumpAndSettle();
      expect(find.text('Internet requests off'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      values.add(
        CompanionPrototypeSnapshot.decode(fields(enabled: false, cursor: 2)),
      );
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      expect(calls.map((call) => call.method), [
        'configureHttp',
        'configureHttp',
      ]);
      expect(calls.map((call) => (call.arguments as Map)['enabled']), [
        false,
        true,
      ]);
      await tester.pumpWidget(const SizedBox());
      await values.close();
    },
  );

  testWidgets(
    'failed edits retain observed policy and hide private platform errors',
    (tester) async {
      final values = StreamController<CompanionPrototypeSnapshot>.broadcast();
      messenger.setMockMethodCallHandler(
        methods,
        (call) async =>
            throw PlatformException(code: 'IO', message: 'PRIVATE_URL'),
      );
      await open(tester, values.stream);
      values.add(CompanionPrototypeSnapshot.decode(fields()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      expect(find.text('Could not update internet requests'), findsOneWidget);
      expect(find.textContaining('PRIVATE_URL'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await values.close();
    },
  );

  testWidgets(
    'closing Settings during a command never stops ownership or updates disposed UI',
    (tester) async {
      final values = StreamController<CompanionPrototypeSnapshot>.broadcast();
      final result = Completer<Object?>();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        if (call.method == 'permissionStatus') {
          return {
            'version': 1,
            'bluetooth': false,
            'notifications': false,
            'notification_access': false,
            'location': false,
            'background_location': false,
            'battery_exemption': false,
          };
        }
        calls.add(call);
        return result.future;
      });
      await open(tester, values.stream);
      values.add(CompanionPrototypeSnapshot.decode(fields()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        null,
      );
      await tester.pumpWidget(const SizedBox());
      result.complete(fields(enabled: false, cursor: 2));
      await tester.pump();
      expect(calls.single.method, 'configureHttp');
      expect(tester.takeException(), null);
      await values.close();
    },
  );
}
