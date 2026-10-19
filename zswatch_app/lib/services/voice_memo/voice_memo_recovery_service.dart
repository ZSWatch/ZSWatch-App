import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../../data/models/voice_memo.dart';
import '../../data/repositories/voice_memo_repository.dart';
import 'ogg_opus_writer.dart';
import 'voice_memo_file_store.dart';
import 'zsw_opus_parser.dart';

class VoiceMemoRecoveryReport {
  int recoveredReceipts = 0;
  int recoveredStages = 0;
  int rebuiltConversions = 0;
  int missingRecordings = 0;
  final List<String> retainedFiles = [];
  final List<String> errors = [];
}

/// Repairs known recordings without BLE, inference or watch deletion.
/// Unknown files and ambiguous/legacy stages are retained for inspection.
class VoiceMemoRecoveryService {
  final VoiceMemoRepository repository;
  final Future<Directory> Function() documentsDirectory;

  VoiceMemoRecoveryService({
    required this.repository,
    required this.documentsDirectory,
  });

  Future<VoiceMemoRecoveryReport> recover() =>
      VoiceMemoFileStore.exclusive(_recover);

  Future<VoiceMemoRecoveryReport> _recover() async {
    final report = VoiceMemoRecoveryReport();
    final root = Directory(
      p.join((await documentsDirectory()).path, 'voice_memos'),
    );
    final memos = await repository.getAllMemos();
    final stages = <String, List<File>>{};
    if (root.existsSync()) {
      await for (final entry in root.list(followLinks: false)) {
        if (entry is Directory &&
            p.basename(entry.path).startsWith('.voice-receipt-') &&
            !VoiceMemoFileStore.isActiveStage(entry.path)) {
          report.retainedFiles.add(entry.path);
          try {
            final manifest = File(p.join(entry.path, 'receipt.json'));
            final payload = File(p.join(entry.path, 'payload'));
            if (!_regularFile(manifest.path) || !_regularFile(payload.path)) {
              continue;
            }
            final decoded = jsonDecode(await manifest.readAsString());
            if (decoded is! Map<String, dynamic>) continue;
            final destination = decoded['destination'];
            if (decoded['version'] != 1 ||
                destination is! String ||
                !RegExp(r'^[A-Za-z0-9_-]+\.zsw_opus$').hasMatch(destination) ||
                decoded['size_bytes'] != await payload.length()) {
              continue;
            }
            stages.putIfAbsent(destination, () => []).add(payload);
          } catch (error) {
            report.errors.add('Retained stage ${entry.path}: $error');
          }
        } else if (entry is File &&
            !memos.any(
              (memo) => p.basenameWithoutExtension(entry.path) == memo.filename,
            )) {
          report.retainedFiles.add(entry.path);
        }
      }
    }
    for (final memo in memos) {
      try {
        if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(memo.filename)) {
          report.errors.add('Unsupported recording filename: ${memo.filename}');
          continue;
        }
        final destination = File(
          p.join(root.path, '${memo.filename}.zsw_opus'),
        );
        String? rawPath = memo.localFilePath;
        Uint8List? raw;
        Directory? publishedStage;
        // Existing receipt paths remain authoritative; do not adopt partial data.
        if (rawPath != null && _regularFile(rawPath)) {
          final data = await File(rawPath).readAsBytes();
          if (_completeReceipt(data, memo) ||
              (memo.syncedFromWatch &&
                  ZswOpusParser.validateDownload(
                    data,
                    expectedSizeBytes: memo.sizeBytes,
                  ))) {
            raw = data;
          }
        }
        if (raw == null && _regularFile(destination.path)) {
          final data = await destination.readAsBytes();
          if (_completeReceipt(data, memo)) {
            raw = data;
            rawPath = destination.path;
          }
        }
        if (raw == null &&
            FileSystemEntity.typeSync(destination.path, followLinks: false) ==
                FileSystemEntityType.notFound) {
          final candidates = <Uint8List>[];
          final sources = <File>[];
          for (final stage
              in stages[p.basename(destination.path)] ?? <File>[]) {
            final data = await stage.readAsBytes();
            if (_completeReceipt(data, memo)) {
              candidates.add(data);
              sources.add(stage);
            }
          }
          if (candidates.isNotEmpty &&
              candidates.every(
                (data) =>
                    const ListEquality<int>().equals(data, candidates.first),
              )) {
            await sources.first.rename(destination.path);
            raw = candidates.first;
            rawPath = destination.path;
            report.recoveredStages++;
            publishedStage = sources.first.parent;
          }
        }
        String? converted = memo.convertedFilePath;
        if (converted != null && !_regularFile(converted)) converted = null;
        if (raw != null && converted == null) {
          try {
            converted = await VoiceMemoFileStore.writeWhileExclusive(
              File(p.join(root.path, '${memo.filename}.ogg')),
              OggOpusWriter.convert(ZswOpusParser.parse(raw)!),
            );
            report.rebuiltConversions++;
          } catch (error) {
            report.errors.add('Conversion failed for ${memo.filename}: $error');
          }
        }
        final committed = await repository.reconcileReceipt(
          expected: memo,
          localFilePath: raw == null ? null : rawPath,
          convertedFilePath: converted,
          syncedFromWatch: raw != null,
        );
        if (!committed) {
          report.errors.add(
            'Recording changed during recovery: ${memo.filename}',
          );
        } else if (raw != null && !memo.syncedFromWatch) {
          report.recoveredReceipts++;
        } else if (raw == null && memo.syncedFromWatch) {
          report.missingRecordings++;
        }
        if (committed && publishedStage != null) {
          final entries = await publishedStage
              .list(followLinks: false)
              .toList();
          if (entries.length == 1 &&
              entries.single is File &&
              p.basename(entries.single.path) == 'receipt.json') {
            await entries.single.delete();
            await publishedStage.delete();
            report.retainedFiles.remove(publishedStage.path);
          }
        }
      } catch (error) {
        report.errors.add('Recovery failed for ${memo.filename}: $error');
      }
    }
    return report;
  }

  static bool _regularFile(String path) =>
      FileSystemEntity.typeSync(path, followLinks: false) ==
      FileSystemEntityType.file;

  /// New adoption requires a closed v1 container matching known watch metadata.
  /// Dirty/partial containers remain untouched, even if their prefix is playable.
  static bool _completeReceipt(Uint8List data, VoiceMemo memo) {
    if (data.length != memo.sizeBytes) return false;
    final parsed = ZswOpusParser.parse(data);
    if (parsed == null ||
        !parsed.isValid ||
        parsed.header.version != 1 ||
        parsed.header.isDirtyStop ||
        parsed.header.sampleRate == 0 ||
        parsed.header.frameSize == 0 ||
        parsed.header.timestamp !=
            memo.timestampUtc.millisecondsSinceEpoch ~/ 1000 ||
        parsed.header.totalFrames != parsed.frames.length ||
        parsed.header.durationMs != parsed.computedDurationMs ||
        memo.durationMs != parsed.computedDurationMs) {
      return false;
    }
    final last = parsed.frames.last;
    return last.fileOffset + 2 + last.data.length == data.length;
  }
}
