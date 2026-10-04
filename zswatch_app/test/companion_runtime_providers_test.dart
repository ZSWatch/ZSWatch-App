import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/connection_state.dart';
import 'package:zswatch_app/providers/ble_providers.dart' as ble;
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/watch_providers.dart' as database;
import 'package:zswatch_app/providers/watch_service_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Android selects native ownership without a build flag; iOS stays separate',
    () {
      final original = debugDefaultTargetPlatformOverride;
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(useNativeCompanionRuntime, isTrue);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(useNativeCompanionRuntime, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = original;
      }
    },
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('dev.zswatch.app/companion_v1');
  const events = MethodChannel('dev.zswatch.app/companion_events_v1');
  final calls = <MethodCall>[];
  final subscriptions = <String>[];
  late ProviderContainer container;
  var disposed = false;
  late Map<String, Object?> snapshot;

  Future<void> flush() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> emit(Map<String, Object?> value) async {
    await messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope(value),
      (_) {},
    );
    await flush();
  }

  setUp(() {
    disposed = false;
    calls.clear();
    subscriptions.clear();
    snapshot = {
      'version': 1,
      'owner': 'android_service_native',
      'runtime_active': true,
      'protocol_ready': true,
      'phase': 'ready',
      'event_cursor': 1,
      'generation': 7,
      'events': <Object?>[],
      'recordings': <String, Object?>{},
      'address': 'AA:BB:CC:DD:EE:FF',
      'att_payload_bytes': 244,
      'watch_info': {
        'address': 'AA:BB:CC:DD:EE:FF',
        'first_seen_ms': 1000,
        'firmware_version': '0.8.1',
        'hardware_version': 'watchdk',
        'battery_level': 87,
        'status_generation': 7,
      },
    };
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return call.method == 'start'
          ? {'version': 1, 'accepted': true}
          : snapshot;
    });
    messenger.setMockMethodCallHandler(events, (call) async {
      subscriptions.add(call.method);
      return null;
    });
    container = ProviderContainer(
      overrides: [
        nativeCompanionRuntimeProvider.overrideWithValue(true),
        database.allWatchesProvider.overrideWith((ref) => Stream.value([])),
        watchServiceProvider.overrideWith(
          (ref) => throw StateError('Legacy protocol instantiated'),
        ),
        database.databaseProvider.overrideWith(
          (ref) => throw StateError('Unexpected DB owner'),
        ),
      ],
    );
  });

  tearDown(() async {
    if (!disposed) container.dispose();
    await flush();
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test(
    'UI providers share one native observer with an injected catalogue and no legacy BLE',
    () async {
      container.listen(watchConnectionProvider, (_, _) {});
      container.listen(connectionPhaseProvider, (_, _) {});
      container.listen(currentWatchProvider, (_, _) {});
      container.listen(batteryLevelProvider, (_, _) {});
      container.listen(ble.currentConnectionProvider, (_, _) {});
      container.listen(watchInfoStreamProvider, (_, _) {});
      container.listen(watchConnectionStreamProvider, (_, _) {});
      container.listen(connectionPhaseStreamProvider, (_, _) {});
      await flush();
      expect(subscriptions, ['listen']);
      await emit(snapshot);
      expect(container.read(watchConnectionProvider).isConnected, true);
      expect(container.read(connectionPhaseProvider).canOperate, true);
      expect(container.read(currentWatchProvider)?.firmwareVersion, '0.8.1');
      expect(container.read(batteryLevelProvider), 87);
      expect(container.read(ble.currentConnectionProvider)?.mtu, 247);
      expect(container.read(hasSmpServiceProvider), false);
      expect(
        () => container.read(bleConnectionServiceProvider),
        throwsStateError,
      );
      expect(subscriptions, ['listen']);
      expect(calls, isEmpty);
      container.dispose();
      await flush();
      expect(subscriptions, ['listen', 'cancel']);
      expect(calls, isEmpty); // Detaching observers never sends Stop.
    },
  );

  test(
    'disconnect, new generation and observer errors cannot retain a connected or live battery view',
    () async {
      container.listen(watchConnectionProvider, (_, _) {});
      container.listen(batteryLevelProvider, (_, _) {});
      await flush();
      await emit(snapshot);
      expect(container.read(batteryLevelProvider), 87);
      await emit({
        ...snapshot,
        'generation': 8,
        'phase': 'connecting',
        'protocol_ready': false,
      });
      expect(
        container.read(watchConnectionProvider).state,
        WatchConnectionState.connecting,
      );
      expect(container.read(batteryLevelProvider), isNull);
      await emit({...snapshot, 'runtime_active': false});
      expect(container.read(watchConnectionProvider).isConnected, false);
      await emit(snapshot);
      await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeErrorEnvelope(
          code: 'SNAPSHOT_FAILED',
        ),
        (_) {},
      );
      await flush();
      expect(container.read(companionSnapshotProvider).hasError, true);
      expect(container.read(watchConnectionProvider).isConnected, false);
      expect(container.read(ble.currentConnectionProvider)?.isConnected, false);
      expect(container.read(currentWatchProvider), isNull);
      expect(container.read(batteryLevelProvider), isNull);
    },
  );

  test(
    'existing watch command notifier delegates exclusively to native service',
    () async {
      final notifier = container.read(watchNotifierProvider.notifier);
      await notifier.connectById('aa:bb:cc:dd:ee:ff');
      await notifier.requestDeviceInfo();
      await notifier.syncTime();
      await notifier.disconnect();
      expect(calls.map((c) => c.method), [
        'start',
        'requestDeviceInfo',
        'syncTime',
        'stop',
      ]);
      expect((calls.first.arguments as Map)['address'], 'AA:BB:CC:DD:EE:FF');
      expect(container.read(watchNotifierProvider).hasError, false);
      expect(subscriptions, isEmpty);
    },
  );
}
