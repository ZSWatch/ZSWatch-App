import 'dart:typed_data';

import 'zsw_opus_parser.dart';

/// Converts ZSWatch custom .zsw_opus files to standard Ogg/Opus format
/// for playback with standard audio players.
///
/// Ogg container spec: RFC 3533
/// Opus in Ogg spec: RFC 7845
///
/// The ZSWatch firmware encodes audio as:
///   - 16 kHz, mono, 32 kbps, 10 ms frames
///   - OPUS_APPLICATION_RESTRICTED_LOWDELAY mode
///   - Pre-skip ≈ 120 samples at 48 kHz
class OggOpusWriter {
  // Samples per Opus frame at the 48 kHz Ogg granule rate.
  // 10 ms frame at 48 kHz = 480 samples.
  static const int _samplesPerFrame48k = 480;

  // Pre-skip for OPUS_APPLICATION_RESTRICTED_LOWDELAY at 16 kHz.
  // The encoder's algorithmic delay is ~2.5 ms ≈ 120 samples at 48 kHz.
  static const int _preSkip = 120;

  // Maximum Opus frames per Ogg page (~2 s of audio at 10 ms/frame).
  static const int _framesPerPage = 200;

  // Arbitrary but fixed serial number for the logical bitstream.
  static const int _serialNumber = 0x5A535731; // "ZSW1"

  /// Convert a parsed .zsw_opus result into a standard Ogg/Opus byte buffer
  /// that can be played by any Opus-capable audio player.
  static Uint8List convert(ZswOpusParseResult parsed) {
    final builder = BytesBuilder(copy: false);
    int pageSeq = 0;

    // ── Page 1: OpusHead (BOS) ──────────────────────────────
    final opusHead = _buildOpusHead(
      channels: 1,
      preSkip: _preSkip,
      inputSampleRate: parsed.header.sampleRate,
    );
    builder.add(
      _buildOggPage(
        granulePosition: 0,
        serialNumber: _serialNumber,
        pageSequence: pageSeq++,
        headerType: 0x02, // BOS
        packets: [opusHead],
      ),
    );

    // ── Page 2: OpusTags ────────────────────────────────────
    final opusTags = _buildOpusTags();
    builder.add(
      _buildOggPage(
        granulePosition: 0,
        serialNumber: _serialNumber,
        pageSequence: pageSeq++,
        headerType: 0x00,
        packets: [opusTags],
      ),
    );

    // ── Pages 3+: Audio data ────────────────────────────────
    int totalSamples = 0;

    for (int i = 0; i < parsed.frames.length; i += _framesPerPage) {
      final end = (i + _framesPerPage).clamp(0, parsed.frames.length);
      final pageFrames = parsed.frames.sublist(i, end);
      totalSamples += pageFrames.length * _samplesPerFrame48k;

      final isLast = end >= parsed.frames.length;
      builder.add(
        _buildOggPage(
          granulePosition: totalSamples,
          serialNumber: _serialNumber,
          pageSequence: pageSeq++,
          headerType: isLast ? 0x04 : 0x00, // EOS on last page
          packets: pageFrames.map((f) => f.data).toList(),
        ),
      );
    }

    return builder.toBytes();
  }

  // ════════════════════════════════════════════════════════════
  //  Opus header packets
  // ════════════════════════════════════════════════════════════

  /// Build the 19-byte OpusHead identification header (RFC 7845 §5.1).
  static Uint8List _buildOpusHead({
    required int channels,
    required int preSkip,
    required int inputSampleRate,
  }) {
    final buf = ByteData(19);
    // "OpusHead" magic
    final magic = 'OpusHead'.codeUnits;
    for (int i = 0; i < 8; i++) {
      buf.setUint8(i, magic[i]);
    }
    buf.setUint8(8, 1); // Version
    buf.setUint8(9, channels); // Channel count
    buf.setUint16(10, preSkip, Endian.little); // Pre-skip
    buf.setUint32(12, inputSampleRate, Endian.little); // Input sample rate
    buf.setInt16(16, 0, Endian.little); // Output gain (dB Q7.8)
    buf.setUint8(18, 0); // Channel mapping family (0 = mono/stereo)
    return buf.buffer.asUint8List();
  }

