import 'dart:typed_data';

/// Converts image pixel data to LVGL v9 RGB565 binary format.
///
/// The output format is a 12-byte header followed by raw RGB565 pixel data,
/// suitable for loading via LVGL's filesystem image API.
class LvglImageConverter {
  static const int _magic = 0x19;
  static const int _cfRgb565 = 0x12;
  static const int _headerSize = 12;

  /// Convert RGBA8888 pixel data to LVGL v9 RGB565 binary.
  ///
  /// [rgba] must contain exactly [width] * [height] * 4 bytes (RGBA).
  /// Returns a [Uint8List] with 12-byte header + RGB565 pixel data.
  static Uint8List rgbaToLvglBin({
    required Uint8List rgba,
    required int width,
    required int height,
  }) {
    assert(rgba.length == width * height * 4);

    final stride = width * 2;
    final totalSize = _headerSize + width * height * 2;
    final output = ByteData(totalSize);

    // LVGL v9 image header (12 bytes, little-endian)
    output.setUint8(0, _magic);
    output.setUint8(1, _cfRgb565);
    output.setUint16(2, 0, Endian.little); // flags
    output.setUint16(4, width, Endian.little);
    output.setUint16(6, height, Endian.little);
    output.setUint16(8, stride, Endian.little);
    output.setUint16(10, 0, Endian.little); // reserved

    // Convert RGBA8888 to RGB565
    var outIdx = _headerSize;
    for (var i = 0; i < rgba.length; i += 4) {
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final rgb565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
      output.setUint16(outIdx, rgb565, Endian.little);
      outIdx += 2;
    }

    return output.buffer.asUint8List();
  }
}
