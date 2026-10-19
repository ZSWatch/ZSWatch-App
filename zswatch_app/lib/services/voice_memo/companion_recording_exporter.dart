import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../data/database/companion_recording_database.dart';

/// Share a temporary, verified copy. Never hand a native receipt to another app.
class CompanionRecordingExporter {
  final Future<Directory> Function() temporaryDirectory;
  const CompanionRecordingExporter({required this.temporaryDirectory});

  Future<void> audio(
    ImportedRecording recording,
    Future<void> Function(File) share,
  ) => audioFile(
    recording.playbackPath,
    recording.playbackSha256,
    recording.filename,
    share,
  );

  Future<void> audioFile(
    String path,
    String hash,
    String filename,
    Future<void> Function(File) share,
  ) async {
    final source = File(path);
    if (FileSystemEntity.typeSync(source.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await source.resolveSymbolicLinks() != source.path ||
        await source.length() > 32 * 1024 * 1024) {
      throw StateError('Playback export source is not a regular local file');
    }
    final bytes = await source.readAsBytes();
    if (sha256.convert(bytes).toString() != hash) {
      throw StateError('Playback export integrity mismatch');
    }
    await _share('$filename.ogg', bytes, share);
  }

  Future<void> text(
    String filename,
    String transcript,
    String summary,
    Future<void> Function(File) share,
  ) => _share(
    '$filename.txt',
    utf8.encode('$transcript${summary.isEmpty ? '' : '\n\nSummary\n$summary'}'),
    share,
  );

  Future<void> _share(
    String name,
    List<int> bytes,
    Future<void> Function(File) share,
  ) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,32}\.(ogg|txt)$').hasMatch(name) ||
        bytes.length > 32 * 1024 * 1024) {
      throw StateError('Invalid recording export');
    }
    final temporary = Directory(
      await (await temporaryDirectory()).resolveSymbolicLinks(),
    );
    final root = Directory(p.join(temporary.path, 'companion-voice-exports'));
    if (await root.resolveSymbolicLinksOrSelf() != root.path) {
      throw StateError('Export directory is not canonical');
    }
    await root.create(recursive: true);
    final staging = await root.createTemp('share-');
    try {
      final file = File(p.join(staging.path, name));
      await file.writeAsBytes(bytes, flush: true);
      await share(file);
    } finally {
      await staging.delete(recursive: true);
    }
  }
}

extension on Directory {
  Future<String> resolveSymbolicLinksOrSelf() async =>
      FileSystemEntity.typeSync(path, followLinks: false) ==
          FileSystemEntityType.notFound
      ? path
      : resolveSymbolicLinks();
}
