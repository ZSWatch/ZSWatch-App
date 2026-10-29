import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'lvgl_image_converter.dart';

/// Processes images for use as ZSWatch watchface backgrounds.
///
/// Handles cropping, resizing, circular masking, and LVGL binary conversion.
class WatchfaceImageProcessor {
  static const int watchSize = 240;
  static const int radius = watchSize ~/ 2;

  /// Process an already-decoded image into LVGL binary bytes.
  static Uint8List processImageBytes(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Failed to decode image');
    }

    final processed = _processImage(decoded);
    final rgba = _imageToRgba(processed);
    return LvglImageConverter.rgbaToLvglBin(
      rgba: rgba,
      width: watchSize,
      height: watchSize,
    );
  }

  static img.Image _processImage(img.Image source) {
    // Center-crop to square
    final side = min(source.width, source.height);
    final x = (source.width - side) ~/ 2;
    final y = (source.height - side) ~/ 2;
    final cropped = img.copyCrop(source, x: x, y: y, width: side, height: side);

    // Resize to 240×240
    final resized = img.copyResize(
      cropped,
      width: watchSize,
      height: watchSize,
      interpolation: img.Interpolation.linear,
    );

    // Apply circular mask — pixels outside radius become black (AMOLED off)
    for (var py = 0; py < watchSize; py++) {
      for (var px = 0; px < watchSize; px++) {
        final dx = px - radius;
        final dy = py - radius;
        if (dx * dx + dy * dy > radius * radius) {
          resized.setPixelRgba(px, py, 0, 0, 0, 255);
        }
      }
    }

    return resized;
  }

  static Uint8List _imageToRgba(img.Image image) {
    final rgba = Uint8List(image.width * image.height * 4);
    var idx = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        rgba[idx++] = pixel.r.toInt();
        rgba[idx++] = pixel.g.toInt();
        rgba[idx++] = pixel.b.toInt();
        rgba[idx++] = pixel.a.toInt();
      }
    }
    return rgba;
  }
}
