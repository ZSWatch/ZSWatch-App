import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_firmware_status.dart';
import 'package:zswatch_app/data/models/dfu_state.dart';
import 'package:zswatch_app/data/models/filesystem_image.dart';
import 'package:zswatch_app/data/models/firmware_image.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/dfu_providers.dart';
import 'package:zswatch_app/providers/filesystem_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';
import 'package:zswatch_app/services/dfu/firmware_manager.dart';
import 'package:zswatch_app/ui/screens/firmware/firmware_update_screen.dart';

class FixtureFirmwareManager extends FirmwareManager {
  List<FirmwareImage> images;
  Completer<List<FirmwareImage>>? preparation;
  FilesystemImage? resourceImage;
  FixtureFirmwareManager(this.images);
  @override
  Future<ReleaseExtractionResult> loadLocalFile(String filePath) async =>
      ReleaseExtractionResult(
        firmwareImage: images.first,
        filesystemImage:
            resourceImage ??
            FilesystemImage.fromFile(filePath: filePath, size: 3),
      );
  @override
  Future<List<FirmwareImage>> prepareFirmware(FirmwareImage image) async =>
      preparation == null ? images : preparation!.future;
}

Map<String, Object?> firmware(
  String phase, {
  String id = 'native-dfu',
  int generation = 9,
  bool unknown = false,
  bool cancelled = false,
}) => {
  'id': id,
  'address': 'AA:BB:CC:DD:EE:FF',
  'generation': generation,
  'phase': phase,
  'current': 2,
  'total': 3,
  'cancel_requested': cancelled,
  'result_unknown': unknown,
  'error': phase == 'failed' ? 'boot_check_unavailable' : null,
  'targets': [
    {'index': 2, 'bytes': 3, 'hash': 'a' * 64},
  ],
};
CompanionPrototypeSnapshot snapshot({
  Map<String, Object?>? operation,
  int generation = 7,
  bool ready = true,
  bool active = true,
  String address = 'AA:BB:CC:DD:EE:FF',
}) => CompanionPrototypeSnapshot.decode({
  'version': 1,
  'owner': 'android_service_native',
  'generation': generation,
  'runtime_active': active,
  'protocol_ready': ready,
  'phase': ready ? 'ready' : 'upgrading',
  'event_cursor': 0,
  'recordings': <String, Object?>{},
  'events': <Object?>[],
  'address': address,
  'desired_running': true,
  'watch_info': {
    'address': address,
    'hardware_version': 'watchdk@1/nrf5340/cpuapp',
  },
  if (operation != null) 'firmware_operation': operation,
});

Uint8List resourceFixture() {
  final bytes = Uint8List(64);
  final b = ByteData.sublistView(bytes);
  b.setUint32(0, 0x0a0a0a0a, Endian.little);
  b.setUint32(4, 56, Endian.little);
  b.setUint32(8, 64, Endian.little);
  b.setUint32(12, 1, Endian.little);
  bytes.setRange(16, 24, 'font.bin'.codeUnits);
  b.setUint32(48, 0, Endian.little);
  b.setUint32(52, 4, Endian.little);
  b.setUint32(56, 0x12345678, Endian.little);
  b.setUint32(60, 0x0a0a0a0a, Endian.little);
  return bytes; // Never a physical resource flash artifact.
}

