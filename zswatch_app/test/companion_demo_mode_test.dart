import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/companion_recording_import_providers.dart';
import 'package:zswatch_app/providers/demo_mode_provider.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/providers/ios_telemetry_providers.dart';
import 'package:zswatch_app/services/background/demo_companion_client.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';

const address = 'FE88C737-593F-DB9B-732D-E11FF4C463F5';
Map<String, Object?> realState({bool active = true, bool firmware = false}) => {
  ...DemoCompanionClient.state(true),
  'demo': false,
  'address': address,
  'runtime_active': active,
  if (firmware)
    'firmware_operation': {
      'id': 'fw',
      'address': address,
      'generation': 1,
      'phase': 'uploading',
      'current': 0,
      'total': 4,
      'cancel_requested': false,
      'result_unknown': false,
      'targets': [
        {'index': 0, 'bytes': 4, 'hash': 'a' * 64},
      ],
    },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late ProviderContainer container;
  late Map<String, Object?> state;
  final calls = <String>[];
  bool failStop = false;
  Completer<void>? stopGate;
  setUp(() {
    calls.clear();
    failStop = false;
    stopGate = null;
    state = realState();
    container = ProviderContainer(
      overrides: [nativeCompanionRuntimeProvider.overrideWithValue(true)],
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'snapshot') return state;
      if (call.method == 'stop') {
        expect(container.read(demoModeProvider), false);
        await stopGate?.future;
        if (failStop) throw PlatformException(code: 'storage_failure');
        state = realState(active: false);
        return state;
      }
      if (call.method == 'start') {
        expect(container.read(demoModeProvider), false);
        expect((call.arguments as Map)['address'], address);
        return {'version': 1, 'accepted': true};
      }
      fail('Unexpected real command ${call.method}');
    });
  });
  tearDown(() {
    container.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'stop is durable before preview; exit restores only the prior intent',
    () async {
      final controller = container.read(demoModeControllerProvider);
      stopGate = Completer<void>();
      final enter = controller.set(true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(demoModeBusyProvider), true);
      expect(container.read(demoModeProvider), false);
      await controller.set(
        true,
      ); // No duplicate Stop while transition is pending.
      stopGate!.complete();
      await enter;
      expect(calls, ['snapshot', 'stop']);
      expect(
        container.read(companionClientProvider),
        isA<DemoCompanionClient>(),
      );
      expect(container.read(watchConnectionProvider).isConnected, true);
      expect(container.read(currentWatchProvider)!.id, 'demo-device');
      final snapshot = await container.read(companionSnapshotProvider.future);
      expect(snapshot.runtimeActive, false);
      expect(snapshot.recordings, isEmpty);
      await controller.set(false);
      expect(calls, ['snapshot', 'stop', 'start']);
      expect(
        container.read(companionClientProvider),
        isNot(isA<DemoCompanionClient>()),
      );
    },
  );
  test('preview recording imports never open the real local ledger', () async {
    final isolated = ProviderContainer(
      overrides: [
        demoModeProvider.overrideWith((ref) => true),
        companionRecordingDatabaseProvider.overrideWith(
          (ref) =>
              throw StateError('Private import ledger opened in Demo Mode'),
        ),
      ],
    );
    addTearDown(isolated.dispose);
    expect(
      await isolated.read(companionRecordingImportsProvider.future),
      isEmpty,
    );
  });
  test('a stopped watch stays stopped after preview', () async {
    state = realState(active: false);
    final controller = container.read(demoModeControllerProvider);
    await controller.set(true);
    await controller.set(false);
    expect(calls, ['snapshot', 'stop']);
  });
  test('failed Stop never installs synthetic state', () async {
    failStop = true;
    await expectLater(
      container.read(demoModeControllerProvider).set(true),
      throwsA(isA<PlatformException>()),
    );
    expect(container.read(demoModeProvider), false);
    expect(container.read(demoModeBusyProvider), false);
  });
  test('firmware update is not interrupted by entry to preview', () async {
    state = realState(firmware: true);
    await expectLater(
      container.read(demoModeControllerProvider).set(true),
      throwsStateError,
    );
    expect(calls, ['snapshot']);
    expect(container.read(demoModeProvider), false);
  });
  test(
    'preview reads and separate event streams never reach the real platform',
    () async {
      await container.read(demoModeControllerProvider).set(true);
      calls.clear();
      final client = container.read(companionClientProvider);
      expect((await client.permissionStatus()).values.every((v) => !v), true);
      await client.notificationStatus();
      await client.sensorState();
      expect(await client.sensors().toList(), isEmpty);
      expect(await client.liveLogs().toList(), isEmpty);
      expect(await client.communicationTraffic().toList(), isEmpty);
      for (final command in ['stop', 'syncTime', 'requestRecordingList']) {
        await expectLater(
          client.command(command),
          throwsA(isA<PlatformException>()),
        );
      }
      await expectLater(
        client.start(address),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        client.setLogStreaming(true),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        client.requestIosConnectionPermissions(),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, isEmpty);
    },
  );
  test(
    'synthetic snapshots cannot project telemetry or acknowledge real receipts',
    () async {
      var projects = 0, acks = 0;
      final writer = IosTelemetryProjection(
        project: (_) async {
          projects++;
          return 1;
        },
        acknowledge: (_, _) async {
          acks++;
          return CompanionPrototypeSnapshot.decode(realState());
        },
      );
      writer.observe(
        CompanionPrototypeSnapshot.decode(DemoCompanionClient.state(true)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(projects, 0);
      expect(acks, 0);
      writer.dispose();
    },
  );
}
