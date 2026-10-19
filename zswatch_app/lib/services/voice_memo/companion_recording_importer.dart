import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../data/database/companion_recording_database.dart';
import '../../data/models/companion_recording.dart';
import 'ogg_opus_writer.dart';
import 'voice_memo_file_store.dart';
import 'verified_companion_recording.dart';

/// UI-owned local projection. No BLE, native journal edits, inference or deletion.
/// Published playback precedes its immutable ledger entry; retry can adopt that
/// exact deterministic output after interruption between rename and DB commit.
class CompanionRecordingImporter {
  final CompanionRecordingDatabase database;
  final Future<Directory> Function() supportDirectory;
  final Future<void> Function(String)? checkpoint;

  const CompanionRecordingImporter({
    required this.database,
    required this.supportDirectory,
    this.checkpoint,
  });

  Future<ImportedRecording> prepare(CompanionRecording recording) =>
      VoiceMemoFileStore.exclusive(() => _prepare(recording));

  Future<ImportedRecording> _prepare(CompanionRecording recording) async {
    if (!recording.hasCommittedReceipt) {
      throw StateError('Recording has no committed native receipt');
    }
    final support = Directory(
      await (await supportDirectory()).resolveSymbolicLinks(),
    );
    final verified = await loadVerifiedCompanionRecording(recording, support);
    final parsed = verified.parsed;
    final expectedSource = verified.sourcePath;
    final keyHash = sha256.convert(utf8.encode(recording.identity)).toString();
    final existing = await database.byIdentity(recording.identity);
    if (existing != null &&
        (existing.sourceSha256 != recording.sha256 ||
            existing.sourcePath != expectedSource)) {
      throw StateError('Imported identity has conflicting source content');
    }
    final root = Directory(
      p.join(support.path, 'companion-recording-imports-v1'),
    );
    await root.create(recursive: true);
    if (await root.resolveSymbolicLinks() != root.path) {
      throw StateError('Import directory is not canonical');
    }
    final output = OggOpusWriter.convert(parsed);
    final outputHash = sha256.convert(output).toString();
    final destination = File(
      p.join(root.path, '$keyHash-${recording.sha256}-ogg-v1.ogg'),
    );
    if (existing != null &&
        (existing.playbackPath != destination.path ||
            existing.playbackSha256 != outputHash ||
            existing.converterVersion != 1 ||
            existing.watchId != recording.watchId ||
            existing.filename != recording.filename ||
            existing.timestampUtc !=
                recording.timestampUtc.millisecondsSinceEpoch ~/ 1000 ||
            existing.sizeBytes != recording.sizeBytes ||
            existing.durationMs != recording.durationMs)) {
      throw StateError('Imported identity has conflicting playback metadata');
    }
    final type = FileSystemEntity.typeSync(
      destination.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      final staged = await VoiceMemoFileStore.prepare(destination, output);
      try {
        await checkpoint?.call('staged');
        await staged.publish();
      } finally {
        await staged.discard();
      }
    } else if (type != FileSystemEntityType.file ||
        await destination.resolveSymbolicLinks() != destination.path ||
        await destination.length() != output.length ||
        sha256.convert(await destination.readAsBytes()).toString() !=
            outputHash) {
      throw StateError(
        'Existing playback file differs; retained for inspection',
      );
    }
    await checkpoint?.call('published');
    if (existing != null) return existing;
    final row = ImportedRecording(
      identity: recording.identity,
      watchId: recording.watchId,
      filename: recording.filename,
      timestampUtc: recording.timestampUtc.millisecondsSinceEpoch ~/ 1000,
      durationMs: recording.durationMs,
      sizeBytes: recording.sizeBytes,
      sourcePath: expectedSource,
      sourceSha256: recording.sha256!,
      playbackPath: destination.path,
      playbackSha256: outputHash,
      converterVersion: 1,
      importedAt: DateTime.now().toUtc(),
    );
    await database.into(database.recordingImports).insert(row);
    await checkpoint?.call('committed');
    return (await database.byIdentity(recording.identity))!;
  }
}
