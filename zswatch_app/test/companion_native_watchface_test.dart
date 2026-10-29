import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_watchface_status.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/filesystem_providers.dart';
import 'package:zswatch_app/providers/watchface_background_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/watchface/watchface_background_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Map<String, Object?> operation(
    String phase, {
    String id = 'test-operation',
    String action = 'apply',
    bool uncertain = false,
  }) => {
    'id': id,
    'address': 'AA:BB:CC:DD:EE:FF',
    'generation': 8,
    'action': action,
    'phase': phase,
    'current': action == 'reset' ? 0 : 10,
    'total': action == 'reset' ? 0 : CompanionWatchfaceStatus.imageBytes,
    'name': 'Test',
    'error': phase == 'failed' ? 'interrupted' : null,
    'application_uncertain': uncertain,
  };
  CompanionPrototypeSnapshot snapshot({
    Map<String, Object?>? state,
    int generation = 7,
  }) => CompanionPrototypeSnapshot.decode({
    'version': 1,
    'generation': generation,
    'phase': 'ready',
    'desired_running': true,
    'owner': 'android_service_native',
    'runtime_active': true,
    'event_cursor': 0,
    'protocol_ready': true,
    'address': 'AA:BB:CC:DD:EE:FF',
    'recordings': <String, Object?>{},
    'events': <Object?>[],
    if (state != null) 'watchface_operation': state,
  });
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareShell') {
        return {'version': 1, 'generation': 8, 'prepared_from_generation': 7};
      }
      if (call.method == 'startWatchface' || call.method == 'resetWatchface') {
        return {
          'version': 1,
          'generation': (call.arguments as Map)['generation'],
          'id': 'test-operation',
          'accepted': true,
        };
      }
      throw StateError('Unexpected method');
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('iOS watchface receipts retain the CoreBluetooth UUID', () {
    final value = operation('uploading')
      ..['address'] = 'FE88C737-593F-DB9B-732D-E11FF4C463F5';
    final status = CompanionWatchfaceStatus.decode({
      'watchface_operation': value,
    });
    expect(status!.address, value['address']);
    expect(status.busy, isTrue);
  });

  test(
    'all existing built-in backgrounds satisfy the native image contract',
    () async {
      for (final bg in builtinBackgrounds) {
        final data = await rootBundle.load(bg.assetBinPath);
        CompanionWatchfaceStatus.validateImage(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      }
    },
  );
  test(
    'bad image name header length and generation never reach native owner',
    () async {
      const client = CompanionPrototypeClient();
      final data = await rootBundle.load(builtinBackgrounds.first.assetBinPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      for (final name in ['', 'x' * 65, 'bad\nname']) {
        await expectLater(
          client.startWatchface(7, bytes, name),
          throwsFormatException,
        );
      }
      await expectLater(
        client.startWatchface(-1, bytes, 'Test'),
        throwsFormatException,
      );
      await expectLater(
        client.startWatchface(7, Uint8List(3), 'Test'),
        throwsFormatException,
      );
      final corrupt = Uint8List.fromList(bytes)..[0] = 0;
      await expectLater(
        client.startWatchface(7, corrupt, 'Test'),
        throwsFormatException,
      );
      expect(calls, isEmpty);
    },
  );
  test(
    'native status rejects malformed metadata and foreign acceptance',
    () async {
      for (final change in [
        {'phase': 'unknown'},
        {'generation': 8.0},
        {'current': -1},
        {'total': 3},
        {'address': 'invalid'},
        {'application_uncertain': 1},
        {'action': 'delete'},
      ]) {
        expect(
          () => CompanionWatchfaceStatus.decode({
            'watchface_operation': {...operation('uploading'), ...change},
          }),
          throwsFormatException,
        );
      }
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'version': 1,
          'generation': 9,
          'id': 'test',
          'accepted': true,
        },
      );
      await expectLater(
        const CompanionPrototypeClient().resetWatchface(7),
        throwsFormatException,
      );
    },
  );
  test(
    'existing built-in upload prepares Nordic then accepts service-owned work without legacy BLE',
    () async {
      final states = StreamController<CompanionPrototypeSnapshot>();
      final container = ProviderContainer(
        overrides: [
          companionSnapshotProvider.overrideWith((ref) => states.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await states.close();
      });
      final ready = container.read(companionSnapshotProvider.future);
      states.add(snapshot());
      await ready;
      final notifier = container.read(watchfaceBackgroundProvider.notifier);
      await notifier.uploadBuiltin(builtinBackgrounds.first);
      expect(calls.map((c) => c.method), ['prepareShell', 'startWatchface']);
      final args = calls.last.arguments as Map;
      expect(args['generation'], 8);
      expect(
        (args['bytes'] as Uint8List).length,
        CompanionWatchfaceStatus.imageBytes,
      );
      expect(container.read(watchfaceBackgroundProvider).isUploading, true);
      states.add(snapshot(state: operation('applying'), generation: 8));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(watchfaceBackgroundProvider).isApplying, true);
      states.add(snapshot(state: operation('completed'), generation: 8));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(watchfaceBackgroundProvider).successMessage,
        'Background applied!',
      );
    },
  );
  test(
    'accepted upload completes when Flutter first sees only the terminal snapshot',
    () async {
      final states = StreamController<CompanionPrototypeSnapshot>();
      final container = ProviderContainer(
        overrides: [
          companionSnapshotProvider.overrideWith((ref) => states.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await states.close();
      });
      final ready = container.read(companionSnapshotProvider.future);
      states.add(snapshot());
      await ready;
      await container
          .read(watchfaceBackgroundProvider.notifier)
          .uploadBuiltin(builtinBackgrounds.first);
      expect(container.read(watchfaceBackgroundProvider).isUploading, true);
      states.add(snapshot(state: operation('completed'), generation: 8));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(watchfaceBackgroundProvider).isUploading, false);
      expect(
        container.read(watchfaceBackgroundProvider).successMessage,
        'Background applied!',
      );
    },
  );

  test(
    'UI disposal after upload acceptance sends no legacy cancel or apply command',
    () async {
      final accepted = Completer<Object?>();
      final entered = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        if (call.method == 'prepareShell') {
          return Future.value({
            'version': 1,
            'generation': 8,
            'prepared_from_generation': 7,
          });
        }
        entered.complete();
        return accepted.future;
      });
      final container = ProviderContainer(
        overrides: [
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(snapshot()),
          ),
        ],
      );
      await container.read(companionSnapshotProvider.future);
      final work = container
          .read(watchfaceBackgroundProvider.notifier)
          .uploadBuiltin(builtinBackgrounds.first);
      await entered.future;
      container.dispose();
      accepted.complete({
        'version': 1,
        'generation': 8,
        'id': 'test-operation',
        'accepted': true,
      });
      await work;
      expect(calls.map((c) => c.method), ['prepareShell', 'startWatchface']);
    },
  );

  test(
    'reset is native NUS-only and screen disposal cannot cancel accepted work',
    () async {
      final accepted = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return accepted.future;
      });
      final container = ProviderContainer(
        overrides: [
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(snapshot()),
          ),
        ],
      );
      await container.read(companionSnapshotProvider.future);
      final future = container
          .read(watchfaceBackgroundProvider.notifier)
          .resetToDefault();
      container.dispose();
      accepted.complete({
        'version': 1,
        'generation': 7,
        'id': 'test',
        'accepted': true,
      });
      await future;
      expect(calls.map((c) => c.method), ['resetWatchface']);
    },
  );
  testWidgets(
    'reattached existing gallery shows native progress without creating legacy FS or BLE',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          companionSnapshotProvider.overrideWith(
            (ref) => Stream.value(
              snapshot(state: operation('uploading'), generation: 8),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(companionSnapshotProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WatchfaceBackgroundScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(watchfaceBackgroundProvider).isUploading, true);
      expect(
        container.read(filesystemUploadStateProvider).bytesTransferred,
        10,
      );
      expect(find.textContaining('ETA calculating...'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets('process interruption remains visible when gallery reattaches', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        companionSnapshotProvider.overrideWith(
          (ref) => Stream.value(
            snapshot(
              state: operation('failed', uncertain: true),
              generation: 9,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(companionSnapshotProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WatchfaceBackgroundScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('previous background result is unknown'),
      findsOneWidget,
    );
    expect(calls, isEmpty);
  });
}
