import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zswatch_app/services/voice_memo/zsw_opus_parser.dart';
import 'package:zswatch_app/services/voice_memo/ogg_opus_writer.dart';
import 'package:zswatch_app/data/models/voice_memo.dart';

/// Build a valid .zsw_opus binary blob for testing.
///
/// Returns raw bytes with a 32-byte header + [frameCount] frames,
/// each containing [frameLenBytes] bytes of dummy Opus data.
Uint8List buildZswOpusFile({
  String magic = 'ZSWO',
  int version = 1,
  int sampleRate = 16000,
  int frameSize = 160,
  int bitrate = 32000,
  int timestamp = 1700000000,
  int? totalFrames,
  int? durationMs,
  int frameCount = 10,
  int frameLenBytes = 20,
}) {
  totalFrames ??= frameCount;
  durationMs ??= (frameCount * frameSize * 1000) ~/ sampleRate;

  // Header: 32 bytes
  final bodySize = frameCount * (2 + frameLenBytes);
  final buf = ByteData(32 + bodySize);

  // Magic (4 bytes)
  for (var i = 0; i < 4; i++) {
    buf.setUint8(i, magic.length > i ? magic.codeUnitAt(i) : 0);
  }
  buf.setUint16(4, version, Endian.little);
  buf.setUint16(6, sampleRate, Endian.little);
  buf.setUint16(8, frameSize, Endian.little);
  buf.setUint16(10, 0, Endian.little); // reserved
  buf.setUint32(12, bitrate, Endian.little);
  buf.setUint32(16, timestamp, Endian.little);
  buf.setUint32(20, totalFrames, Endian.little);
  buf.setUint32(24, durationMs, Endian.little);
  buf.setUint32(28, 0, Endian.little); // reserved

  // Frames
  var offset = 32;
  for (var f = 0; f < frameCount; f++) {
    buf.setUint16(offset, frameLenBytes, Endian.little);
    offset += 2;
    for (var b = 0; b < frameLenBytes; b++) {
      buf.setUint8(offset + b, (f + b) & 0xFF);
    }
    offset += frameLenBytes;
  }

  return buf.buffer.asUint8List();
}