  /// Build the OpusTags comment header (RFC 7845 §5.2).
  static Uint8List _buildOpusTags() {
    const vendor = 'ZSWatch';
    final vendorBytes = vendor.codeUnits;
    // 8 (magic) + 4 (vendor len) + vendor + 4 (comment count)
    final length = 8 + 4 + vendorBytes.length + 4;
    final buf = ByteData(length);

    // "OpusTags" magic
    final magic = 'OpusTags'.codeUnits;
    for (int i = 0; i < 8; i++) {
      buf.setUint8(i, magic[i]);
    }
    buf.setUint32(8, vendorBytes.length, Endian.little);
    for (int i = 0; i < vendorBytes.length; i++) {
      buf.setUint8(12 + i, vendorBytes[i]);
    }
    buf.setUint32(12 + vendorBytes.length, 0, Endian.little); // No comments

    return buf.buffer.asUint8List();
  }

  // ════════════════════════════════════════════════════════════
  //  Ogg page builder
  // ════════════════════════════════════════════════════════════

  /// Build a single Ogg page containing one or more packets.
  ///
  /// [headerType] flags: 0x01 = continuation, 0x02 = BOS, 0x04 = EOS.
  static Uint8List _buildOggPage({
    required int granulePosition,
    required int serialNumber,
    required int pageSequence,
    required int headerType,
    required List<Uint8List> packets,
  }) {
    // Build segment table: each packet is split into 255-byte segments
    // with a final segment < 255 (or 0 if exactly a multiple of 255).
    final segmentTable = <int>[];
    for (final packet in packets) {
      int remaining = packet.length;
      while (remaining >= 255) {
        segmentTable.add(255);
        remaining -= 255;
      }
      segmentTable.add(remaining); // final segment (0–254)
    }

    final numSegments = segmentTable.length;
    final headerSize = 27 + numSegments;
    final dataSize = packets.fold<int>(0, (sum, p) => sum + p.length);
    final pageSize = headerSize + dataSize;

    final page = Uint8List(pageSize);
    final bd = ByteData.sublistView(page);

    // Capture pattern: "OggS"
    page[0] = 0x4F; // O
    page[1] = 0x67; // g
    page[2] = 0x67; // g
    page[3] = 0x53; // S

    // Stream structure version
    bd.setUint8(4, 0);

    // Header type flag
    bd.setUint8(5, headerType);

    // Granule position (64-bit LE)
    bd.setUint32(6, granulePosition & 0xFFFFFFFF, Endian.little);
    bd.setUint32(10, (granulePosition >> 32) & 0xFFFFFFFF, Endian.little);

    // Serial number
    bd.setUint32(14, serialNumber, Endian.little);

    // Page sequence number
    bd.setUint32(18, pageSequence, Endian.little);

    // CRC32 — set to 0 initially, computed over the full page
    bd.setUint32(22, 0, Endian.little);

    // Number of page segments
    bd.setUint8(26, numSegments);

    // Segment table
    for (int i = 0; i < numSegments; i++) {
      page[27 + i] = segmentTable[i];
    }

    // Packet data
    int offset = headerSize;
    for (final packet in packets) {
      page.setRange(offset, offset + packet.length, packet);
      offset += packet.length;
    }

    // Compute and insert CRC32
    final crc = _oggCrc32(page);
    bd.setUint32(22, crc, Endian.little);

    return page;
  }

  // ════════════════════════════════════════════════════════════
  //  Ogg CRC-32
  // ════════════════════════════════════════════════════════════

  /// Ogg uses CRC-32 with polynomial 0x04C11DB7 (unreflected),
  /// initial value 0, no final XOR — different from the common
  /// "CRC-32" (ISO 3309 / ITU-T V.42) which uses reflected I/O.
  static int _oggCrc32(Uint8List data) {
    int crc = 0;
    for (final byte in data) {
      crc = (_crcTable[((crc >> 24) ^ byte) & 0xFF] ^ (crc << 8)) & 0xFFFFFFFF;
    }
    return crc;
  }

  static final List<int> _crcTable = _generateCrcTable();

  static List<int> _generateCrcTable() {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int crc = i << 24;
      for (int j = 0; j < 8; j++) {
        if (crc & 0x80000000 != 0) {
          crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF;
        } else {
          crc = (crc << 1) & 0xFFFFFFFF;
        }
      }
      table[i] = crc;
    }
    return table;
  }
}
