import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/developer/companion_prototype_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  const eventControl = MethodChannel('dev.zswatch.app/companion_events_v1');
  const client = CompanionPrototypeClient();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final subscriptions = <MethodCall>[];
  late Map<String, Object?> saved;

  setUp(() {
    calls.clear();
    subscriptions.clear();
    saved = {
      'version': 1,
      'owner': 'android_service_native',
      'runtime_active': true,
      'protocol_ready': true,
      'phase': 'ready',
      'event_cursor': 4,
      'generation': 2,
      'address': 'AA:BB:CC:DD:EE:FF',
      'acked_cursor': 0,
      'event_gap': false,
      'events': [
        {'seq': 4, 'kind': 'recording_state'},
      ],
      'recordings': {
        'memo': {'state': 'downloaded', 'sha256': 'saved-hash'},
      },
    };
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'start') return {'version': 1, 'accepted': true};
      return saved;
    });
    messenger.setMockMethodCallHandler(eventControl, (call) async {
      subscriptions.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(eventControl, null);
  });

  test(
    'snapshot reattachment reads persisted events and recording receipt',
    () async {
      final first = await client.snapshot();
      final second = await const CompanionPrototypeClient().snapshot();
      expect(second.cursor, first.cursor);
      expect(second.generation, 2);
      expect(second.recordings['memo'], {
        'state': 'downloaded',
        'sha256': 'saved-hash',
      });
      expect(calls.map((call) => call.method), ['snapshot', 'snapshot']);
      expect(
        calls.every((call) => (call.arguments as Map)['version'] == 1),
        isTrue,
      );
    },
  );

  test(
    'start normalizes MAC and sends a versioned acceptance request',
    () async {
      await client.start(' aa:bb:cc:dd:ee:ff ');
      expect(calls.single.method, 'start');
      expect(calls.single.arguments, {
        'version': 1,
        'address': 'AA:BB:CC:DD:EE:FF',
      });
    },
  );

  test('invalid address never reaches the native owner', () async {
    await expectLater(client.start('watch UUID'), throwsFormatException);
    expect(calls, isEmpty);
  });

  test('unaccepted start and native permission errors propagate', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (_) async => {'version': 1, 'accepted': false},
    );
    await expectLater(client.start('AA:BB:CC:DD:EE:FF'), throwsFormatException);
    messenger.setMockMethodCallHandler(
      methods,
      (_) async => throw PlatformException(
        code: 'START_FAILED',
        message: 'permission required',
      ),
    );
    await expectLater(
      client.start('AA:BB:CC:DD:EE:FF'),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'version and incomplete snapshot cannot be mistaken for readiness',
    () async {
      for (final invalid in [
        saved..['version'] = 2,
        <String, Object?>{'version': 1},
        null,
      ]) {
        messenger.setMockMethodCallHandler(methods, (_) async => invalid);
        await expectLater(client.snapshot(), throwsFormatException);
      }
    },
  );

  test('acknowledgment and commands use v1 envelope', () async {
    await client.command('ackEvents', cursor: 4);
    await client.command('syncTime');
    await client.command('retryRecordings');
    await client.command('stop');
    expect(calls.first.arguments, {'version': 1, 'cursor': 4});
    expect(calls.map((call) => call.method), [
      'ackEvents',
      'syncTime',
      'retryRecordings',
      'stop',
    ]);
  });

  test('invalid cursor and unknown commands do not reach the owner', () async {
    await expectLater(client.command('ackEvents'), throwsFormatException);
    await expectLater(
      client.command('ackEvents', cursor: -1),
      throwsFormatException,
    );
    await expectLater(client.command('deleteRecording'), throwsFormatException);
    expect(calls, isEmpty);
  });

  test('event observer delivers snapshots and cancel sends no stop', () async {
    final delivered = <CompanionPrototypeSnapshot>[];
    final subscription = client.watch().listen(delivered.add);
    await Future<void>.delayed(Duration.zero);
    expect(subscriptions.single.method, 'listen');
    expect(subscriptions.single.arguments, {'version': 1});
    await messenger.handlePlatformMessage(
      eventControl.name,
      const StandardMethodCodec().encodeSuccessEnvelope(saved),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(delivered.single.cursor, 4);
    await subscription.cancel();
    expect(subscriptions.last.method, 'cancel');
    expect(calls, isEmpty);
  });

  testWidgets(
    'prototype UI detach and remount leave native receipts and owner alone',
    (tester) async {
      await tester.pumpWidget(const CompanionPrototypeApp());
      await tester.pumpAndSettle();
      expect(find.text('Companion prototype'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const CompanionPrototypeApp());
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['snapshot', 'snapshot']);
      expect(saved['runtime_active'], true);
      expect(
        ((saved['recordings']! as Map)['memo'] as Map)['state'],
        'downloaded',
      );
      expect(subscriptions.map((call) => call.method), [
        'listen',
        'cancel',
        'listen',
      ]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