void main() {
  group('ZswOpusParser', () {
    test('parses valid file', () {
      final data = buildZswOpusFile();
      final result = ZswOpusParser.parse(data);

      expect(result, isNotNull);
      expect(result!.header.magic, 'ZSWO');
      expect(result.header.version, 1);
      expect(result.header.sampleRate, 16000);
      expect(result.header.frameSize, 160);
      expect(result.header.bitrate, 32000);
      expect(result.header.timestamp, 1700000000);
      expect(result.header.totalFrames, 10);
      expect(result.header.isDirtyStop, false);
      expect(result.frames.length, 10);
      expect(result.isValid, true);
    });

    test('returns null for data smaller than header', () {
      final data = Uint8List(16); // Too small
      expect(ZswOpusParser.parse(data), isNull);
      expect(ZswOpusParser.parseHeader(data), isNull);
    });

    test('returns null for wrong magic', () {
      final data = buildZswOpusFile(magic: 'NOPE');
      expect(ZswOpusParser.parse(data), isNull);
    });

    test('parses header-only (no frames) as invalid', () {
      // Build just the 32-byte header with no frames
      final data = buildZswOpusFile(frameCount: 0);
      final result = ZswOpusParser.parse(data);

      expect(result, isNotNull);
      expect(result!.isValid, false); // No frames → isValid = false
      expect(result.frames, isEmpty);
    });

    test('detects dirty stop (0xFFFFFFFF in totalFrames)', () {
      final data = buildZswOpusFile(totalFrames: 0xFFFFFFFF);
      final result = ZswOpusParser.parse(data);

      expect(result, isNotNull);
      expect(result!.header.isDirtyStop, true);
    });

    test('detects dirty stop (0xFFFFFFFF in durationMs)', () {
      final data = buildZswOpusFile(durationMs: 0xFFFFFFFF);
      final result = ZswOpusParser.parse(data);

      expect(result, isNotNull);
      expect(result!.header.isDirtyStop, true);
    });

    test('handles truncated frame (dirty stop mid-write)', () {
      final fullData = buildZswOpusFile(frameCount: 5, frameLenBytes: 30);
      // Chop off last 10 bytes → last frame is truncated
      final truncated = Uint8List.sublistView(
        fullData,
        0,
        fullData.length - 10,
      );
      final result = ZswOpusParser.parse(truncated);

      expect(result, isNotNull);
      // Should have 4 complete frames (5th is truncated)
      expect(result!.frames.length, 4);
    });

    test('handles zero-length frame as end marker', () {
      final data = buildZswOpusFile(frameCount: 3, frameLenBytes: 10);
      // Insert a zero-length frame after the 2nd frame
      // offset of 3rd frame = 32 + 2*(2+10) = 56
      final modified = Uint8List.fromList(data);
      modified[56] = 0;
      modified[57] = 0;

      final result = ZswOpusParser.parse(modified);
      expect(result, isNotNull);
      expect(result!.frames.length, 2); // Stops at zero-length marker
    });

    test('computed duration matches expected value', () {
      final data = buildZswOpusFile(
        frameCount: 100,
        frameSize: 160,
        sampleRate: 16000,
      );
      final result = ZswOpusParser.parse(data);

      // 100 frames * 160 samples / 16000 Hz = 1.0 seconds = 1000 ms
      expect(result!.computedDurationMs, 1000);
    });

    test('validate returns true for valid file', () {
      final data = buildZswOpusFile();
      expect(ZswOpusParser.validate(data), true);
    });

    test('validate returns false for wrong magic', () {
      final data = buildZswOpusFile(magic: 'XXXX');
      expect(ZswOpusParser.validate(data), false);
    });

    test('validate returns false for empty data', () {
      expect(ZswOpusParser.validate(Uint8List(0)), false);
    });

    test('validateDownload checks size match', () {
      final data = buildZswOpusFile();
      expect(
        ZswOpusParser.validateDownload(data, expectedSizeBytes: data.length),
        true,
      );
      expect(
        ZswOpusParser.validateDownload(
          data,
          expectedSizeBytes: data.length + 1,
        ),
        false,
      );
    });

    test('parseHeader returns header without parsing frames', () {
      final data = buildZswOpusFile(timestamp: 1234567890, bitrate: 24000);
      final header = ZswOpusParser.parseHeader(data);

      expect(header, isNotNull);
      expect(header!.timestamp, 1234567890);
      expect(header.bitrate, 24000);
    });

    test('frame data content is correct', () {
      final data = buildZswOpusFile(frameCount: 2, frameLenBytes: 5);
      final result = ZswOpusParser.parse(data);

      expect(result!.frames.length, 2);
      // First frame: bytes are (0+0)&0xFF, (0+1)&0xFF, ...
      expect(result.frames[0].data.length, 5);
      expect(result.frames[0].data[0], 0);
      expect(result.frames[0].data[1], 1);
      // Second frame: bytes are (1+0)&0xFF, (1+1)&0xFF, ...
      expect(result.frames[1].data[0], 1);
      expect(result.frames[1].data[1], 2);
    });

    test('frame fileOffset values are sequential', () {
      final data = buildZswOpusFile(frameCount: 3, frameLenBytes: 10);
      final result = ZswOpusParser.parse(data);

      expect(result!.frames[0].fileOffset, 32); // Right after header
      expect(result.frames[1].fileOffset, 32 + 12); // 2 + 10
      expect(result.frames[2].fileOffset, 32 + 24); // 2*(2+10)
    });
  });

  group('VoiceMemo model', () {
    test('syncStatus returns onWatchOnly when not synced', () {
      final memo = VoiceMemo(
        id: 1,
        filename: 'test.zsw_opus',
        timestampUtc: DateTime.utc(2025, 1, 1),
        durationMs: 5000,
        sizeBytes: 1024,
      );
      expect(memo.syncStatus, VoiceMemoSyncStatus.onWatchOnly);
    });

    test('syncStatus returns synced when downloaded', () {
      final memo = VoiceMemo(
        id: 1,
        filename: 'test.zsw_opus',
        timestampUtc: DateTime.utc(2025, 1, 1),
        durationMs: 5000,
        sizeBytes: 1024,
        syncedFromWatch: true,
        localFilePath: '/path/to/file',
      );
      expect(memo.syncStatus, VoiceMemoSyncStatus.synced);
    });

    test('syncStatus returns transcribed when transcription exists', () {
      final memo = VoiceMemo(
        id: 1,
        filename: 'test.zsw_opus',
        timestampUtc: DateTime.utc(2025, 1, 1),
        durationMs: 5000,
        sizeBytes: 1024,
        syncedFromWatch: true,
        localFilePath: '/path/to/file',
        transcription: 'Hello world',
      );
      expect(memo.syncStatus, VoiceMemoSyncStatus.transcribed);
    });

    test('formattedDuration formats correctly', () {
      expect(
        VoiceMemo(
          id: 1,
          filename: 'a',
          timestampUtc: DateTime.utc(2025),
          durationMs: 65000,
          sizeBytes: 0,
        ).formattedDuration,
        '1:05',
      );
      expect(
        VoiceMemo(
          id: 1,
          filename: 'a',
          timestampUtc: DateTime.utc(2025),
          durationMs: 3000,
          sizeBytes: 0,
        ).formattedDuration,
        '0:03',
      );
    });

    test('formattedSize formats correctly', () {
      expect(
        VoiceMemo(
          id: 1,
          filename: 'a',
          timestampUtc: DateTime.utc(2025),
          durationMs: 0,
          sizeBytes: 512,
        ).formattedSize,
        '512 B',
      );
      expect(
        VoiceMemo(
          id: 1,
          filename: 'a',
          timestampUtc: DateTime.utc(2025),
          durationMs: 0,
          sizeBytes: 2048,
        ).formattedSize,
        '2.0 KB',
      );
      expect(
        VoiceMemo(
          id: 1,
          filename: 'a',
          timestampUtc: DateTime.utc(2025),
          durationMs: 0,
          sizeBytes: 2 * 1024 * 1024,
        ).formattedSize,
        '2.0 MB',
      );
    });

    test('copyWith creates a correct copy', () {
      final memo = VoiceMemo(
        id: 1,
        filename: 'test.zsw_opus',
        timestampUtc: DateTime.utc(2025, 1, 1),
        durationMs: 5000,
        sizeBytes: 1024,
      );

      final updated = memo.copyWith(
        transcription: 'Hello',
        syncedFromWatch: true,
      );

      expect(updated.id, 1);
      expect(updated.filename, 'test.zsw_opus');
      expect(updated.transcription, 'Hello');
      expect(updated.syncedFromWatch, true);
      expect(updated.durationMs, 5000); // Unchanged
    });

    test('Equatable equality works', () {
      final a = VoiceMemo(
        id: 1,
        filename: 'a',
        timestampUtc: DateTime.utc(2025),
        durationMs: 0,
        sizeBytes: 0,
      );
      final b = VoiceMemo(
        id: 1,
        filename: 'a',
        timestampUtc: DateTime.utc(2025),
        durationMs: 0,
        sizeBytes: 0,
      );
      final c = VoiceMemo(
        id: 2,
        filename: 'a',
        timestampUtc: DateTime.utc(2025),
        durationMs: 0,
        sizeBytes: 0,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  OggOpusWriter tests
  // ═══════════════════════════════════════════════════════════

  group('OggOpusWriter', () {
    test('convert produces valid Ogg stream starting with OggS', () {
      final data = buildZswOpusFile(frameCount: 5, frameLenBytes: 20);
      final parsed = ZswOpusParser.parse(data)!;
      final ogg = OggOpusWriter.convert(parsed);

      // Must start with "OggS" capture pattern
      expect(ogg[0], 0x4F); // O
      expect(ogg[1], 0x67); // g
      expect(ogg[2], 0x67); // g
      expect(ogg[3], 0x53); // S
    });

    test('convert output contains OpusHead and OpusTags', () {
      final data = buildZswOpusFile(frameCount: 3, frameLenBytes: 10);
      final parsed = ZswOpusParser.parse(data)!;
      final ogg = OggOpusWriter.convert(parsed);
      final str = String.fromCharCodes(ogg);

      expect(str.contains('OpusHead'), isTrue);
      expect(str.contains('OpusTags'), isTrue);
    });

    test('convert produces at least 3 Ogg pages (head, tags, audio)', () {
      final data = buildZswOpusFile(frameCount: 10, frameLenBytes: 20);
      final parsed = ZswOpusParser.parse(data)!;
      final ogg = OggOpusWriter.convert(parsed);

      // Count OggS markers
      int pageCount = 0;
      for (int i = 0; i <= ogg.length - 4; i++) {
        if (ogg[i] == 0x4F &&
            ogg[i + 1] == 0x67 &&
            ogg[i + 2] == 0x67 &&
            ogg[i + 3] == 0x53) {
          pageCount++;
        }
      }
      expect(pageCount, greaterThanOrEqualTo(3));
    });

    test('first page has BOS flag set', () {
      final data = buildZswOpusFile(frameCount: 5, frameLenBytes: 20);
      final parsed = ZswOpusParser.parse(data)!;
      final ogg = OggOpusWriter.convert(parsed);

      // Byte 5 is the header type flag; BOS = 0x02
      expect(ogg[5] & 0x02, equals(0x02));
    });

    test('last page has EOS flag set', () {
      final data = buildZswOpusFile(frameCount: 5, frameLenBytes: 20);
      final parsed = ZswOpusParser.parse(data)!;
      final ogg = OggOpusWriter.convert(parsed);

      // Find the last OggS marker
      int lastPageOffset = -1;
      for (int i = ogg.length - 4; i >= 0; i--) {
        if (ogg[i] == 0x4F &&
            ogg[i + 1] == 0x67 &&
            ogg[i + 2] == 0x67 &&
            ogg[i + 3] == 0x53) {
          lastPageOffset = i;
          break;
        }
      }
      expect(lastPageOffset, greaterThan(0));
      // Byte 5 is header type; EOS = 0x04
      expect(ogg[lastPageOffset + 5] & 0x04, equals(0x04));
    });

    test('OpusHead contains correct channel count and sample rate', () {
      final data = buildZswOpusFile(
        frameCount: 3,
        frameLenBytes: 10,
        sampleRate: 16000,
      );
      final parsed = ZswOpusParser.parse(data)!;
      final ogg = OggOpusWriter.convert(parsed);

      // Find "OpusHead" in the output
      final str = String.fromCharCodes(ogg);
      final headIdx = str.indexOf('OpusHead');
      expect(headIdx, greaterThan(0));

      // OpusHead layout: magic(8) version(1) channels(1) preskip(2) samplerate(4)
      expect(ogg[headIdx + 8], 1); // version
      expect(ogg[headIdx + 9], 1); // 1 channel (mono)

      // Input sample rate at offset 12 (LE)
      final bd = ByteData.sublistView(ogg, headIdx + 12, headIdx + 16);
      expect(bd.getUint32(0, Endian.little), 16000);
    });

    test('convert output grows with more frames', () {
      final small = buildZswOpusFile(frameCount: 5, frameLenBytes: 20);
      final large = buildZswOpusFile(frameCount: 500, frameLenBytes: 20);
      final oggSmall = OggOpusWriter.convert(ZswOpusParser.parse(small)!);
      final oggLarge = OggOpusWriter.convert(ZswOpusParser.parse(large)!);

      expect(oggLarge.length, greaterThan(oggSmall.length));
    });

    test('convert handles single frame', () {
      final data = buildZswOpusFile(frameCount: 1, frameLenBytes: 40);
      final parsed = ZswOpusParser.parse(data)!;
      final ogg = OggOpusWriter.convert(parsed);

      // Should still produce valid output with OggS pages
      expect(ogg.length, greaterThan(0));
      expect(ogg[0], 0x4F); // O
    });
  });
}
