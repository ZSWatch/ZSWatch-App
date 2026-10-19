import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:zswatch_app/data/models/connection.dart';
import 'package:zswatch_app/data/models/voice_memo.dart';
import 'package:zswatch_app/data/repositories/voice_memo_repository.dart';
import 'package:zswatch_app/services/voice_memo/voice_memo_sync_service.dart';
import 'package:zswatch_app/services/watch_service.dart';

import 'zsw_opus_parser_test.dart' show buildZswOpusFile;

class FakeRepository implements VoiceMemoRepository {
  final VoiceMemo memo;
  final List<String> events;
  bool failCommit = false;
  bool downloaded = false;
  String? localPath;
  int upserts = 0;

  FakeRepository(this.memo, this.events);

  @override
  Future<void> upsertFromWatch({
    required String filename,
    required int timestampUtc,
    required int durationMs,
    required int sizeBytes,
  }) async {
    upserts++;
  }

  @override
  Future<List<VoiceMemo>> getUndownloadedMemos() async =>
      downloaded ? [] : [memo];

  @override
  Future<void> markDownloaded({
    required String filename,
    required String localFilePath,
  }) async {
    events.add('commit');
    expect(File(localFilePath).existsSync(), true);
    if (failCommit) throw StateError('Database commit failed');
    downloaded = true;
    localPath = localFilePath;
  }

  @override
  Future<void> updateConvertedPath({
    required String filename,
    required String convertedFilePath,
  }) async {}

