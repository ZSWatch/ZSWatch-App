import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:zswatch_app/data/database/companion_recording_database.dart';
import 'package:zswatch_app/services/voice_memo/companion_recording_importer.dart';

import 'support/companion_recording_fixture.dart';
import 'support/host_sqlite.dart';
import 'zsw_opus_parser_test.dart' show buildZswOpusFile;

void main() {
  configureHostSqlite();
  late Directory root;
  late CompanionRecordingDatabase db;
  late CompanionRecordingImporter importer;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('companion-import-');
    await Directory(
      '${root.path}/companion-recording-imports-v1',
    ).create(recursive: true);
    db = CompanionRecordingDatabase.forTesting(
      NativeDatabase(
        File('${root.path}/companion-recording-imports-v1/imports.sqlite'),
      ),
    );
    importer = CompanionRecordingImporter(
      database: db,
      supportDirectory: () async => root,
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'explicit preparation publishes a separate deterministic playback receipt',
    () async {
      final recording = await seedCompanionRecording(root);
      final raw = await File(recording.localPath!).readAsBytes();
      final journal = File('${root.path}/companion-prototype/state-v1.json');
      await journal.writeAsString('{"preserve":"native journal"}');
      final row = await importer.prepare(recording);
      expect(row.identity, recording.identity);
      expect(row.sourceSha256, recording.sha256);
      expect(row.playbackPath, contains('companion-recording-imports-v1/'));
      expect((await File(row.playbackPath).readAsBytes()).sublist(0, 4), [
        79,
        103,
        103,
        83,
      ]);
      expect(await File(recording.localPath!).readAsBytes(), raw);
      expect(await journal.readAsString(), '{"preserve":"native journal"}');
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        1,
      );
      final changes =
          (await db.customSelect('SELECT total_changes() AS n').getSingle())
              .read<int>('n');
      final repeated = await importer.prepare(recording);
      expect(repeated, row);
      expect(
        (await db.customSelect('SELECT total_changes() AS n').getSingle())
            .read<int>('n'),
        changes,
      );
      await db.close();
      await Directory(
        '${root.path}/companion-recording-imports-v1',
      ).create(recursive: true);
      db = CompanionRecordingDatabase.forTesting(
        NativeDatabase(
          File('${root.path}/companion-recording-imports-v1/imports.sqlite'),
        ),
      );
      importer = CompanionRecordingImporter(
        database: db,
        supportDirectory: () async => root,
      );
      expect(await importer.prepare(recording), row);
    },
  );

  test(
    'same filename on two watches remains separate and concurrent retries are idempotent',
    () async {
      final a = await seedCompanionRecording(root);
      final b = await seedCompanionRecording(root, watch: 'second-watch');
      final rows = await Future.wait([
        importer.prepare(a),
        importer.prepare(a),
        importer.prepare(b),
      ]);
      expect(rows[0], rows[1]);
      expect(rows[0].playbackPath, isNot(rows[2].playbackPath));
      expect(await db.select(db.recordingImports).get(), hasLength(2));
    },
  );

  for (final state in ['pending', 'failed', 'downloading']) {
    test('$state does not become a playback receipt', () async {
      await expectLater(
        importer.prepare(await seedCompanionRecording(root, state: state)),
        throwsStateError,
      );
      expect(await db.select(db.recordingImports).get(), isEmpty);
    });
  }

  final invalid = <String, Uint8List>{
    'dirty stop': buildZswOpusFile(totalFrames: 0xffffffff),
    'frame count': buildZswOpusFile(totalFrames: 9),
    'header duration': buildZswOpusFile(durationMs: 99),
    'timestamp': buildZswOpusFile(timestamp: 1700000001),
    'version': buildZswOpusFile(version: 2),
    'audio profile': buildZswOpusFile(sampleRate: 8000, frameSize: 80),
    'truncated frame': Uint8List.fromList(buildZswOpusFile().sublist(0, 250)),
    'trailing garbage': Uint8List.fromList([...buildZswOpusFile(), 0]),
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key} even with a matching raw hash', () async {
      final recording = await seedCompanionRecording(root, bytes: entry.value);
      await expectLater(importer.prepare(recording), throwsStateError);
      expect(await db.select(db.recordingImports).get(), isEmpty);
    });
  }

  test('a raw hash mismatch never creates playback', () async {
    final recording = await seedCompanionRecording(root);
    await File(
      recording.localPath!,
    ).writeAsBytes(buildZswOpusFile(bitrate: 31000));
    await expectLater(importer.prepare(recording), throwsStateError);
    expect(await db.select(db.recordingImports).get(), isEmpty);
  });

  test('a symlink receipt is rejected and its target retained', () async {
    final recording = await seedCompanionRecording(root);
    final source = File(recording.localPath!);
    final outside = await source.rename('${root.path}/outside.zsw_opus');
    await Link(source.path).create(outside.path);
    await expectLater(importer.prepare(recording), throwsStateError);
    expect(await outside.readAsBytes(), buildZswOpusFile());
  });

  test('a noncanonical import directory cannot open the ledger', () async {
    await db.close();
    await Directory(
      '${root.path}/companion-recording-imports-v1',
    ).delete(recursive: true);
    final outside = await Directory('${root.path}/outside').create();
    await Link(
      '${root.path}/companion-recording-imports-v1',
    ).create(outside.path);
    db = CompanionRecordingDatabase.open(Future.value(root));
    await expectLater(db.select(db.recordingImports).get(), throwsStateError);
    expect(outside.listSync(), isEmpty);
    await expectLater(db.close(), throwsStateError);
    db = CompanionRecordingDatabase.forTesting(NativeDatabase.memory());
  });

  test(
    'a conflicting source for the same identity cannot change the immutable import',
    () async {
      final recording = await seedCompanionRecording(root);
      final row = await importer.prepare(recording);
      final output = await File(row.playbackPath).readAsBytes();
      final changed = await seedCompanionRecording(
        root,
        bytes: buildZswOpusFile(bitrate: 31000),
      );
      expect(changed.identity, recording.identity);
      await expectLater(importer.prepare(changed), throwsStateError);
      expect(await db.byIdentity(recording.identity), row);
      expect(await File(row.playbackPath).readAsBytes(), output);
    },
  );

  test(
    'missing playback is rebuilt, but a corrupt existing playback is retained',
    () async {
      final recording = await seedCompanionRecording(root);
      final row = await importer.prepare(recording);
      final file = File(row.playbackPath);
      final output = await file.readAsBytes();
      await file.delete();
      expect(await importer.prepare(recording), row);
      expect(await file.readAsBytes(), output);
      await file.writeAsBytes([1, 2, 3]);
      await expectLater(importer.prepare(recording), throwsStateError);
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(await db.byIdentity(recording.identity), row);
    },
  );

  test('publication before ledger failure is adopted on retry', () async {
    final recording = await seedCompanionRecording(root);
    final failing = CompanionRecordingImporter(
      database: db,
      supportDirectory: () async => root,
      checkpoint: (phase) async {
        if (phase == 'published') throw StateError('interrupted');
      },
    );
    await expectLater(failing.prepare(recording), throwsStateError);
    expect(await db.select(db.recordingImports).get(), isEmpty);
    final files = Directory('${root.path}/companion-recording-imports-v1')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ogg'))
        .toList();
    expect(files, hasLength(1));
    final bytes = await files.single.readAsBytes();
    final row = await importer.prepare(recording);
    expect(row.playbackPath, files.single.path);
    expect(await files.single.readAsBytes(), bytes);
  });

  for (final boundary in ['staged', 'published', 'committed']) {
    test(
      'SIGKILL at $boundary recovers with exactly one committed import',
      () async {
        final recording = await seedCompanionRecording(root);
        final raw = await File(recording.localPath!).readAsBytes();
        final child = await Process.start('flutter', [
          'test',
          '--no-pub',
          'test/support/companion_import_crash_worker.dart',
          '--reporter',
          'expanded',
          '--dart-define=COMPANION_IMPORT_ROOT=${root.path}',
          '--dart-define=COMPANION_IMPORT_BOUNDARY=$boundary',
        ]);
        final reached = Completer<int>();
        final output = StringBuffer();
        final subscription = child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
              output.writeln(line);
              final match = RegExp(
                r'COMPANION_IMPORT_BOUNDARY:(\d+)',
              ).firstMatch(line);
              if (match != null && !reached.isCompleted) {
                reached.complete(int.parse(match.group(1)!));
              }
            });
        final errors = child.stderr
            .transform(utf8.decoder)
            .listen(output.write);
        int? workerPid;
        try {
          workerPid = await reached.future.timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw StateError(output.toString()),
          );
          expect(Process.killPid(workerPid, ProcessSignal.sigkill), true);
          expect(
            await child.exitCode.timeout(const Duration(seconds: 20)),
            isNot(0),
          );
          final rowsBefore = await db.select(db.recordingImports).get();
          expect(rowsBefore.length, boundary == 'committed' ? 1 : 0);
          final row = await importer.prepare(recording);
          expect(await db.select(db.recordingImports).get(), [row]);
          expect(await importer.prepare(recording), row);
          expect(await File(recording.localPath!).readAsBytes(), raw);
          expect(File(row.playbackPath).existsSync(), true);
          if (boundary == 'staged') {
            expect(
              Directory(
                '${root.path}/companion-recording-imports-v1',
              ).listSync().whereType<Directory>(),
              hasLength(1),
            );
          }
        } finally {
          if (workerPid != null) {
            Process.killPid(workerPid, ProcessSignal.sigkill);
          }
          child.kill();
          await subscription.cancel();
          await errors.cancel();
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
