import 'dart:typed_data';

import 'fs_file_entry.dart';

class CompanionLogFiles {
  final List<FsFileEntry> files;
  final Uint8List? bytes;
  const CompanionLogFiles._(this.files, this.bytes);
  static const maxBytes = 4 * 1024 * 1024;
  static bool validPath(String path) =>
      RegExp(r'^/user/logs/log000[0-7]$').hasMatch(path);

  factory CompanionLogFiles.decode(
    Object? value,
    int generation, {
    String? path,
  }) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['generation'] is! int ||
        value['generation'] != generation ||
        value['files'] is! List) {
      throw const FormatException('Unsupported log inspection response');
    }
    final entries = <FsFileEntry>[];
    final seen = <String>{};
    for (final entry in value['files'] as List) {
      if (entry is! Map ||
          entry['path'] is! String ||
          !validPath(entry['path'] as String) ||
          !seen.add(entry['path'] as String) ||
          entry['size_bytes'] is! int ||
          (entry['size_bytes'] as int) < 0 ||
          (entry['size_bytes'] as int) > 2147483647) {
        throw const FormatException('Invalid log metadata');
      }
      final filePath = entry['path'] as String;
      entries.add(
        FsFileEntry(
          path: filePath,
          name: filePath.split('/').last,
          sizeBytes: entry['size_bytes'] as int,
        ),
      );
    }
    final bytes = value['bytes'];
    if (path == null
        ? bytes != null
        : entries.length != 1 ||
              entries.single.path != path ||
              bytes is! Uint8List ||
              bytes.length != entries.single.sizeBytes ||
              bytes.length > maxBytes) {
      throw const FormatException('Invalid log download response');
    }
    return CompanionLogFiles._(List.unmodifiable(entries), bytes as Uint8List?);
  }
}
