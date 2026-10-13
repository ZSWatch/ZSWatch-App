import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/background/companion_prototype_client.dart';
import '../data/models/companion_recording.dart';
import '../data/models/companion_notification_status.dart';
import '../data/models/companion_http_status.dart';
import '../data/models/companion_gps_status.dart';
import '../data/models/companion_watchface_status.dart';
import 'watch_providers.dart' show databaseProvider;

/// Mobile UI observes the platform owner without creating a legacy BLE session.
bool get useNativeCompanionRuntime =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

final nativeCompanionRuntimeProvider = Provider<bool>((ref) {
  return useNativeCompanionRuntime;
});

final companionClientProvider = Provider<CompanionPrototypeClient>((ref) {
  return const CompanionPrototypeClient();
});

/// Only an opened result view reads private transcript/result content.
final companionVoiceJobProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, String>((ref, id) {
      ref.watch(
        companionSnapshotProvider.select((snapshot) {
          final rows = snapshot.asData?.value.fields['voice_jobs'];
          if (rows is! List) return '';
          final job = rows
              .whereType<Map<Object?, Object?>>()
              .where((row) => row['job_id'] == id)
              .firstOrNull;
          return '${job?['state']}:${job?['processing']}:${job?['transcript_saved']}:${job?['action_revision']}';
        }),
      );
      return ref.watch(companionClientProvider).voiceJob(id);
    });

final companionWatchfaceStatusProvider =
    Provider<AsyncValue<CompanionWatchfaceStatus?>>((ref) {
      return ref
          .watch(companionSnapshotProvider)
          .whenData(
            (snapshot) => CompanionWatchfaceStatus.decode(snapshot.fields),
          );
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
    final background = await Permission.locationAlways.request();
    if (!background.isGranted && defaultTargetPlatform != TargetPlatform.iOS) {
      throw StateError('Background location permission required');
    }
  };
});

/// Requested only by an explicit Connect action, never during app startup.
final companionConnectionPermissionsProvider =
    Provider<Future<void> Function()>((ref) {
      return () async {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await ref
              .read(companionClientProvider)
              .requestIosConnectionPermissions();
        } else {
          final status = await Permission.bluetoothConnect.request();
          if (!status.isGranted) {
            throw StateError('Bluetooth permission is required to connect');
          }
          await Permission.notification.request();
        }
        // Flutter owns schema creation/migrations. Initialize it before the
        // native owner can collect health/analytics while Flutter is absent.
        await ref
            .read(databaseProvider)
            .customSelect('SELECT 1 FROM watches LIMIT 1')
            .get();
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
  final subscription = ref.listen(companionSnapshotProvider, (previous, next) {
    if (values.isClosed) return;
    next.when(
      data: (snapshot) => values.add(project(snapshot)),
      error: values.addError,
      loading: () {},
    );
  }, fireImmediately: true);
  ref.onDispose(() {
    subscription.close();
    unawaited(values.close());
  });
  return values.stream;
}
