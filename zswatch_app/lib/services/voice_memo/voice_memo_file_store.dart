import 'dart:io';
import 'dart:typed_data';

/// A flushed recording staged on the same filesystem as its final destination.
/// Publishing is separate so a partially received file never appears as synced.
class PreparedVoiceMemoFile {
  final File destination;
  final File stagedFile;
  final Directory _stagingDirectory;

  PreparedVoiceMemoFile._(
    this.destination,
    this.stagedFile,
    this._stagingDirectory,
  );

  Future<String> publish() async {
    await stagedFile.rename(destination.path);
    return destination.path;
  }

  Future<void> discard() async {
    if (_stagingDirectory.existsSync()) {
      await _stagingDirectory.delete(recursive: true);
    }
  }
}

/// Atomic file publication before recording metadata/watch cleanup is committed.
///
/// An app-process exit before rename leaves only a staging directory. A retry
/// writes a fresh stage; it never truncates a previously published recording.
/// File/DB reconciliation and stale-stage cleanup remain separate recovery work.
class VoiceMemoFileStore {
  static Future<PreparedVoiceMemoFile> prepare(
    File destination,
    Uint8List data,
  ) async {
    await destination.parent.create(recursive: true);
    final staging = await destination.parent.createTemp('.voice-receipt-');
    final stagedFile = File.fromUri(staging.uri.resolve('payload'));
    try {
      await stagedFile.writeAsBytes(data, flush: true);
      return PreparedVoiceMemoFile._(destination, stagedFile, staging);
    } catch (_) {
      await staging.delete(recursive: true);
      rethrow;
    }
  }

  static Future<String> write(File destination, Uint8List data) async {
    final prepared = await prepare(destination, data);
    try {
      return await prepared.publish();
    } finally {
      await prepared.discard();
    }
  }
}
