import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../data/models/voice_memo.dart';
import 'ogg_opus_writer.dart';
import 'voice_memo_file_store.dart';
import 'zsw_opus_parser.dart';

/// Retained legacy audio stays separate from UUID-based native receipts.
Future<({String path, String hash})> prepareRetainedRecording(
  VoiceMemo memo,
  Directory documents,
  Directory support,
) => VoiceMemoFileStore.exclusive(() async {
  final root = await documents.resolveSymbolicLinks();
  final source = File(memo.localFilePath ?? '');
  if (memo.localFilePath == null ||
      !p.isWithin(root, source.path) ||
      FileSystemEntity.typeSync(source.path, followLinks: false) !=
          FileSystemEntityType.file ||
      await source.resolveSymbolicLinks() != source.path ||
      await source.length() != memo.sizeBytes ||
      memo.sizeBytes > 16 * 1024 * 1024) {
    throw StateError(
      'Retained source is unavailable or outside its original directory',
    );
  }
  final bytes = await source.readAsBytes();
  final parsed = ZswOpusParser.parse(bytes);
  if (parsed == null ||
      !parsed.isValid ||
      parsed.header.version != 1 ||
      parsed.header.sampleRate != 16000 ||
      parsed.header.frameSize != 160 ||
      parsed.header.isDirtyStop ||
      parsed.header.totalFrames != parsed.frames.length ||
      parsed.header.durationMs != parsed.computedDurationMs ||
      parsed.frames.last.fileOffset + 2 + parsed.frames.last.data.length !=
          bytes.length) {
    throw StateError('Retained audio format cannot be verified');
  }
  final cache = Directory(
    p.join(await support.resolveSymbolicLinks(), 'retained-voice-playback-v1'),
  );
  if (FileSystemEntity.typeSync(cache.path, followLinks: false) !=
          FileSystemEntityType.notFound &&
      await cache.resolveSymbolicLinks() != cache.path) {
    throw StateError('Retained playback directory is not canonical');
  }
  await cache.create(recursive: true);
  final ogg = OggOpusWriter.convert(parsed);
  final hash = sha256.convert(ogg).toString();
  final target = File(
    p.join(cache.path, '${memo.id}-${sha256.convert(bytes)}.ogg'),
  );
  await VoiceMemoFileStore.writeWhileExclusive(target, ogg);
  return (path: target.path, hash: hash);
});
