import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/dashboard/companion_find_watch_button.dart';

Map<String, Object?> fields({bool ready = true}) => {
  'version': 1,
  'owner': 'android_service_native',
  'runtime_active': ready,
  'protocol_ready': ready,
  'phase': ready ? 'ready' : 'stopped',
  'generation': 7,
  'event_cursor': 1,
  'events': <Object?>[],
  'recordings': <String, Object?>{},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'find is a current-session explicit command with exact acceptance receipt',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {
          ...fields(),
          'find_receipt': {'generation': 7, 'accepted': true},
        };
      });
      await const CompanionPrototypeClient().findWatch(7);
      expect(calls.single.method, 'findWatch');
      expect(calls.single.arguments, {'version': 1, 'generation': 7});
      await expectLater(
        const CompanionPrototypeClient().findWatch(-1),
        throwsFormatException,
      );
      expect(calls, hasLength(1));
      for (final receipt in [
        null,
        {'generation': 6, 'accepted': true},
        {'generation': 7.0, 'accepted': true},
        {'generation': 7, 'accepted': false},
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => {...fields(), 'find_receipt': receipt},
        );
        await expectLater(
          const CompanionPrototypeClient().findWatch(7),
          throwsFormatException,
        );
      }
    },
  );

  Future<void> mount(WidgetTester tester, Map<String, Object?> value) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(CompanionPrototypeSnapshot.decode(value)),
          ),
          watchServiceProvider.overrideWith(
            (ref) => throw StateError('No Dart BLE owner'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CompanionFindWatchButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('stopped or non-Ready owners cannot start a burst', (
    tester,
  ) async {
    await mount(tester, fields(ready: false));
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    await mount(tester, {
      ...fields(),
      'protocol_ready': false,
      'phase': 'connecting',
    });
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'one native action survives UI disposal without a Dart stop timer',
    (tester) async {
      final calls = <MethodCall>[];
      final result = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return result.future;
      });
      await mount(tester, fields());
      await tester.tap(find.text('Find watch'));
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      result.complete({
        ...fields(),
        'find_receipt': {'generation': 7, 'accepted': true},
      });
      await tester.pump(const Duration(seconds: 12));
      expect(calls.map((call) => call.method), ['findWatch']);
      expect(calls.single.arguments, {'version': 1, 'generation': 7});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native rejection gives retry feedback without exposing platform details',
    (tester) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'COMMAND_FAILED',
          message: 'PRIVATE_NATIVE_DETAILS',
        );
      });
      await mount(tester, fields());
      await tester.tap(find.text('Find watch'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not start finding watch'),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE_NATIVE_DETAILS'), findsNothing);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
    },
  );
}
