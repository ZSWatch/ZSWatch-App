import 'dart:async';
import 'dart:convert';
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
    try {
      if (_stagingDirectory.existsSync()) {
        await _stagingDirectory.delete(recursive: true);
      }
    } finally {
      VoiceMemoFileStore._activeStages.remove(_stagingDirectory.path);
    }
  }
}

/// Atomic file publication before recording metadata/watch cleanup is committed.
///
/// An app-process exit before rename leaves only a staging directory. A retry
/// writes a fresh stage; it never truncates a previously published recording.
/// Complete stages carry a receipt manifest for conservative startup recovery.
class VoiceMemoFileStore {
  static final Set<String> _activeStages = {};
  static Future<void> _tail = Future.value();

  static bool isActiveStage(String path) => _activeStages.contains(path);

  /// Serializes recovery and publication within the current Dart runtime.
  /// Separate processes/runtimes need a shared owner before native migration.
  static Future<T> exclusive<T>(Future<T> Function() operation) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        released.complete();
      }
    }();
  }

  static Future<PreparedVoiceMemoFile> prepare(
    File destination,
    Uint8List data,
  ) async {
    await destination.parent.create(recursive: true);
    final staging = await destination.parent.createTemp('.voice-receipt-');
    _activeStages.add(staging.path);
    final stagedFile = File.fromUri(staging.uri.resolve('payload'));
    try {
      await stagedFile.writeAsBytes(data, flush: true);
      await File.fromUri(staging.uri.resolve('receipt.json')).writeAsString(
        jsonEncode({
          'version': 1,
          'destination': destination.uri.pathSegments.last,
          'size_bytes': data.length,
        }),
        flush: true,
      );
      return PreparedVoiceMemoFile._(destination, stagedFile, staging);
    } catch (_) {
      _activeStages.remove(staging.path);
      await staging.delete(recursive: true);
      rethrow;
    }
  }

  static Future<String> write(File destination, Uint8List data) =>
      exclusive(() => writeWhileExclusive(destination, data));

  /// Used by reconciliation while it already owns [exclusive].
  static Future<String> writeWhileExclusive(
    File destination,
    Uint8List data,
  ) async {
    final prepared = await prepare(destination, data);
    try {
      return await prepared.publish();
    } finally {
      await prepared.discard();
    }
  }
}
