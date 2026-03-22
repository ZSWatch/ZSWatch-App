import 'dart:typed_data';

/// Parsed header from a .zsw_opus file
class ZswOpusHeader {
  /// File format magic bytes (should be "ZSWO")
  final String magic;

  /// Format version (currently 1)
  final int version;

  /// Audio sample rate in Hz (normally 16000)
  final int sampleRate;

  /// Samples per Opus frame (normally 160)
  final int frameSize;

  /// Encoding bitrate in bps (normally 32000)
  final int bitrate;

  /// Recording start timestamp (Unix epoch seconds)
  final int timestamp;

  /// Total encoded frames (0xFFFFFFFF if dirty stop)
  final int totalFrames;

  /// Recording duration in ms (0xFFFFFFFF if dirty stop)
  final int durationMs;

  const ZswOpusHeader({
    required this.magic,
    required this.version,
    required this.sampleRate,
    required this.frameSize,
    required this.bitrate,
    required this.timestamp,
    required this.totalFrames,
    required this.durationMs,
  });

  /// Whether this file had a dirty stop (crash/reset during recording)
  bool get isDirtyStop => totalFrames == 0xFFFFFFFF || durationMs == 0xFFFFFFFF;
}

/// A single Opus frame extracted from a .zsw_opus file
class OpusFrame {
  /// Offset in the file where this frame starts (including length prefix)
  final int fileOffset;

  /// Encoded Opus data bytes
  final Uint8List data;

  const OpusFrame({required this.fileOffset, required this.data});
}

/// Result of parsing a .zsw_opus file
class ZswOpusParseResult {
  final ZswOpusHeader header;
  final List<OpusFrame> frames;

  /// Computed duration in milliseconds (from frame count, not header)
  int get computedDurationMs {
    if (header.sampleRate == 0) return 0;
    return (frames.length * header.frameSize * 1000) ~/ header.sampleRate;
  }

  /// Whether the file appears valid
  bool get isValid => header.magic == 'ZSWO' && frames.isNotEmpty;

  const ZswOpusParseResult({required this.header, required this.frames});
}

/// Parser for the ZSWatch .zsw_opus custom container format
///
/// File layout:
///   Header (32 bytes, fixed):
///     [4B magic "ZSWO"]
///     [2B version LE]
///     [2B sample_rate LE]
///     [2B frame_size LE]
///     [2B reserved]
///     [4B bitrate LE]
///     [4B timestamp LE]
///     [4B total_frames LE]
///     [4B duration_ms LE]
///     [4B reserved]
///   Body (packed frames):
///     [2B frame_length LE][N bytes opus data] ...
class ZswOpusParser {
  static const int headerSize = 32;
  static const String expectedMagic = 'ZSWO';

  /// Parse a .zsw_opus file from raw bytes.
  ///
  /// Returns null if the file is too small or has an invalid magic.
  static ZswOpusParseResult? parse(Uint8List data) {
    if (data.length < headerSize) return null;

    final header = _parseHeader(data);
    if (header == null) return null;

    final frames = _parseFrames(data);
    return ZswOpusParseResult(header: header, frames: frames);
  }

  /// Parse only the header (for quick validation without reading all frames).
  static ZswOpusHeader? parseHeader(Uint8List data) {
    if (data.length < headerSize) return null;
    return _parseHeader(data);
  }

  /// Validate file integrity: parse header + walk all frames.
  /// Returns true if magic is valid and all frames are well-formed.
  static bool validate(Uint8List data) {
    final result = parse(data);
    if (result == null) return false;
    if (result.header.magic != expectedMagic) return false;
    // Verify frame data covers the full body (no trailing garbage beyond
    // what could be a partial frame from a dirty stop)
    return result.frames.isNotEmpty;
  }

  /// Validate that a downloaded file matches expected metadata.
  /// Used for post-download verification before deleting from watch.
  static bool validateDownload(
    Uint8List data, {
    required int expectedSizeBytes,
  }) {
    if (data.length != expectedSizeBytes) return false;
    return validate(data);
  }

  static ZswOpusHeader? _parseHeader(Uint8List data) {
    final bd = ByteData.sublistView(data, 0, headerSize);

    final magic = String.fromCharCodes(data.sublist(0, 4));
    if (magic != expectedMagic) return null;

    return ZswOpusHeader(
      magic: magic,
      version: bd.getUint16(4, Endian.little),
      sampleRate: bd.getUint16(6, Endian.little),
      frameSize: bd.getUint16(8, Endian.little),
      bitrate: bd.getUint32(12, Endian.little),
      timestamp: bd.getUint32(16, Endian.little),
      totalFrames: bd.getUint32(20, Endian.little),
      durationMs: bd.getUint32(24, Endian.little),
    );
  }

  static List<OpusFrame> _parseFrames(Uint8List data) {
    final frames = <OpusFrame>[];
    int offset = headerSize;

    while (offset + 2 <= data.length) {
      final bd = ByteData.sublistView(data, offset, offset + 2);
      final frameLen = bd.getUint16(0, Endian.little);

      if (frameLen == 0) break; // Zero-length frame = end marker or corruption
      if (offset + 2 + frameLen > data.length)
        break; // Truncated frame (dirty stop)

      final frameData = Uint8List.sublistView(
        data,
        offset + 2,
        offset + 2 + frameLen,
      );
      frames.add(OpusFrame(fileOffset: offset, data: frameData));
      offset += 2 + frameLen;
    }

    return frames;
  }
}
