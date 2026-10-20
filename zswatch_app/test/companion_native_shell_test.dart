import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_shell_result.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/shell_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/developer/shell_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Map<String, Object?> reply() => {
    'version': 1,
    'generation': 7,
    'output': 'Active',
    'return_code': 0,
  };
  final ready = CompanionPrototypeSnapshot.decode({
    'version': 1,
    'generation': 7,
    'phase': 'ready',
    'desired_running': true,
    'owner': 'android_service_native',
    'runtime_active': true,
    'event_cursor': 0,
    'protocol_ready': true,
    'address': 'AA:BB:CC:DD:EE:FF',
    'recordings': <String, Object?>{},
    'events': <Object?>[],
  });

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareShell') {
        return {'version': 1, 'generation': 7, 'prepared_from_generation': 7};
      }
      if (call.method == 'executeShell') return reply();
      throw StateError('Unexpected method ${call.method}');
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('client sends a generation fence and validates its reply', () async {
    final result = await const CompanionPrototypeClient().executeShell(
      7,
      'power status',
    );
    expect(result.output, 'Active');
    expect(calls.single.arguments, {
      'version': 1,
      'generation': 7,
      'command': 'power status',
    });
  });

  test('invalid commands never reach the native owner', () async {
    const client = CompanionPrototypeClient();
    for (final command in ['', '  ', 'x' * 513, 'power\u0000status']) {
      await expectLater(client.executeShell(7, command), throwsFormatException);
    }
    await expectLater(
      client.executeShell(-1, 'power status'),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  test('foreign or malformed native replies are rejected', () {
    for (final change in [
      {'generation': 8},
      {'generation': 7.0},
      {'version': 2},
      {'output': false},
      {'return_code': 0.0},
      {'return_code': 2147483648},
      {'output': 'x' * 65537},
    ]) {
      expect(
        () => CompanionShellResult.decode({...reply(), ...change}, 7),
        throwsFormatException,
      );
    }
    expect(
      CompanionShellResult.decode({
        ...reply(),
        'return_code': -2,
      }, 7).returnCode,
      -2,
    );
  });

  testWidgets(
    'existing native shell screen and disposal never use legacy BLE',
    (tester) async {
      var legacy = 0;
      final container = ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => Stream.value(ready)),
          watchServiceProvider.overrideWith((ref) {
            legacy++;
            throw StateError('Legacy BLE owner');
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(companionSnapshotProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ShellScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final result = await container
          .read(shellServiceProvider)
          .execute('power status');
      expect(result.output, 'Active');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls.map((c) => c.method), ['prepareShell', 'executeShell']);
      expect(legacy, 0);
    },
  );

  test('UI shell disposal does not cancel a service-owned command', () async {
    final done = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      if (call.method == 'prepareShell') {
        return Future.value({
          'version': 1,
          'generation': 7,
          'prepared_from_generation': 7,
        });
      }
      return done.future;
    });
    final container = ProviderContainer(
      overrides: [
        nativeCompanionRuntimeProvider.overrideWithValue(true),
        companionSnapshotProvider.overrideWith((ref) => Stream.value(ready)),
      ],
    );
    await container.read(companionSnapshotProvider.future);
    final service = container.read(shellServiceProvider);
    final future = service.execute('power status');
    service.dispose();
    done.complete(reply());
    expect((await future).output, 'Active');
    expect(calls.map((c) => c.method), ['prepareShell', 'executeShell']);
    await expectLater(service.execute('power status'), throwsStateError);
    container.dispose();
  });

  test(
    'native provider prepares new handles before accepting a command',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'prepareShell') {
          return {'version': 1, 'generation': 8, 'prepared_from_generation': 7};
        }
        expect(call.method, 'executeShell');
        expect((call.arguments as Map)['generation'], 8);
        return {...reply(), 'generation': 8};
      });
      final container = ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => Stream.value(ready)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(companionSnapshotProvider.future);
      expect(
        (await container.read(shellServiceProvider).execute('power status'))
            .output,
        'Active',
      );
      expect(calls.map((c) => c.method), ['prepareShell', 'executeShell']);
    },
  );

  test('invalid preparation cannot admit or replay a shell command', () async {
    const client = CompanionPrototypeClient();
    for (final change in [
      {'generation': 9},
      {'generation': 6},
      {'generation': 7.0},
      {'prepared_from_generation': 8},
      {'prepared_from_generation': 7.0},
      {'version': 2},
    ]) {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'version': 1,
          'generation': 7,
          'prepared_from_generation': 7,
          ...change,
        },
      );
      await expectLater(client.prepareShell(7), throwsFormatException);
    }
    await expectLater(client.prepareShell(-1), throwsFormatException);
  });

  testWidgets('quick action retains its pending result through SMP reconnect', (
    tester,
  ) async {
    final states = StreamController<CompanionPrototypeSnapshot>.broadcast(
      sync: true,
    );
    final preparation = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareShell') return preparation.future;
      return {
        ...reply(),
        'generation': 8,
        'output': 'Power reply after reconnect',
      };
    });
    final container = ProviderContainer(
      overrides: [
        nativeCompanionRuntimeProvider.overrideWithValue(true),
        companionSnapshotProvider.overrideWith((ref) => states.stream),
        watchServiceProvider.overrideWith(
          (ref) => throw StateError('Legacy BLE owner'),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(states.close);
    final subscription = container.listen(companionSnapshotProvider, (_, _) {});
    addTearDown(subscription.close);
    states.add(ready);
    await container.read(companionSnapshotProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShellScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Power Status'));
    await tester.pump();
    states.add(
      CompanionPrototypeSnapshot.decode({
        ...ready.fields,
        'phase': 'disconnected',
        'protocol_ready': false,
      }),
    );
    await tester.pump();
    expect(find.text('Power Status'), findsOneWidget);
    expect(find.text('Watch not connected'), findsOneWidget);
    states.add(
      CompanionPrototypeSnapshot.decode({...ready.fields, 'generation': 8}),
    );
    await tester.pump();
    preparation.complete({
      'version': 1,
      'generation': 8,
      'prepared_from_generation': 7,
    });
    await tester.pumpAndSettle();
    expect(find.text('Power reply after reconnect'), findsOneWidget);
    expect(calls.map((c) => c.method), ['prepareShell', 'executeShell']);
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> openVoiceTest(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        nativeCompanionRuntimeProvider.overrideWithValue(true),
        companionSnapshotProvider.overrideWith((ref) => Stream.value(ready)),
        watchServiceProvider.overrideWith(
          (ref) => throw StateError('Legacy BLE owner'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(companionSnapshotProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShellScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick Actions'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Voice Memo Test (phone speaks)'),
      find.ancestor(
        of: find.text('Power Status'),
        matching: find.byType(ListView),
      ),
      const Offset(0, -400),
    );
    await tester.ensureVisible(find.text('Voice Memo Test (phone speaks)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voice Memo Test (phone speaks)'));
    await tester.pump();
  }

  List<Object?> voiceCommands() => calls
      .where((call) => call.method == 'executeShell')
      .map((call) => (call.arguments as Map)['command'])
      .toList();

  testWidgets('voice test stops after an uncertain start reply', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareShell') {
        return {'version': 1, 'generation': 7, 'prepared_from_generation': 7};
      }
      if ((call.arguments as Map)['command'] == 'voice_memo start') {
        throw PlatformException(code: 'transport', message: 'Reply lost');
      }
      return reply();
    });
    await openVoiceTest(tester);
    await tester.pumpAndSettle();
    expect(voiceCommands(), ['voice_memo start', 'voice_memo stop']);
    expect(find.textContaining('Start failed:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rejected voice start does not stop an existing recording', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareShell') {
        return {'version': 1, 'generation': 7, 'prepared_from_generation': 7};
      }
      return {...reply(), 'return_code': -1, 'output': 'Already recording'};
    });
    await openVoiceTest(tester);
    await tester.pumpAndSettle();
    expect(voiceCommands(), ['voice_memo start']);
    expect(find.text('Start failed: Already recording'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('voice cleanup preserves the speech error when stop also fails', (
    tester,
  ) async {
    const speech = MethodChannel('dev.zswatch.app/test_speech');
    messenger.setMockMethodCallHandler(speech, (_) async {
      throw PlatformException(code: 'speech', message: 'Engine unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(speech, null));
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareShell') {
        return {'version': 1, 'generation': 7, 'prepared_from_generation': 7};
      }
      if ((call.arguments as Map)['command'] == 'voice_memo stop') {
        throw PlatformException(code: 'transport', message: 'Stop reply lost');
      }
      return reply();
    });
    await openVoiceTest(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(voiceCommands(), ['voice_memo start', 'voice_memo stop']);
    expect(find.text('Speech failed: Engine unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stalled phone speech still attempts to stop the recording', (
    tester,
  ) async {
    const speech = MethodChannel('dev.zswatch.app/test_speech');
    final playback = Completer<Object?>();
    messenger.setMockMethodCallHandler(speech, (_) => playback.future);
    addTearDown(() => messenger.setMockMethodCallHandler(speech, null));
    await openVoiceTest(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 36));
    await tester.pumpAndSettle();
    expect(voiceCommands(), ['voice_memo start', 'voice_memo stop']);
    expect(
      find.textContaining('Speech failed: TimeoutException'),
      findsOneWidget,
    );
    playback.complete(null);
    await tester.pumpWidget(const SizedBox());
  });
}