  @override
  Future<void> markDeletedOnWatch(String filename) async =>
      events.add('deleted');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWatch implements WatchService {
  final messages = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final List<String> events;
  final VoiceMemo memo;
  final Future<void> Function()? beforeDelete;
  bool emptyList = false;

  FakeWatch(this.memo, this.events, {this.beforeDelete});

  @override
  Stream<Map<String, dynamic>> get incomingMessages => messages.stream;
  @override
  Stream<Connection> get connectionStream => const Stream.empty();
  @override
  bool get isConnected => true;
  @override
  int get connectionGeneration => 1;
  @override
  BluetoothDevice get device => BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF');
  @override
  Future<void> enableSmp() async {}
  @override
  Future<bool> rediscoverServices() async => true;
  @override
  Future<void> disableSmpIfConnectionUnchanged(int generation) async {}

  @override
  Future<void> sendVoiceMemoCommand(
    String action, {
    Map<String, dynamic>? extraData,
  }) async {
    if (action == 'list') {
      // Deliver before the send Future completes, as a fast watch can do.
      messages.add({
        't': 'voice_memo',
        'action': 'list_result',
        'recordings': emptyList
            ? <Map<String, Object>>[]
            : [
                {
                  'filename': memo.filename,
                  'timestamp': 1700000000,
                  'duration_ms': memo.durationMs,
                  'size_bytes': memo.sizeBytes,
                },
              ],
      });
    } else if (action == 'delete') {
      await beforeDelete?.call();
      events.add('delete');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFs implements FsManager {
  @override
  String remoteId = 'AA:BB:CC:DD:EE:FF';
  final callbacks = StreamController<DownloadCallback>.broadcast(sync: true);
  final Uint8List data;
  bool wrongPathFirst = false;
  bool failDownload = false;

  FakeFs(this.data);
  @override
  Stream<DownloadCallback> get downloadCallbacks => callbacks.stream;
  @override
  Future<int> status(String path) async => data.length;
  @override
  Future<void> download(String path) async {
    if (failDownload) {
      callbacks.add(OnDownloadFailed(path, 'Connection lost'));
    } else {
      if (wrongPathFirst) {
        callbacks.add(
          OnDownloadCompleted('/user/recordings/old.zsw_opus', Uint8List(1)),
        );
      }
      callbacks.add(OnDownloadCompleted(path, data));
      callbacks.add(
        OnDownloadCompleted(path, data),
      ); // Duplicate native callback.
    }
  }

  @override
  Future<void> kill() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late Uint8List original;
  late List<String> events;
  late FakeRepository repository;
  late FakeWatch watch;
  late FakeFs fs;
  VoiceMemoSyncService? service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('voice-sync-test-');
    original = buildZswOpusFile();
    events = [];
    final memo = VoiceMemo(
      id: 1,
      filename: 'fixture',
      timestampUtc: DateTime.utc(2023),
      durationMs: 100,
      sizeBytes: original.length,
    );
    repository = FakeRepository(memo, events);
    watch = FakeWatch(
      memo,
      events,
      beforeDelete: () async {
        expect(repository.downloaded, true);
        expect(await File(repository.localPath!).readAsBytes(), original);
      },
    );
    fs = FakeFs(original);
  });

  tearDown(() async {
    service?.dispose();
    service = null;
    await watch.messages.close();
    await fs.callbacks.close();
    await directory.delete(recursive: true);
  });

  VoiceMemoSyncService createService({
    Future<Directory> Function()? storage,
    Future<void> Function()? recovery,
  }) {
    return service = VoiceMemoSyncService(
      watchService: watch,
      repository: repository,
      fsManagerFactory: (_) => fs,
      documentsDirectory: storage ?? () async => directory,
      beforeSync: recovery,
    );
  }

  test('immediate list response is accepted before send returns', () async {
    repository.downloaded = true;
    final sync = createService();
    await sync.syncRecordings().timeout(const Duration(seconds: 1));
    expect(repository.upserts, 1);
    expect(sync.currentState.phase, VoiceMemoSyncPhase.completed);
  });

  test('sync waits for startup recovery before querying the watch', () async {
    repository.downloaded = true;
    final ready = Completer<void>();
    final sync = createService(recovery: () => ready.future);
    final pending = sync.syncRecordings();
    await Future<void>.delayed(Duration.zero);
    expect(repository.upserts, 0);
    expect(sync.currentState.phase, VoiceMemoSyncPhase.fetchingList);
    ready.complete();
    await pending;
    expect(repository.upserts, 1);
  });

  test(
    'disposing during startup recovery does not restart a closed sync service',
    () async {
      final ready = Completer<void>();
      final sync = createService(recovery: () => ready.future);
      final pending = sync.syncRecordings();
      await Future<void>.delayed(Duration.zero);
      sync.dispose();
      ready.complete();
      await pending;
      expect(repository.upserts, 0);
      expect(events, isEmpty);
    },
  );

  test(
    'failed startup recovery stops sync before transfer or deletion',
    () async {
      final sync = createService(
        recovery: () async {
          throw StateError('Database unavailable');
        },
      );
      await sync.syncRecordings();
      expect(sync.currentState.phase, VoiceMemoSyncPhase.failed);
      expect(repository.upserts, 0);
      expect(events, isEmpty);
    },
  );

  test(
    'missing local recording absent from watch is not blindly downloaded',
    () async {
      watch.emptyList = true;
      final sync = createService();
      await sync.syncRecordings().timeout(const Duration(seconds: 1));
      expect(sync.currentState.completedCount, 0);
      expect(events, isEmpty);
      expect(repository.downloaded, false);
    },
  );

  test(
    'immediate and duplicate download callbacks commit audio before watch cleanup',
    () async {
      final sync = createService();
      await sync.syncRecordings();
      expect(sync.currentState.completedCount, 1);
      expect(events, ['commit', 'delete', 'deleted']);
      expect(
        (await directory.list(recursive: true).toList()).any(
          (entry) => entry.path.contains('.voice-receipt-'),
        ),
        false,
      );
    },
  );

  test(
    'callback for another remote file cannot complete this receipt',
    () async {
      fs.wrongPathFirst = true;
      await createService().syncRecordings();
      expect(repository.downloaded, true);
      expect(events, ['commit', 'delete', 'deleted']);
    },
  );

  test('transfer failure preserves the watch copy', () async {
    fs.failDownload = true;
    await createService().syncRecordings();
    expect(events, isEmpty);
    expect(await directory.list().isEmpty, true);
  });

  test('truncated download is not committed or deleted', () async {
    await fs.callbacks.close();
    fs = FakeFs(Uint8List.sublistView(original, 0, original.length - 1));
    await createService().syncRecordings();
    expect(events, isEmpty);
    expect(await directory.list().isEmpty, true);
  });

  test('local storage failure preserves the watch copy', () async {
    await createService(
      storage: () async =>
          throw const FileSystemException('Storage unavailable'),
    ).syncRecordings();
    expect(events, isEmpty);
  });

  test(
    'metadata commit failure retains audio and preserves the watch copy',
    () async {
      repository.failCommit = true;
      await createService().syncRecordings();
      expect(events, ['commit']);
      expect(
        await File(
          '${directory.path}/voice_memos/fixture.zsw_opus',
        ).readAsBytes(),
        original,
      );
    },
  );
}
