class FsFileEntry {
  final String path;
  final String name;
  final int sizeBytes;

  const FsFileEntry({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  FsFileEntry copyWith({String? path, String? name, int? sizeBytes}) {
    return FsFileEntry(
      path: path ?? this.path,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FsFileEntry &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          name == other.name &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hash(path, name, sizeBytes);
}
