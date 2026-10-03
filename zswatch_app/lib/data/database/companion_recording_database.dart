import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

part 'companion_recording_database.g.dart';

/// Separate migration ledger: no filename-based adoption of legacy voice rows.
@DataClassName('ImportedRecording')
class RecordingImports extends Table {
  TextColumn get identity => text()();
  TextColumn get watchId => text()();
  TextColumn get filename => text()();
  IntColumn get timestampUtc => integer()();
  IntColumn get durationMs => integer()();
  IntColumn get sizeBytes => integer()();
  TextColumn get sourcePath => text()();
  TextColumn get sourceSha256 => text()();
  TextColumn get playbackPath => text()();
  TextColumn get playbackSha256 => text()();
  IntColumn get converterVersion => integer()();
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {identity};
}

@DriftDatabase(tables: [RecordingImports])
class CompanionRecordingDatabase extends _$CompanionRecordingDatabase {
  CompanionRecordingDatabase.forTesting(super.executor);

  CompanionRecordingDatabase.open(Future<Directory> supportDirectory)
    : super(
        LazyDatabase(() async {
          final support = Directory(
            await (await supportDirectory).resolveSymbolicLinks(),
          );
          final root = Directory(
            p.join(support.path, 'companion-recording-imports-v1'),
          );
          await root.create(recursive: true);
          if (await root.resolveSymbolicLinks() != root.path) {
            throw StateError('Import directory is not canonical');
          }
          return NativeDatabase.createInBackground(
            File(p.join(root.path, 'imports.sqlite')),
          );
        }),
      );

  @override
  int get schemaVersion => 1;

  Stream<List<ImportedRecording>> watchImports() =>
      select(recordingImports).watch();

  Future<ImportedRecording?> byIdentity(String identity) => (select(
    recordingImports,
  )..where((row) => row.identity.equals(identity))).getSingleOrNull();
}
