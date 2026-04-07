class FsFileEntry {
  final String path;
  final String name;
  final int sizeBytes;

  const FsFileEntry({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
  }
}