void main() {
  test(
    'iOS firmware status accepts only its UUID and retains uncertain outcomes',
    () {
      const uuid = 'FE88C737-593F-DB9B-732D-E11FF4C463F5';
      final fields = <String, Object?>{
        'owner': 'ios_companion_native',
        'firmware_operation': {
          ...firmware('failed', unknown: true),
          'address': uuid,
        },
      };
      final status = CompanionFirmwareStatus.decode(fields)!;
      expect(status.address, uuid);
      expect(status.resultUnknown, true);
      expect(status.dfuState.status, DfuStatus.failed);
      expect(
        () => CompanionFirmwareStatus.decode({
          ...fields,
          'owner': 'android_service_native',
        }),
        throwsFormatException,
      );
      expect(
        () => CompanionFirmwareStatus.decode({
          ...fields,
          'firmware_operation': {
            ...firmware('uploading'),
            'address': 'AA:BB:CC:DD:EE:FF',
          },
        }),
        throwsFormatException,
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.zswatch.app/companion_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late Directory folder;
  late FixtureFirmwareManager manager;
  setUp(() async {
    calls.clear();
    folder = await Directory.systemTemp.createTemp('native-firmware-ui-');
    final file = File('${folder.path}/external.bin');
    await file.writeAsBytes([
      1,
      2,
      3,
    ]); // UI fixture only, never sent to real SDK/watch.
    manager = FixtureFirmwareManager([
      FirmwareImage(
        name: 'external.bin',
        filePath: file.path,
        size: 3,
        slot: 2,
        board: 'watchdk@1/nrf5340/cpuapp',
      ),
    ]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'prepareShell':
          return {'version': 1, 'prepared_from_generation': 7, 'generation': 8};
        case 'startFirmware':
          return {
            'version': 1,
            'accepted': true,
            'id': 'native-dfu',
            'generation': 9,
          };
        case 'cancelFirmware':
          return {'version': 1, 'accepted': true};
        default:
          throw StateError('Unexpected ${call.method}');
      }
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await manager.dispose();
    await folder.delete(recursive: true);
  });

  ProviderContainer container(Stream<CompanionPrototypeSnapshot> states) =>
      ProviderContainer(
        overrides: [
          nativeCompanionRuntimeProvider.overrideWithValue(true),
          companionSnapshotProvider.overrideWith((ref) => states),
          firmwareManagerProvider.overrideWithValue(manager),
          dfuServiceProvider.overrideWith(
            (ref) => throw StateError('Legacy DFU created'),
          ),
          filesystemUploadServiceProvider.overrideWith(
            (ref) => throw StateError('Legacy FS created'),
          ),
          watchServiceProvider.overrideWith(
            (ref) => throw StateError('Legacy BLE created'),
          ),
        ],
      );
  Future<void> emit(
    ProviderContainer c,
    StreamController<CompanionPrototypeSnapshot> states,
    CompanionPrototypeSnapshot value,
  ) async {
    final pending = c.read(companionSnapshotProvider.future);
    states.add(value);
    await pending;
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'file manager distinguishes standalone resources from firmware without a device owner',
    () async {
      final file = File('${folder.path}/lvgl_resources_raw.bin');
      await file.writeAsBytes(resourceFixture());
      final realManager = FirmwareManager();
      addTearDown(realManager.dispose);
      final result = await realManager.loadLocalFile(file.path);
      expect(result.firmwareImage, isNull);
      expect(result.filesystemImage!.targetPath, '/S/full_fs');
      expect(result.filesystemImage!.size, 64);
      final firmware = await realManager.loadLocalFile(
        manager.images.first.filePath,
      );
      expect(firmware.firmwareImage, isNotNull);
      expect(firmware.filesystemImage, isNull);
    },
  );

  test(
    'image indices, byte limits and generation are checked before dispatch',
    () async {
      const client = CompanionPrototypeClient();
      for (final images in <List<CompanionFirmwareImage>>[
        [],
        [CompanionFirmwareImage(-1, Uint8List(3))],
        [CompanionFirmwareImage(3, Uint8List(3))],
        [CompanionFirmwareImage(0, Uint8List(0))],
        [
          CompanionFirmwareImage(
            0,
            Uint8List(CompanionFirmwareStatus.maxImageBytes + 1),
          ),
        ],
        [
          CompanionFirmwareImage(2, Uint8List(3)),
          CompanionFirmwareImage(2, Uint8List(3)),
        ],
      ]) {
        await expectLater(
          client.startFirmware(8, images),
          throwsFormatException,
        );
      }
      await expectLater(
        client.startFirmware(-1, [CompanionFirmwareImage(0, Uint8List(3))]),
        throwsFormatException,
      );
      await expectLater(client.cancelFirmware(''), throwsFormatException);
      expect(calls, isEmpty);
    },
  );
  test(
    'accepted generation must represent the exclusive native handoff',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'version': 1,
          'accepted': true,
          'id': 'native-dfu',
          'generation': 8,
        },
      );
      await expectLater(
        const CompanionPrototypeClient().startFirmware(8, [
          CompanionFirmwareImage(2, Uint8List(3)),
        ]),
        throwsFormatException,
      );
    },
  );
  test('malformed status cannot turn into verified success', () {
    for (final changes in [
      {'phase': 'other'},
      {'generation': 9.0},
      {'current': -1},
      {'total': CompanionFirmwareStatus.maxImageBytes + 1},
      {'address': 'invalid'},
      {'targets': <Object?>[]},
      {
        'targets': [
          {'index': 2, 'bytes': 3, 'hash': 'invalid'},
        ],
      },
      {'phase': 'completed', 'result_unknown': true},
      {'phase': 'completed', 'error': 'interrupted'},
      {'cancel_requested': 'yes'},
    ]) {
      expect(
        () => CompanionFirmwareStatus.decode({
          'firmware_operation': {...firmware('uploading'), ...changes},
        }),
        throwsFormatException,
      );
    }
  });
  test(
    'SDK completion is still reconnecting or verifying; unavailable network image is unverified',
    () {
      for (final phase in ['reconnecting', 'verifying']) {
        final status = CompanionFirmwareStatus.decode({
          'firmware_operation': firmware(phase),
        })!;
        expect(status.busy, true);
        expect(status.dfuState.status, DfuStatus.reconnecting);
        expect(status.canCancel, false);
      }
      final failed = CompanionFirmwareStatus.decode({
        'firmware_operation': firmware('failed', unknown: true),
      })!;
      expect(failed.dfuState.status, DfuStatus.failed);
      expect(failed.errorMessage, contains('installed firmware is unverified'));
      expect(failed.errorMessage, contains('every selected image'));
    },
  );
  test(
    'existing firmware preparation preserves single external image and acceptance stays busy',
    () async {
      final states = StreamController<CompanionPrototypeSnapshot>();
      final c = container(states.stream);
      addTearDown(() async {
        c.dispose();
        await states.close();
      });
      await emit(c, states, snapshot());
      final notifier = c.read(dfuNotifierProvider.notifier);
      await notifier.loadLocalFile(manager.images.first.filePath);
      await notifier.startUpdate();
      expect(calls.map((call) => call.method), [
        'prepareShell',
        'startFirmware',
      ]);
      final args = calls.last.arguments as Map;
      expect(args['generation'], 8);
      final payload = (args['images'] as List).single as Map;
      expect(payload['index'], 2);
      expect(payload['bytes'], Uint8List.fromList([1, 2, 3]));
      expect(c.read(dfuStateProvider).status, DfuStatus.preparing);
      expect(
        c.read(effectiveDfuOperationStateProvider).canStartFirmwareUpdate,
        false,
      );
      await emit(
        c,
        states,
        snapshot(
          operation: firmware('reconnecting'),
          generation: 10,
          ready: false,
        ),
      );
      expect(c.read(dfuStateProvider).status, DfuStatus.reconnecting);
      await emit(
        c,
        states,
        snapshot(operation: firmware('completed'), generation: 11),
      );
      expect(c.read(dfuStateProvider).status, DfuStatus.completed);
      notifier.reset();
      expect(c.read(dfuStateProvider).status, DfuStatus.idle);
      expect(calls.length, 2); // Reset only dismisses the UI receipt.
    },
  );
  test(
    'reattached UI derives running operation and reset cannot clear it',
    () async {
      final c = container(
        Stream.value(
          snapshot(
            operation: firmware('uploading'),
            ready: false,
            generation: 9,
          ),
        ),
      );
      addTearDown(c.dispose);
      await c.read(companionSnapshotProvider.future);
      final notifier = c.read(dfuNotifierProvider.notifier);
      notifier.reset();
      expect(c.read(dfuStateProvider).status, DfuStatus.uploading);
      expect(c.read(effectiveDfuOperationStateProvider).isUpdating, true);
      await notifier.startUpdate();
      c.dispose();
      expect(calls, isEmpty);
    },
  );
  test(
    'cached active DFU cannot claim a live firmware owner after process loss',
    () async {
      final c = container(
        Stream.value(
          snapshot(
            operation: firmware('uploading'),
            ready: false,
            active: false,
          ),
        ),
      );
      addTearDown(c.dispose);
      await c.read(companionSnapshotProvider.future);
      expect(c.read(dfuStateProvider).status, DfuStatus.failed);
      expect(
        c.read(dfuStateProvider).errorMessage,
        contains('background service is unavailable'),
      );
      await c.read(dfuNotifierProvider.notifier).startUpdate();
      expect(calls, isEmpty);
    },
  );

  test(
    'Nordic cancellation receipt waits for terminal status and critical phases never cancel',
    () async {
      final states = StreamController<CompanionPrototypeSnapshot>();
      final c = container(states.stream);
      addTearDown(() async {
        c.dispose();
        await states.close();
      });
      await emit(
        c,
        states,
        snapshot(operation: firmware('uploading'), ready: false),
      );
      await c.read(dfuNotifierProvider.notifier).cancel();
      expect(calls.single.method, 'cancelFirmware');
      expect(calls.single.arguments, {'version': 1, 'id': 'native-dfu'});
      expect(c.read(dfuStateProvider).status, DfuStatus.uploading);
      for (final phase in ['uploading', 'applying', 'rebooting', 'verifying']) {
        await emit(
          c,
          states,
          snapshot(operation: firmware(phase, cancelled: true), ready: false),
        );
        await c.read(dfuNotifierProvider.notifier).cancel();
      }
      expect(calls.length, 1);
    },
  );
  test(
    'resource-only and combined selections submit all payloads once to the native owner',
    () async {
      final resource = resourceFixture();
      final file = File('${folder.path}/lvgl_resources_raw.bin');
      await file.writeAsBytes(resource);
      manager.resourceImage = FilesystemImage.fromFile(
        filePath: file.path,
        size: resource.length,
      );
      for (final combined in [false, true]) {
        calls.clear();
        final c = container(Stream.value(snapshot()));
        await c.read(companionSnapshotProvider.future);
        final notifier = c.read(dfuNotifierProvider.notifier);
        await notifier.loadLocalFile(manager.images.first.filePath);
        if (combined) {
          await notifier.startBothUpdates();
        } else {
          await notifier.startFilesystemUpload();
        }
        expect(calls.map((call) => call.method), [
          'prepareShell',
          'startFirmware',
        ]);
        final args = calls.last.arguments as Map;
        expect(args['resources'], resource);
        expect((args['images'] as List).length, combined ? 1 : 0);
        expect(c.read(dfuStateProvider).status, DfuStatus.preparing);
        c.dispose();
        expect(
          calls.length,
          2,
        ); // UI disposal cannot sequence or cancel stage two.
      }
    },
  );
  test(
    'malformed resource envelope, changed size and target reject before native preparation',
    () async {
      final file = File('${folder.path}/lvgl_resources_raw.bin');
      await file.writeAsBytes(resourceFixture());
      final image = FilesystemImage.fromFile(filePath: file.path, size: 64);
      final c = container(Stream.value(snapshot()));
      addTearDown(c.dispose);
      await c.read(companionSnapshotProvider.future);
      final notifier = c.read(dfuNotifierProvider.notifier);
      for (final invalid in [
        image.copyWith(size: 65),
        image.copyWith(targetPath: '/user/bg.bin'),
      ]) {
        manager.resourceImage = invalid;
        await notifier.loadLocalFile(manager.images.first.filePath);
        await notifier.startFilesystemUpload();
        expect(c.read(dfuNotifierProvider).hasError, true);
      }
      manager.resourceImage = image;
      await file.writeAsBytes(Uint8List(64));
      await notifier.loadLocalFile(manager.images.first.filePath);
      await notifier.startBothUpdates();
      expect(c.read(dfuNotifierProvider).hasError, true);
      expect(calls, isEmpty);
    },
  );
  test(
    'reattached combined progress names both native stages and waits for verified postflight',
    () async {
      final states = StreamController<CompanionPrototypeSnapshot>();
      final c = container(states.stream);
      addTearDown(() async {
        c.dispose();
        await states.close();
      });
      Map<String, Object?> update(String phase, {bool verified = false}) => {
        ...firmware(phase),
        'current': 32,
        'total': 64,
        'resource': {'bytes': 64, 'hash': 'b' * 64},
        'resource_verified': verified,
      };
      await emit(
        c,
        states,
        snapshot(operation: update('resource_uploading'), ready: false),
      );
      expect(c.read(effectiveDfuOperationStateProvider).isBothUpdating, true);
      expect(c.read(effectiveDfuOperationStateProvider).currentStep, 1);
      expect(
        c.read(firmwareFilesystemStateProvider).status,
        FilesystemUploadStatus.uploading,
      );
      expect(
        c.read(companionFirmwareStatusProvider).valueOrNull!.canCancel,
        false,
      );
      await c.read(dfuNotifierProvider.notifier).cancel();
      await emit(
        c,
        states,
        snapshot(operation: update('resource_verifying'), ready: false),
      );
      expect(c.read(dfuStateProvider).status, DfuStatus.validating);
      expect(
        c.read(dfuStateProvider).currentImageName,
        'Verifying LVGL resources',
      );
      await emit(
        c,
        states,
        snapshot(operation: update('uploading', verified: true), ready: false),
      );
      expect(c.read(effectiveDfuOperationStateProvider).currentStep, 2);
      expect(
        c.read(firmwareFilesystemStateProvider).status,
        FilesystemUploadStatus.idle,
      );
      await c.read(dfuNotifierProvider.notifier).cancel();
      expect(calls, isEmpty);
      await emit(
        c,
        states,
        snapshot(operation: update('verifying', verified: true), ready: false),
      );
      expect(c.read(dfuStateProvider).status, DfuStatus.reconnecting);
      await emit(
        c,
        states,
        snapshot(operation: update('completed', verified: true)),
      );
      expect(c.read(dfuStateProvider).status, DfuStatus.completed);
    },
  );
  test(
    'Done dismisses the whole resource result and a later package remains visible',
    () async {
      final states = StreamController<CompanionPrototypeSnapshot>();
      final c = container(states.stream);
      addTearDown(() async {
        c.dispose();
        await states.close();
      });
      for (final phase in ['completed', 'failed']) {
        await emit(
          c,
          states,
          snapshot(
            operation: {
              ...firmware(
                phase,
                id: 'resource-$phase',
                unknown: phase == 'failed',
              ),
              'resource': {'bytes': 64, 'hash': 'b' * 64},
              'resource_verified': true,
            },
          ),
        );
        expect(
          c.read(firmwareFilesystemStateProvider).status,
          phase == 'completed'
              ? FilesystemUploadStatus.completed
              : FilesystemUploadStatus.failed,
        );
        c.read(dfuNotifierProvider.notifier).reset();
        await c
            .read(dfuNotifierProvider.notifier)
            .loadLocalFile(manager.images.first.filePath);
        expect(c.read(dfuStateProvider).status, DfuStatus.idle);
        expect(
          c.read(firmwareFilesystemStateProvider).status,
          FilesystemUploadStatus.idle,
        );
        expect(c.read(effectiveDfuOperationStateProvider).hasFirmware, true);
        expect(
          c.read(companionFirmwareStatusProvider).valueOrNull!.id,
          'resource-$phase',
        );
      }
      await emit(
        c,
        states,
        snapshot(
          ready: false,
          operation: {
            ...firmware('resource_uploading', id: 'next-package'),
            'resource': {'bytes': 64, 'hash': 'b' * 64},
            'resource_verified': false,
          },
        ),
      );
      c.read(dfuNotifierProvider.notifier).reset();
      expect(
        c.read(firmwareFilesystemStateProvider).status,
        FilesystemUploadStatus.uploading,
      );
      expect(c.read(dfuStateProvider).status.isInProgress, true);
      expect(
        calls,
        isEmpty,
      ); // UI dismissal leaves the native journal/work alone.
    },
  );
  test(
    'resource-only terminal status and malformed verification cannot invent successful firmware',
    () {
      final resource = {'bytes': 64, 'hash': 'b' * 64};
      final status = CompanionFirmwareStatus.decode({
        'firmware_operation': {
          ...firmware('resource_uploading'),
          'targets': <Object?>[],
          'resource': resource,
          'resource_verified': false,
        },
      })!;
      expect(status.busy, true);
      expect(status.indices, isEmpty);
      expect(status.canCancel, false);
      for (final change in [
        {
          'resource': {'bytes': 63, 'hash': 'b' * 64},
        },
        {'resource_verified': 'yes'},
        {'phase': 'completed', 'resource_verified': false},
      ]) {
        expect(
          () => CompanionFirmwareStatus.decode({
            'firmware_operation': {
              ...firmware('resource_verifying'),
              'resource': resource,
              'resource_verified': false,
              ...change,
            },
          }),
          throwsFormatException,
        );
      }
      for (final bytes in [
        Uint8List(0),
        Uint8List(64),
        Uint8List(CompanionFirmwareStatus.maxImageBytes + 4),
      ]) {
        expect(
          () => CompanionResourceTarget.validatePayload(bytes),
          throwsFormatException,
        );
      }
    },
  );
  test('Nordic default WatchDK manifest matches revision 1 but rejects other revisions', () async {
    final c = container(Stream.value(snapshot()));
    addTearDown(c.dispose);
    await c.read(companionSnapshotProvider.future);
    final notifier = c.read(dfuNotifierProvider.notifier);
    final original = manager.images.single;
    manager.images = [original.copyWith(board: 'watchdk')];
    await notifier.loadLocalFile(original.filePath);
    await notifier.startUpdate();
    expect(c.read(dfuNotifierProvider).hasError, false);
    expect(calls.map((call) => call.method), ['prepareShell', 'startFirmware']);
  });

  test(
    'board mismatch, duplicate indices, ambiguous package and changed file reject before preparing SMP',
    () async {
      final c = container(Stream.value(snapshot()));
      addTearDown(c.dispose);
      await c.read(companionSnapshotProvider.future);
      final notifier = c.read(dfuNotifierProvider.notifier);
      final original = manager.images.single;
      for (final images in [
        [original.copyWith(board: 'zswatch@5/nrf5340/cpuapp')],
        [original.copyWith(board: 'watchdk@2/nrf5340/cpuapp')],
        [original.copyWith(board: 'zswatch')],
        [original, original],
        [original.copyWith(slot: null), original.copyWith(slot: null)],
        [original.copyWith(size: 4)],
      ]) {
        manager.images = images;
        await notifier.loadLocalFile(original.filePath);
        await notifier.startUpdate();
        expect(c.read(dfuNotifierProvider).hasError, true);
        expect(c.read(dfuNotifierProvider).isUpdating, false);
      }
      expect(calls, isEmpty);
    },
  );
  test(
    'connection change during local preparation never dispatches update',
    () async {
      final states = StreamController<CompanionPrototypeSnapshot>();
      final c = container(states.stream);
      addTearDown(() async {
        c.dispose();
        await states.close();
      });
      await emit(c, states, snapshot());
      final notifier = c.read(dfuNotifierProvider.notifier);
      await notifier.loadLocalFile(manager.images.first.filePath);
      manager.preparation = Completer();
      final update = notifier.startUpdate();
      await emit(c, states, snapshot(generation: 8));
      manager.preparation!.complete(manager.images);
      await update;
      expect(c.read(dfuNotifierProvider).error, contains('connection changed'));
      expect(calls, isEmpty);
    },
  );
  test('lost start receipt cannot produce idle or automatic retry', () async {
    final c = container(Stream.value(snapshot()));
    addTearDown(c.dispose);
    await c.read(companionSnapshotProvider.future);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'prepareShell') {
        return {'version': 1, 'generation': 8, 'prepared_from_generation': 7};
      }
      throw const FormatException('Lost receipt');
    });
    final notifier = c.read(dfuNotifierProvider.notifier);
    await notifier.loadLocalFile(manager.images.first.filePath);
    await notifier.startUpdate();
    expect(c.read(dfuStateProvider).status, DfuStatus.failed);
    expect(
      c.read(dfuStateProvider).errorMessage,
      contains('acceptance is unknown'),
    );
    await notifier.startUpdate();
    expect(calls.map((call) => call.method), ['prepareShell', 'startFirmware']);
  });
  test(
    'status errors and foreign watch receipts do not show verified success',
    () async {
      final states = StreamController<CompanionPrototypeSnapshot>();
      final c = container(states.stream);
      addTearDown(() async {
        c.dispose();
        await states.close();
      });
      await emit(
        c,
        states,
        snapshot(
          operation: firmware('completed'),
          address: '11:22:33:44:55:66',
        ),
      );
      expect(c.read(dfuStateProvider).status, DfuStatus.idle);
      states.addError(StateError('Observer failed'));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(dfuStateProvider).status, DfuStatus.failed);
    },
  );
  testWidgets(
    'existing screen reattaches to native upgrade without legacy DFU, BLE or filesystem',
    (tester) async {
      final c = container(
        Stream.value(
          snapshot(
            operation: firmware('uploading'),
            ready: false,
            generation: 9,
          ),
        ),
      );
      addTearDown(c.dispose);
      await c.read(companionSnapshotProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: FirmwareUpdateScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Firmware Update'), findsOneWidget);
      expect(find.text('Uploading...'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(c.read(dfuStateProvider).status, DfuStatus.uploading);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls, isEmpty);
    },
  );
  testWidgets('native upload cancellation remains visible until explicit UI dismissal', (tester) async {
    final c = container(Stream.value(snapshot(operation: firmware('cancelled', cancelled: true))));
    addTearDown(c.dispose);
    await c.read(companionSnapshotProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: FirmwareUpdateScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Update Cancelled'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('FW Update'), findsNothing);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(c.read(dfuStateProvider).status, DfuStatus.idle);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('resource-only completion names the filesystem outcome', (tester) async {
    final operation = firmware('completed')
      ..['targets'] = <Object?>[]
      ..['resource'] = {'bytes': 64, 'hash': 'b' * 64}
      ..['resource_verified'] = true;
    final c = container(Stream.value(snapshot(operation: operation)));
    addTearDown(c.dispose);
    await c.read(companionSnapshotProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: FirmwareUpdateScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Filesystem Upload Complete!'), findsOneWidget);
    expect(find.text('Update Complete!'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

}
