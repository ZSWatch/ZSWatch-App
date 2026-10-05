import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../../data/models/companion_recording.dart';
import 'zsw_opus_parser.dart';

Future<({ZswOpusParseResult parsed, String sourcePath})>
loadVerifiedCompanionRecording(
  CompanionRecording recording,
  Directory support,
) async {
  if (!recording.hasCommittedReceipt) {
    throw StateError('Recording has no committed receipt');
  }
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
  return (parsed: parsed, sourcePath: expectedSource);
}
