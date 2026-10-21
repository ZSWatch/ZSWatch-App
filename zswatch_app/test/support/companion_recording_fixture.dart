import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:zswatch_app/data/models/companion_recording.dart';

import '../zsw_opus_parser_test.dart' show buildZswOpusFile;

Future<CompanionRecording> seedCompanionRecording(
  Directory root, {
  String watch = 'AA:BB:CC:DD:EE:FF',
  Uint8List? bytes,
  String state = 'downloaded',
  int duration = 100,
  String filename = 'memo_001',
}) async {
  final raw = bytes ?? buildZswOpusFile();
  final identity = '$watch:$filename:1700000000:${raw.length}:$duration';
  final key = sha256.convert(utf8.encode(identity));
  final source = File(
    '${root.path}/companion-prototype/recordings/$key.zsw_opus',
  );
  await source.parent.create(recursive: true);
  await source.writeAsBytes(raw, flush: true);
  return CompanionRecording.decode(identity, {
    'address': watch,
    'filename': filename,
    'timestamp': 1700000000,
    'duration_ms': duration,
    'size_bytes': raw.length,
    'state': state,
    'local_path': source.path,
    'sha256': sha256.convert(raw).toString(),
  });
}
