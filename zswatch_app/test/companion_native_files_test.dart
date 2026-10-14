import 'dart:async';
import 'dart:io';

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
  test('listing omits optional path instead of encoding a native null', () async {
    const client = CompanionPrototypeClient();
    final result = await client.inspectLogs(8);
    expect(result.files.single.path, '/user/logs/log0000');
    expect(calls.single.arguments, {'version': 1, 'generation': 8});
  });
  test('download sends the selected validated path', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(bytes: Uint8List.fromList([1, 2]));
    });
    const client = CompanionPrototypeClient();
    final result = await client.inspectLogs(8, path: '/user/logs/log0000');
    expect(result.bytes, [1, 2]);
    expect((calls.single.arguments as Map)['path'], '/user/logs/log0000');
  });
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
  test(
    'native refresh rereads same-size files and isolates each selected watch',
    () async {
      final dir = Directory.systemTemp.createTempSync('zsw-native-logs-');
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(paths, (call) async => dir.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(paths, null);
        dir.deleteSync(recursive: true);
      });
      var content = Uint8List.fromList([65, 66]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepareShell') {
          return {'version': 1, 'generation': 8, 'prepared_from_generation': 7};
        }
        return reply(
          bytes: (call.arguments as Map)['path'] == null ? null : content,
        );
      });
      final snapshots = StreamController<CompanionPrototypeSnapshot>();
      final container = ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => snapshots.stream),
          watchServiceProvider.overrideWith(
            (ref) => throw StateError('Legacy BLE'),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(snapshots.close);
      snapshots.add(ready);
      await container.read(companionSnapshotProvider.future);
      final observation = container.listen(fileSystemProvider, (_, _) {});
      addTearDown(observation.close);
      final first = container.read(fileSystemProvider.notifier);
      await first.refreshLogs();
      await first.downloadFile(first.state.logFiles.single);
      final firstPath = first.state.downloadedPaths.values.single;
      expect(await File(firstPath).readAsBytes(), [65, 66]);
      content = Uint8List.fromList([67, 68]);
      await first.refreshLogs();
      expect(first.state.downloadedPaths, isEmpty);
      await first.downloadFile(first.state.logFiles.single);
      expect(await File(firstPath).readAsBytes(), [67, 68]);
      snapshots.add(
        CompanionPrototypeSnapshot.decode({...ready.fields, 'generation': 8}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(fileSystemProvider.notifier), same(first));
      snapshots.add(
        CompanionPrototypeSnapshot.decode({
          ...ready.fields,
          'address': '11:22:33:44:55:66',
        }),
      );
      await Future<void>.delayed(Duration.zero);
      final second = container.read(fileSystemProvider.notifier);
      expect(second, isNot(same(first)));
      expect(second.state.downloadedPaths, isEmpty);
      content = Uint8List.fromList([69, 70]);
      await second.refreshLogs();
      await second.downloadFile(second.state.logFiles.single);
      final secondPath = second.state.downloadedPaths.values.single;
      expect(secondPath, isNot(firstPath));
      expect(await File(firstPath).readAsBytes(), [67, 68]);
      expect(await File(secondPath).readAsBytes(), [69, 70]);
    },
  );

  test(
    'watch replacement discards a late download before local file access',
    () async {
      final completed = Completer<Object?>();
      final started = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prepareShell') {
          return {'version': 1, 'generation': 8, 'prepared_from_generation': 7};
        }
        if ((call.arguments as Map)['path'] == null) return reply();
        started.complete();
        return completed.future;
      });
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      var localAccesses = 0;
      messenger.setMockMethodCallHandler(paths, (call) async {
        localAccesses++;
        throw StateError('Disposed download must not access local storage');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(paths, null));
      final snapshots = StreamController<CompanionPrototypeSnapshot>();
      final container = ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => snapshots.stream),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(snapshots.close);
      snapshots.add(ready);
      await container.read(companionSnapshotProvider.future);
      final observation = container.listen(fileSystemProvider, (_, _) {});
      addTearDown(observation.close);
      final first = container.read(fileSystemProvider.notifier);
      await first.refreshLogs();
      final downloading = first.downloadFile(first.state.logFiles.single);
      await started.future;
      snapshots.add(
        CompanionPrototypeSnapshot.decode({
          ...ready.fields,
          'address': '11:22:33:44:55:66',
        }),
      );
      await Future<void>.delayed(Duration.zero);
      final current = container.read(fileSystemProvider.notifier);
      expect(current, isNot(same(first)));
      completed.complete(reply(bytes: Uint8List.fromList([65, 66])));
      await downloading;
      expect(current.state.downloadedPaths, isEmpty);
      expect(localAccesses, 0);
    },
  );
}
