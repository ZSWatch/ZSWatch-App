import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/data/database/app_database.dart';
import 'package:zswatch_app/data/repositories/voice_memo_repository.dart';
import 'support/host_sqlite.dart';

void main() {
  configureHostSqlite();
  test(
    'repairs legacy voice memo rows with null non-nullable columns',
    () async {
      final executor = NativeDatabase.memory(
        setup: (db) {
          db
            ..execute('''
            CREATE TABLE voice_memos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              filename TEXT NOT NULL,
              timestamp_utc INTEGER,
              duration_ms INTEGER,
              size_bytes INTEGER,
              local_file_path TEXT,
              transcription TEXT,
              synced_from_watch INTEGER,
              deleted_on_watch INTEGER,
              downloaded_at INTEGER,
              transcribed_at INTEGER,
              converted_file_path TEXT,
              summary TEXT,
              category TEXT,
              processing_status TEXT,
              ai_model TEXT,
              ai_processed_at INTEGER,
              task_created INTEGER,
              calendar_event_created INTEGER,
              action_review_state TEXT,
              archived INTEGER
            )
          ''')
            ..execute(
              "INSERT INTO voice_memos (filename) VALUES ('20260512_230102')",
            )
            ..execute('PRAGMA user_version = 6');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);

      final repository = VoiceMemoRepository(db);

      await repository.upsertFromWatch(
        filename: '20260512_230102',
        timestampUtc: 1778626862,
        durationMs: 1200,
        sizeBytes: 4096,
      );

      final memo = await repository.getMemoByFilename('20260512_230102');

      expect(memo, isNotNull);
      expect(memo!.timestampUtc.millisecondsSinceEpoch ~/ 1000, 1778626862);
      expect(memo.durationMs, 1200);
      expect(memo.sizeBytes, 4096);
      expect(memo.syncedFromWatch, isFalse);
      expect(memo.deletedOnWatch, isFalse);
      expect(memo.taskCreated, isFalse);
      expect(memo.calendarEventCreated, isFalse);
      expect(memo.archived, isFalse);
    },
  );

  test(
    'repairs missing AI columns before processing recovery queries them',
    () async {
      final executor = NativeDatabase.memory(
        setup: (sqlite) {
          sqlite.execute('''
          CREATE TABLE voice_memos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT NOT NULL,
            timestamp_utc INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL,
            size_bytes INTEGER NOT NULL,
            local_file_path TEXT,
            transcription TEXT,
            synced_from_watch INTEGER NOT NULL DEFAULT 0,
            deleted_on_watch INTEGER NOT NULL DEFAULT 0,
            downloaded_at INTEGER,
            transcribed_at INTEGER,
            converted_file_path TEXT
          )
        ''');
          sqlite.execute('''
          INSERT INTO voice_memos
            (filename, timestamp_utc, duration_ms, size_bytes, transcription)
          VALUES ('legacy', 1700000000, 1200, 4096, 'Keep this transcript')
        ''');
          sqlite.execute('PRAGMA user_version = 7');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);
      final memo = await db.getVoiceMemoByFilename('legacy');
      expect(memo!.transcription, 'Keep this transcript');
      expect(memo.timestampUtc, 1700000000);
      expect(memo.summary, isNull);
      expect(memo.processingStatus, isNull);
      expect(memo.taskCreated, isFalse);
      expect(memo.calendarEventCreated, isFalse);
      expect(memo.archived, isFalse);
    },
  );

  test(
    'upgrade preserves valid recording data and native-owned processing state',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite.execute(_nullableLegacyTable);
            sqlite.execute('''
            INSERT INTO voice_memos (
              filename, timestamp_utc, duration_ms, size_bytes, local_file_path,
              transcription, summary, processing_status, synced_from_watch,
              deleted_on_watch, task_created, calendar_event_created, archived
            ) VALUES (
              'valid', 1700000000, 1234, 5678, '/saved/valid.zsw_opus',
              'Keep transcript', 'Keep summary', 'queued', 1, 1, 1, 1, 1
            )
          ''');
            sqlite.execute('''
            INSERT INTO voice_memos (
              filename, timestamp_utc, duration_ms, size_bytes, processing_status,
              synced_from_watch, deleted_on_watch, task_created,
              calendar_event_created, archived
            ) VALUES ('native-pending', 1700000000, 1, 1, 'queued', 0, 0, 0, 0, 0)
          ''');
            sqlite.execute('PRAGMA user_version = 7');
          },
        ),
        recoverLegacyProcessing: false,
      );
      addTearDown(db.close);
      final memo = await db.getVoiceMemoByFilename('valid');
      expect(memo!.timestampUtc, 1700000000);
      expect(memo.durationMs, 1234);
      expect(memo.sizeBytes, 5678);
      expect(memo.localFilePath, '/saved/valid.zsw_opus');
      expect(memo.transcription, 'Keep transcript');
      expect(memo.summary, 'Keep summary');
      expect(memo.processingStatus, 'queued');
      expect(memo.syncedFromWatch, isTrue);
      expect(memo.deletedOnWatch, isTrue);
      expect(memo.taskCreated, isTrue);
      expect(memo.calendarEventCreated, isTrue);
      expect(memo.archived, isTrue);
      expect(
        (await db.getVoiceMemoByFilename('native-pending'))!.processingStatus,
        'queued',
      );
      expect(
        (await db.customSelect('SELECT total_changes() AS n').getSingle())
            .read<int>('n'),
        2, // Only the two fixture inserts; migration must not rewrite valid rows.
      );
    },
  );

  test('repaired database reopens without rewriting recordings', () async {
    final directory = await Directory.systemTemp.createTemp(
      'memo-schema-repair-',
    );
    final file = File('${directory.path}/app.db');
    var db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (sqlite) {
          sqlite.execute(_nullableLegacyTable);
          sqlite.execute(
            "INSERT INTO voice_memos (filename, transcription) VALUES ('legacy', 'Keep transcript')",
          );
          sqlite.execute('PRAGMA user_version = 7');
        },
      ),
      recoverLegacyProcessing: false,
    );
    try {
      final repaired = await db.getVoiceMemoByFilename('legacy');
      expect(repaired!.timestampUtc, 0);
      expect(repaired.transcription, 'Keep transcript');
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        9,
      );
      await db.close();
      db = AppDatabase.forTesting(
        NativeDatabase(file),
        recoverLegacyProcessing: false,
      );
      expect(await db.getVoiceMemoByFilename('legacy'), repaired);
      expect(
        (await db.customSelect('SELECT total_changes() AS n').getSingle())
            .read<int>('n'),
        0,
      );
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}

const _nullableLegacyTable = '''
  CREATE TABLE voice_memos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL,
    timestamp_utc INTEGER,
    duration_ms INTEGER,
    size_bytes INTEGER,
    local_file_path TEXT,
    transcription TEXT,
    synced_from_watch INTEGER,
    deleted_on_watch INTEGER,
    downloaded_at INTEGER,
    transcribed_at INTEGER,
    converted_file_path TEXT,
    summary TEXT,
    category TEXT,
    processing_status TEXT,
    ai_model TEXT,
    ai_processed_at INTEGER,
    task_created INTEGER,
    calendar_event_created INTEGER,
    action_review_state TEXT,
    archived INTEGER
  )
''';
