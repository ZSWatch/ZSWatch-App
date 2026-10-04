import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_log_files.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/file_system_provider.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/ui/screens/developer/file_system_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Map<String, Object?> reply({Uint8List? bytes}) => {
    'version': 1,
    'generation': 8,
    'files': [
      {'path': '/user/logs/log0000', 'size_bytes': 2},
    ],
    'bytes': bytes,
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
        return {'version': 1, 'generation': 8, 'prepared_from_generation': 7};
      }
      if (call.method == 'inspectLogs') return reply();
      throw StateError('Unexpected method');
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'fixed paths and generation are validated before native access',
    () async {
      const client = CompanionPrototypeClient();
      for (final path in [
        '/user/logs/log0008',
        '/user/logs/../x',
        '/user/recordings/a',
      ]) {
        await expectLater(
          client.inspectLogs(7, path: path),
          throwsFormatException,
        );
      }
      await expectLater(client.inspectLogs(-1), throwsFormatException);
      expect(calls, isEmpty);
    },
  );
  test('malformed or foreign metadata is rejected', () {
    for (final value in [
      {...reply(), 'generation': 9},
      {...reply(), 'version': 2},
      {
        ...reply(),
        'files': [
          {'path': '/user/logs/log0000', 'size_bytes': -1},
        ],
      },
      {
        ...reply(),
        'files': [
          {'path': '/user/logs/../x', 'size_bytes': 2},
        ],
      },
      {
        ...reply(),
        'files': [...reply()['files'] as List, ...reply()['files'] as List],
      },
      reply(bytes: Uint8List(2)),
    ]) {
      expect(() => CompanionLogFiles.decode(value, 8), throwsFormatException);
    }
  });
  test('download path length and byte type must match validated metadata', () {
    expect(
      CompanionLogFiles.decode(
        reply(bytes: Uint8List.fromList([1, 2])),
        8,
        path: '/user/logs/log0000',
      ).bytes,
      [1, 2],
    );
    for (final value in [
      reply(),
      reply(bytes: Uint8List(1)),
      {
        ...reply(),
        'bytes': [1, 2],
      },
    ]) {
      expect(
        () => CompanionLogFiles.decode(value, 8, path: '/user/logs/log0000'),
        throwsFormatException,
      );
    }
    expect(
      () => CompanionLogFiles.decode(
        reply(bytes: Uint8List(2)),
        8,
        path: '/user/logs/log0001',
      ),
      throwsFormatException,
    );
  });
  testWidgets(
    'existing Files screen uses prepared native generation and no legacy BLE',
    (tester) async {
      var legacy = 0;
      final container = ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => Stream.value(ready)),
          watchServiceProvider.overrideWith((ref) {
            legacy++;
            throw StateError('Legacy BLE');
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(companionSnapshotProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FileSystemScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('log0000'), findsOneWidget);
      expect(find.text('2 B'), findsOneWidget);
      expect(legacy, 0);
      expect(calls.map((c) => c.method), ['prepareShell', 'inspectLogs']);
      expect((calls.last.arguments as Map)['generation'], 8);
    },
  );
  test(
    'disposed UI does not cancel service-owned inspection or update disposed state',
    () async {
      final done = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepareShell') {
          return {'version': 1, 'generation': 8, 'prepared_from_generation': 7};
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
      final notifier = container.read(fileSystemProvider.notifier);
      final future = notifier.refreshLogs();
      container.dispose();
      done.complete(reply());
      await future;
    },
  );
}
