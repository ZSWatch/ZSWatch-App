import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/background/companion_prototype_client.dart';
import '../data/models/companion_recording.dart';
import '../data/models/companion_notification_status.dart';
import '../data/models/companion_http_status.dart';
import '../data/models/companion_gps_status.dart';

/// Immutable selection for this app run. Native and Dart must not both own BLE.
bool get useNativeCompanionRuntime =>
    kDebugMode &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android &&
    const bool.fromEnvironment('COMPANION_RUNTIME_PROTOTYPE');

final nativeCompanionRuntimeProvider = Provider<bool>((ref) {
  return useNativeCompanionRuntime;
});

final companionClientProvider = Provider<CompanionPrototypeClient>((ref) {
  return const CompanionPrototypeClient();
});

final companionHttpStatusProvider = Provider<AsyncValue<CompanionHttpStatus>>((
  ref,
) {
  return ref
      .watch(companionSnapshotProvider)
      .whenData((snapshot) => CompanionHttpStatus.decode(snapshot.fields));
});

final companionGpsStatusProvider = Provider<AsyncValue<CompanionGpsStatus>>((
  ref,
) {
  return ref
      .watch(companionSnapshotProvider)
      .whenData((snapshot) => CompanionGpsStatus.decode(snapshot.fields));
});

/// Explicit UI opt-in only; native watch callbacks never open permission dialogs.
final companionGpsPermissionsProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    if (!(await Permission.locationWhenInUse.request()).isGranted) {
      throw StateError('Location permission required');
    }
    if (!(await Permission.locationAlways.request()).isGranted) {
      throw StateError('Background location permission required');
    }
  };
});

/// Requested only by an explicit Connect action, never during app startup.
final companionConnectionPermissionsProvider =
    Provider<Future<void> Function()>((ref) {
      return () async {
        final status = await Permission.bluetoothConnect.request();
        if (!status.isGranted) {
          throw StateError('Bluetooth permission is required to connect');
        }
        await Permission.notification.request();
      };
    });

final companionNotificationStatusProvider =
    FutureProvider.autoDispose<CompanionNotificationStatus>((ref) {
      if (!ref.watch(nativeCompanionRuntimeProvider)) {
        throw StateError('Native companion runtime is not selected');
      }
      return ref.watch(companionClientProvider).notificationStatus();
    });

/// Includes retained receipts from every watch; a screen selects its watch.
/// No DB row IDs are invented and no file/model services are started here.
final companionRecordingsProvider =
    Provider<AsyncValue<List<CompanionRecording>>>((ref) {
      return ref.watch(companionSnapshotProvider).whenData((snapshot) {
        final records = snapshot.recordings.entries
            .map((entry) => CompanionRecording.decode(entry.key, entry.value))
            .toList();
        records.sort((a, b) {
          final time = b.timestampUtc.compareTo(a.timestampUtc);
          return time != 0 ? time : a.identity.compareTo(b.identity);
        });
        return List<CompanionRecording>.unmodifiable(records);
      });
    });

/// One EventChannel subscription shared by all Flutter observers. Native emits
/// an initial snapshot on listen, so an additional read cannot race that stream.
/// Disposing Flutter observers cancels observation, never the service.
final companionSnapshotProvider = StreamProvider<CompanionPrototypeSnapshot>((
  ref,
) {
  if (!ref.watch(nativeCompanionRuntimeProvider)) {
    throw StateError('Native companion runtime is not selected');
  }
  final values = StreamController<CompanionPrototypeSnapshot>();
  final observer = ref
      .watch(companionClientProvider)
      .watch()
      .listen(values.add, onError: values.addError, onDone: values.close);
  // Cancel the platform subscription explicitly even if a consumer's pending
  // .future retains a listener while the provider is being disposed.
  ref.onDispose(() {
    unawaited(observer.cancel());
    unawaited(values.close());
  });
  return values.stream;
});

/// Adapts shared AsyncValue state to the existing StreamProvider APIs without
/// opening another platform subscription or using Riverpod's deprecated .stream.
Stream<T> companionValues<T>(
  Ref ref,
  T Function(CompanionPrototypeSnapshot) project,
) {
  final values = StreamController<T>();
  ref.listen(companionSnapshotProvider, (previous, next) {
    next.when(
      data: (snapshot) => values.add(project(snapshot)),
      error: values.addError,
      loading: () {},
    );
  }, fireImmediately: true);
  ref.onDispose(() => unawaited(values.close()));
  return values.stream;
}
