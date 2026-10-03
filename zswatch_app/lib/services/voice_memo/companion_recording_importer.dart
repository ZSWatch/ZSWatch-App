import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../data/database/companion_recording_database.dart';
import '../../data/models/companion_recording.dart';
import 'ogg_opus_writer.dart';
import 'voice_memo_file_store.dart';
import 'zsw_opus_parser.dart';

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
    final native = Directory(
      p.join(support.path, 'companion-prototype', 'recordings'),
    );
    if (await native.resolveSymbolicLinks() != native.path) {
      throw StateError('Native receipt directory is not canonical');
    }
    final keyHash = sha256.convert(utf8.encode(recording.identity)).toString();
    final expectedSource = p.join(native.path, '$keyHash.zsw_opus');
    final source = File(recording.localPath!);
    if (FileSystemEntity.typeSync(source.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await source.resolveSymbolicLinks() != expectedSource ||
        await source.length() != recording.sizeBytes) {
      throw StateError('Native receipt file/path/size mismatch');
    }
    final raw = await source.readAsBytes();
    if (raw.length != recording.sizeBytes ||
        sha256.convert(raw).toString() != recording.sha256) {
      throw StateError('Native receipt hash mismatch');
    }
    final parsed = ZswOpusParser.parse(raw);
    // The existing Ogg writer uses 10 ms mono frames. Other profiles need a
    // separate converter contract instead of silently changing their timing.
    if (parsed == null ||
        !parsed.isValid ||
        parsed.header.version != 1 ||
        parsed.header.isDirtyStop ||
        parsed.header.sampleRate != 16000 ||
        parsed.header.frameSize != 160 ||
        parsed.header.timestamp !=
            recording.timestampUtc.millisecondsSinceEpoch ~/ 1000 ||
        parsed.header.totalFrames != parsed.frames.length ||
        parsed.header.durationMs != parsed.computedDurationMs ||
        recording.durationMs != parsed.computedDurationMs ||
        parsed.frames.last.fileOffset + 2 + parsed.frames.last.data.length !=
            raw.length) {
      throw StateError(
        'Native receipt container/metadata mismatch or unsupported audio profile',
      );
    }
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
