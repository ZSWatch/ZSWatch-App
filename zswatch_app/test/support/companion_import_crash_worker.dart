import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:zswatch_app/data/database/companion_recording_database.dart';
import 'package:zswatch_app/services/voice_memo/companion_recording_importer.dart';

import 'companion_recording_fixture.dart';
import 'host_sqlite.dart';

void main() {
  configureHostSqlite();
  const root = String.fromEnvironment('COMPANION_IMPORT_ROOT');
  const boundary = String.fromEnvironment('COMPANION_IMPORT_BOUNDARY');
  test('wait at import boundary', () async {
    if (root.isEmpty ||
        !['staged', 'published', 'committed'].contains(boundary)) {
      throw StateError('Only invoke through the recovery test');
    }
    final directory = Directory(root);
    final recording = await seedCompanionRecording(directory);
    await Directory(
      '$root/companion-recording-imports-v1',
    ).create(recursive: true);
    final db = CompanionRecordingDatabase.forTesting(
      NativeDatabase(
        File('$root/companion-recording-imports-v1/imports.sqlite'),
      ),
    );
    await db.customStatement('PRAGMA journal_mode=WAL');
    await CompanionRecordingImporter(
      database: db,
      supportDirectory: () async => directory,
      checkpoint: (phase) async {
        if (phase == boundary) {
          stdout.writeln('COMPANION_IMPORT_BOUNDARY:$pid');
          await Completer<void>().future;
        }
      },
    ).prepare(recording);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
