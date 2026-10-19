/// A native receipt identity, not a Drift row or an inference result.
enum CompanionRecordingState {
  pending,
  downloading,
  downloaded,
  failed,
  deleted,
}

class CompanionRecording {
  final String identity;
  final String watchId;
  final String filename;
  final DateTime timestampUtc;
  final int durationMs;
  final int sizeBytes;
  final CompanionRecordingState state;
  final String? localPath;
  final String? sha256;
  final String? error;
  final String title;
  final bool archived;
  final bool purged;
  final bool purgePending;

  const CompanionRecording._({
    required this.identity,
    required this.watchId,
    required this.filename,
    required this.timestampUtc,
    required this.durationMs,
    required this.sizeBytes,
    required this.state,
    this.localPath,
    this.sha256,
    this.error,
    required this.title,
    required this.archived,
    required this.purged,
    required this.purgePending,
  });

  /// This reflects the committed journal. It does not read/validate the file,
  /// decode audio, establish AI readiness or acknowledge deletion on the watch.
  bool get hasCommittedReceipt => state == CompanionRecordingState.downloaded;

  factory CompanionRecording.decode(String identity, Object? value) {
    if (value is! Map) throw const FormatException('Invalid native recording');
    final watchId = value['address'];
    final filename = value['filename'];
    final timestamp = value['timestamp'];
    final duration = value['duration_ms'];
    final size = value['size_bytes'];
    if (watchId is! String ||
        watchId.isEmpty ||
        watchId.length > 256 ||
        filename is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(filename) ||
        timestamp is! int ||
        timestamp < 0 ||
        timestamp > 0xffffffff ||
        duration is! int ||
        duration <= 0 ||
        size is! int ||
        size < 34 ||
        size > 16 * 1024 * 1024 ||
        identity != '$watchId:$filename:$timestamp:$size:$duration') {
      throw const FormatException('Invalid native recording identity/metadata');
    }
    final state = switch (value['state']) {
      'pending' => CompanionRecordingState.pending,
      'downloading' => CompanionRecordingState.downloading,
      'downloaded' => CompanionRecordingState.downloaded,
      'failed' => CompanionRecordingState.failed,
      'deleted' => CompanionRecordingState.deleted,
      _ => throw const FormatException('Unknown native recording state'),
    };
    final path = value['local_path'];
    final hash = value['sha256'];
    final error = value['error'];
    final title = value['title'] ?? '';
    final archived = value['archived'] ?? false;
    final purged = value['purged'] ?? false;
    final purgePending = value['purge_pending'] ?? false;
    if ((path != null && (path is! String || !path.startsWith('/'))) ||
        (hash != null &&
            (hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash))) ||
        (error != null && error is! String) ||
        title is! String ||
        title.length > 256 ||
        archived is! bool ||
        purged is! bool ||
        purgePending is! bool ||
        (purged && state != CompanionRecordingState.deleted) ||
        (purgePending && !purged) ||
        (state == CompanionRecordingState.downloaded &&
            (path == null || hash == null))) {
      throw const FormatException('Invalid native recording receipt');
    }
    return CompanionRecording._(
      identity: identity,
      watchId: watchId,
      filename: filename,
      timestampUtc: DateTime.fromMillisecondsSinceEpoch(
        timestamp * 1000,
        isUtc: true,
      ),
      durationMs: duration,
      sizeBytes: size,
      state: state,
      localPath: path as String?,
      sha256: hash as String?,
      error: error as String?,
      title: title.trim().isEmpty ? filename : title,
      archived: archived,
      purged: purged,
      purgePending: purgePending,
    );
  }
}
