import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/models/companion_watchface_status.dart';
import 'package:zswatch_app/providers/companion_runtime_providers.dart';
import 'package:zswatch_app/providers/dfu_providers.dart';
import 'package:zswatch_app/providers/filesystem_providers.dart';
import 'package:zswatch_app/providers/transfer_progress_providers.dart';
import 'package:zswatch_app/providers/watch_service_provider.dart';
import 'package:zswatch_app/services/background/companion_prototype_client.dart';

CompanionPrototypeSnapshot transferSnapshot(
  String phase,
  int bytes, {
  bool watchface = false,
  bool resources = false,
  String id = 'transfer',
}) {
  const address = 'AA:BB:CC:DD:EE:FF';
  return CompanionPrototypeSnapshot.decode({
    'version': 1,
    'owner': 'android_service_native',
    'generation': 7,
    'address': address,
    'runtime_active': true,
    'protocol_ready': true,
    'phase': 'ready',
    'event_cursor': 0,
    'events': <Object?>[],
    'recordings': <String, Object?>{},
    (watchface ? 'watchface_operation' : 'firmware_operation'): {
      'id': id,
      'address': address,
      'generation': 7,
      'phase': phase,
      'current': bytes,
      'total': watchface ? CompanionWatchfaceStatus.imageBytes : 10000,
      if (watchface) ...{
        'name': 'Image',
        'action': 'apply',
        'application_uncertain': false,
      } else ...{
        'result_unknown': false,
        'cancel_requested': false,
        'targets': [
          {'index': 0, 'bytes': 10000, 'hash': 'a' * 64},
        ],
        if (resources) ...{
          'resource': {'bytes': 10000, 'hash': 'b' * 64},
          'resource_verified': false,
        },
      },
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('ticker expires a stalled rate and stops when cleared', (
    tester,
  ) async {
    var clock = Duration.zero;
    final notifier = NativeTransferRateNotifier(() => clock);
    notifier.observe('image', 1000, 10000);
    clock = const Duration(seconds: 1);
    notifier.observe('image', 2000, 10000);
    expect(notifier.state.bytesPerSecond, 1000);
    clock = const Duration(seconds: 7);
    await tester.pump(const Duration(seconds: 6));
    expect(notifier.state.bytesPerSecond, 0);
    expect(notifier.state.history.last, 0);
    notifier.clear();
    clock = const Duration(seconds: 8);
    await tester.pump(const Duration(seconds: 1));
    expect(notifier.state.history, isEmpty);
    notifier.dispose();
  });
  for (final phase in [
    'uploading',
    'resource_uploading',
    'resource_verifying',
    'watchface',
  ]) {
    test(
      '$phase projects native byte progress into live speed, chart and ETA',
      () async {
        var clock = Duration.zero;
        final states = StreamController<CompanionPrototypeSnapshot>();
        final container = ProviderContainer(
          overrides: [
            nativeCompanionRuntimeProvider.overrideWithValue(true),
            companionSnapshotProvider.overrideWith((ref) => states.stream),
            transferProgressClockProvider.overrideWithValue(() => clock),
            watchServiceProvider.overrideWith(
              (ref) => throw StateError('Legacy BLE created'),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await states.close();
        });
        final watchface = phase == 'watchface';
        final resources = phase.startsWith('resource_');
        final nativePhase = watchface ? 'uploading' : phase;
        if (watchface) {
          container.listen(filesystemUploadStateProvider, (_, _) {});
        } else {
          container.listen(dfuStateProvider, (_, _) {});
          container.listen(firmwareFilesystemStateProvider, (_, _) {});
        }
        Future<void> progress(
          int bytes, {
          String? nextPhase,
          String id = 'transfer',
        }) async {
          states.add(
            transferSnapshot(
              nextPhase ?? nativePhase,
              bytes,
              watchface: watchface,
              resources: resources,
              id: id,
            ),
          );
          await Future<void>.delayed(Duration.zero);
          await container.pump();
        }

        await progress(1000);
        clock = const Duration(seconds: 1);
        await progress(2000);
        if (watchface || resources) {
          final state = container.read(
            watchface
                ? filesystemUploadStateProvider
                : firmwareFilesystemStateProvider,
          );
          expect(state.speedBytesPerSecond, 1000);
          expect(state.speedHistory, [1000]);
          expect(state.formattedTimeRemaining, watchface ? '1:54' : '8s');
        } else {
          final state = container.read(dfuStateProvider);
          expect(state.speedBytesPerSecond, 1000);
          expect(state.speedHistory, [1000]);
          expect(state.formattedTimeRemaining, '8 sec');
        }
        clock = const Duration(seconds: 2);
        await progress(3000);
        final transfer = watchface
            ? NativeImageTransfer.watchface
            : NativeImageTransfer.firmware;
        expect(container.read(nativeTransferRateProvider(transfer)).history, [
          1000,
          1000,
        ]);
        // An image switch or explicit retry must never reuse the previous rate.
        clock = const Duration(seconds: 3);
        await progress(500, id: 'retry');
        expect(
          container.read(nativeTransferRateProvider(transfer)).bytesPerSecond,
          0,
        );
        expect(
          container.read(nativeTransferRateProvider(transfer)).history,
          isEmpty,
        );
        clock = const Duration(seconds: 4);
        await progress(1500, id: 'retry');
        expect(
          container.read(nativeTransferRateProvider(transfer)).bytesPerSecond,
          1000,
        );
        await progress(1500, nextPhase: 'applying', id: 'retry');
        expect(
          container.read(nativeTransferRateProvider(transfer)).history,
          isEmpty,
        );
      },
    );
  }
}
