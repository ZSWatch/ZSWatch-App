import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/data/models/voice_memo.dart';
import 'package:zswatch_app/data/repositories/voice_memo_repository.dart';
import 'package:zswatch_app/services/voice_memo/voice_memo_file_store.dart';
import 'package:zswatch_app/services/voice_memo/voice_memo_recovery_service.dart';

import 'zsw_opus_parser_test.dart' show buildZswOpusFile;
import 'support/host_sqlite.dart';

void main() {
  configureHostSqlite();
  late Directory directory;
  late Directory voiceDirectory;
  late AppDatabase db;
  late VoiceMemoRepository repository;
  late Uint8List audio;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('voice-recovery-test-');
    voiceDirectory = await Directory('${directory.path}/voice_memos').create();
    db = AppDatabase.forTesting(
      NativeDatabase(File('${directory.path}/app.sqlite')),
    );
    repository = VoiceMemoRepository(db);
    audio = buildZswOpusFile();
    await repository.upsertFromWatch(
      filename: 'fixture',
      timestampUtc: 1700000000,
      durationMs: 100,
      sizeBytes: audio.length,
    );
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  File rawFile([String name = 'fixture']) =>
      File('${voiceDirectory.path}/$name.zsw_opus');

  Future<VoiceMemo> memo() async =>
      (await repository.getMemoByFilename('fixture'))!;

  Future<VoiceMemoRecoveryReport> recover() => VoiceMemoRecoveryService(
    repository: repository,
    documentsDirectory: () async => directory,
  ).recover();

  Future<Directory> stage(
    Uint8List bytes, {
    bool manifest = true,
    String destination = 'fixture.zsw_opus',
  }) async {
    final staging = await voiceDirectory.createTemp('.voice-receipt-');
    await File('${staging.path}/payload').writeAsBytes(bytes, flush: true);
    if (manifest) {
      await File('${staging.path}/receipt.json').writeAsString(
        jsonEncode({
          'version': 1,
          'destination': destination,
          'size_bytes': bytes.length,
        }),
        flush: true,
      );
    }
    return staging;
  }

  test(
    'published audio before DB commit is adopted and converted once',
    () async {
      await rawFile().writeAsBytes(audio, flush: true);
      final first = await recover();
      final repaired = await memo();
      expect(first.recoveredReceipts, 1);
      expect(first.rebuiltConversions, 1);
      expect(first.errors, isEmpty);
      expect(repaired.syncedFromWatch, true);
      expect(repaired.deletedOnWatch, false);
      expect(await File(repaired.localFilePath!).readAsBytes(), audio);
      expect(File(repaired.convertedFilePath!).existsSync(), true);
      final downloadedAt = repaired.downloadedAt;
      final second = await recover();
      expect(second.recoveredReceipts, 0);
      expect(second.rebuiltConversions, 0);
      expect((await memo()).downloadedAt, downloadedAt);
    },
  );

  test(
    'complete orphan stage is published before metadata and then cleaned',
    () async {
      final staged = await stage(audio);
      final result = await recover();
      expect(result.recoveredStages, 1);
      expect(result.recoveredReceipts, 1);
      expect(result.errors, isEmpty);
      expect(result.retainedFiles, isEmpty);
      expect(staged.existsSync(), false);
      expect(await rawFile().readAsBytes(), audio);
      expect((await memo()).syncedFromWatch, true);
    },
  );

  test(
    'incomplete legacy stage and unknown published recording are retained',
    () async {
      final staged = await stage(audio, manifest: false);
      final unknown = rawFile('unknown');
      await unknown.writeAsBytes(audio);
      final result = await recover();
      expect(result.recoveredReceipts, 0);
      expect(result.retainedFiles, containsAll([staged.path, unknown.path]));
      expect(await File('${staged.path}/payload').readAsBytes(), audio);
      expect(await unknown.readAsBytes(), audio);
      expect(await repository.getMemoByFilename('unknown'), isNull);
    },
  );

  test(
    'partial, dirty and unsupported-version data cannot be adopted',
    () async {
      for (final bytes in [
        Uint8List.sublistView(audio, 0, audio.length - 1),
        buildZswOpusFile(totalFrames: 0xFFFFFFFF),
        buildZswOpusFile(version: 2),
      ]) {
        await rawFile().writeAsBytes(bytes);
        final result = await recover();
        expect(result.recoveredReceipts, 0);
        expect((await memo()).syncedFromWatch, false);
        expect(await rawFile().readAsBytes(), bytes);
      }
    },
  );

  test(
    'same-length partial frame is retained instead of trusted by size',
    () async {
      final broken = Uint8List.fromList(audio);
      ByteData.sublistView(broken).setUint16(32, 65535, Endian.little);
      final staged = await stage(broken);
      expect((await recover()).recoveredStages, 0);
      expect(staged.existsSync(), true);
      expect((await memo()).syncedFromWatch, false);
    },
  );

  test(
    'wrong recording timestamp and ambiguous stages stay untouched',
    () async {
      final wrong = await stage(buildZswOpusFile(timestamp: 1700000001));
      expect((await recover()).recoveredStages, 0);
      expect(wrong.existsSync(), true);
      await wrong.delete(recursive: true);
      final one = await stage(audio);
      final changed = Uint8List.fromList(audio)..[34] = 99;
      final two = await stage(changed);
      final result = await recover();
      expect(result.recoveredStages, 0);
      expect(result.retainedFiles, containsAll([one.path, two.path]));
      expect(rawFile().existsSync(), false);
    },
  );

  test('recovery cannot touch a live prepared stage', () async {
    final prepared = await VoiceMemoFileStore.prepare(rawFile(), audio);
    try {
      final result = await recover();
      expect(result.recoveredStages, 0);
      expect(rawFile().existsSync(), false);
      expect(await prepared.stagedFile.readAsBytes(), audio);
    } finally {
      await prepared.discard();
    }
  });

  test('a staged retry never replaces an existing recording', () async {
    final previous = Uint8List.fromList([1, 2, 3]);
    await rawFile().writeAsBytes(previous);
    final staged = await stage(audio);
    final result = await recover();
    expect(result.recoveredStages, 0);
    expect(await rawFile().readAsBytes(), previous);
    expect(staged.existsSync(), true);
    expect((await memo()).syncedFromWatch, false);
  });

  test(
    'missing raw file clears receipt while preserving transcript and Ogg',
    () async {
      final ogg = File('${voiceDirectory.path}/legacy.ogg');
      await ogg.writeAsBytes([1, 2, 3]);
      await repository.markDownloaded(
        filename: 'fixture',
        localFilePath: rawFile().path,
      );
      await repository.updateConvertedPath(
        filename: 'fixture',
        convertedFilePath: ogg.path,
      );
      await repository.updateTranscription(
        filename: 'fixture',
        transcription: 'Keep this',
      );
      await repository.markDeletedOnWatch('fixture');
      final result = await recover();
      final repaired = await memo();
      expect(result.missingRecordings, 1);
      expect(repaired.localFilePath, isNull);
      expect(repaired.syncedFromWatch, false);
      expect(repaired.downloadedAt, isNull);
      expect(repaired.convertedFilePath, ogg.path);
      expect(repaired.transcription, 'Keep this');
      expect(repaired.deletedOnWatch, true);
      expect(ogg.existsSync(), true);
    },
  );

  test(
    'missing conversion is rebuilt from the already committed raw file',
    () async {
      await rawFile().writeAsBytes(audio);
      await repository.markDownloaded(
        filename: 'fixture',
        localFilePath: rawFile().path,
      );
      await repository.updateConvertedPath(
        filename: 'fixture',
        convertedFilePath: '${directory.path}/gone.ogg',
      );
      final result = await recover();
      expect(result.recoveredReceipts, 0);
      expect(result.rebuiltConversions, 1);
      expect(File((await memo()).convertedFilePath!).existsSync(), true);
    },
  );

  test(
    'conversion failure does not prevent durable raw receipt recovery',
    () async {
      await rawFile().writeAsBytes(audio);
      await Directory('${voiceDirectory.path}/fixture.ogg').create();
      final result = await recover();
      expect(result.recoveredReceipts, 1);
      expect(result.errors, hasLength(1));
      expect((await memo()).syncedFromWatch, true);
      expect((await memo()).convertedFilePath, isNull);
    },
  );

  test(
    'metadata change and deletion defeat stale recovery snapshots',
    () async {
      final snapshot = await memo();
      await repository.upsertFromWatch(
        filename: 'fixture',
        timestampUtc: 1700000001,
        durationMs: 100,
        sizeBytes: audio.length,
      );
      expect(
        await repository.reconcileReceipt(
          expected: snapshot,
          localFilePath: rawFile().path,
          convertedFilePath: null,
          syncedFromWatch: true,
        ),
        false,
      );
      final changed = await memo();
      await repository.deleteMemo('fixture');
      expect(
        await repository.reconcileReceipt(
          expected: changed,
          localFilePath: rawFile().path,
          convertedFilePath: null,
          syncedFromWatch: true,
        ),
        false,
      );
      expect(await repository.getMemoByFilename('fixture'), isNull);
    },
  );

  test(
    'recovery and receipt writes serialize without a failed-operation deadlock',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = VoiceMemoFileStore.exclusive(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      var finished = false;
      final pending = recover().then((report) {
        finished = true;
        return report;
      });
      await Future<void>.delayed(Duration.zero);
      expect(finished, false);
      release.complete();
      await held;
      await pending;
      await expectLater(
        VoiceMemoFileStore.exclusive<void>(() async {
          throw StateError('Injected failure');
        }),
        throwsStateError,
      );
      await recover().timeout(const Duration(seconds: 2));
    },
  );

  test(
    'symlink stages and destination traversal are never followed',
    () async {
      final outside = File('${directory.path}/outside');
      await outside.writeAsBytes(audio);
      final malicious = await stage(audio, destination: '../outside');
      final linked = await voiceDirectory.createTemp('.voice-receipt-');
      await Link('${linked.path}/payload').create(outside.path);
      await File('${linked.path}/receipt.json').writeAsString(
        jsonEncode({
          'version': 1,
          'destination': 'fixture.zsw_opus',
          'size_bytes': audio.length,
        }),
      );
      expect((await recover()).recoveredStages, 0);
      expect(malicious.existsSync(), true);
      expect(await outside.readAsBytes(), audio);
      expect(rawFile().existsSync(), false);
    },
    skip: Platform.isWindows,
  );

  for (final boundary in ['staged', 'published', 'committed']) {
    test(
      'real Flutter process death at $boundary is reconciled by actual Drift',
      () async {
        await db.close();
        db = AppDatabase.forTesting(
          NativeDatabase(File('${directory.path}/app.sqlite')),
        );
        repository = VoiceMemoRepository(db);
        final child = await Process.start('flutter', [
          'test',
          '--no-pub',
          'test/support/voice_recovery_crash_worker.dart',
          '--reporter',
          'expanded',
          '--dart-define=VOICE_RECOVERY_ROOT=${directory.path}',
          '--dart-define=VOICE_RECOVERY_BOUNDARY=$boundary',
        ]);
        final ready = Completer<int>();
        final output = StringBuffer();
        final errors = child.stderr.transform(utf8.decoder).join();
        final subscription = child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                output.writeln(line);
                final match = RegExp(
                  r'VOICE_RECOVERY_BOUNDARY:(\d+)',
                ).firstMatch(line);
                if (match != null && !ready.isCompleted) {
                  ready.complete(int.parse(match.group(1)!));
                }
              },
              onDone: () {
                if (!ready.isCompleted) {
                  ready.completeError(StateError(output.toString()));
                }
              },
            );
        int? workerPid;
        var workerKilled = false;
        var childExited = false;
        try {
          workerPid = await ready.future.timeout(const Duration(seconds: 60));
          expect(Process.killPid(workerPid, ProcessSignal.sigkill), true);
          workerKilled = true;
          expect(
            await child.exitCode.timeout(const Duration(seconds: 20)),
            isNot(0),
          );
          childExited = true;
          final result = await recover();
          expect(result.errors, isEmpty);
          final repaired = await memo();
          expect(repaired.syncedFromWatch, true);
          expect(repaired.deletedOnWatch, false);
          expect(await File(repaired.localFilePath!).readAsBytes(), audio);
          expect(File(repaired.convertedFilePath!).existsSync(), true);
          expect((await recover()).recoveredReceipts, 0);
        } finally {
          if (workerPid != null && !workerKilled) {
            Process.killPid(workerPid, ProcessSignal.sigkill);
          }
          if (!childExited) child.kill(ProcessSignal.sigkill);
          await child.exitCode;
          await subscription.cancel();
          await errors;
        }
      },
      skip: Platform.isWindows,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
