/// Lightweight crash summary received via Gadgetbridge protocol on connect.
class CrashSummary {
  final String file;
  final int line;
  final String time;
  final String fwVersion;
  final String fwCommitSha;
  final String board;
  final String buildType;

  const CrashSummary({
    required this.file,
    required this.line,
    required this.time,
    required this.fwVersion,
    required this.fwCommitSha,
    required this.board,
    required this.buildType,
  });

  @override
  String toString() => 'CrashSummary($file:$line @ $time, sha=$fwCommitSha)';
}
