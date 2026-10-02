import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/data/repositories/voice_memo_repository.dart';
import 'package:zswatch_app/services/voice_memo/voice_memo_file_store.dart';

import '../zsw_opus_parser_test.dart' show buildZswOpusFile;
import 'host_sqlite.dart';

void main() {
  configureHostSqlite();
  const root = String.fromEnvironment('VOICE_RECOVERY_ROOT');
  const boundary = String.fromEnvironment('VOICE_RECOVERY_BOUNDARY');
  test(
    'receipt worker waits at the requested crash boundary',
    () async {
      if (root.isEmpty ||
          !['staged', 'published', 'committed'].contains(boundary)) {
        throw StateError('This worker must be invoked by the recovery test');
      }
      final db = AppDatabase.forTesting(
        NativeDatabase(File('$root/app.sqlite')),
      );
      final repository = VoiceMemoRepository(db);
      // Open the actual Drift connection and keep it alive until SIGKILL.
      await db.customStatement('PRAGMA journal_mode=WAL');
      final prepared = await VoiceMemoFileStore.prepare(
        File('$root/voice_memos/fixture.zsw_opus'),
        buildZswOpusFile(),
      );
      if (boundary != 'staged') await prepared.publish();
      if (boundary == 'committed') {
        await repository.markDownloaded(
          filename: 'fixture',
          localFilePath: '$root/voice_memos/fixture.zsw_opus',
        );
      }
      stdout.writeln('VOICE_RECOVERY_BOUNDARY:$pid');
      await Completer<void>().future;
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
