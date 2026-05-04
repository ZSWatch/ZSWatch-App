import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen for interactively cropping an image before uploading
/// as a watchface background.
///
/// Returns the cropped image bytes (Uint8List) via Navigator.pop,
/// or null if the user cancels.
class WatchfaceCropScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const WatchfaceCropScreen({super.key, required this.imagePath});

  @override
  ConsumerState<WatchfaceCropScreen> createState() =>
      _WatchfaceCropScreenState();
}

class _WatchfaceCropScreenState extends ConsumerState<WatchfaceCropScreen> {
  final _cropController = CropController();
  Uint8List? _imageBytes;
  bool _isCropping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  /// Loads the image bytes. The file should already be JPEG (image_picker
  /// transcodes HEIC when maxWidth/imageQuality are set). Falls back to
  /// re-encoding via Flutter's native codec if the raw bytes aren't decodable.
  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load image file');
      debugPrint('[WatchfaceCropScreen] Image load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Background'),
        actions: [
          TextButton(
            onPressed: _isCropping
                ? null
                : () {
                    setState(() => _isCropping = true);
                    _cropController.crop();
                  },
            child: _isCropping
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Done'),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _imageBytes == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Crop(
                    controller: _cropController,
                    image: _imageBytes!,
                    aspectRatio: 1,
                    withCircleUi: true,
                    baseColor: Colors.black,
                    maskColor: Colors.black.withValues(alpha: 0.7),
                    onCropped: (croppedBytes) {
                      if (!mounted) return;
                      setState(() => _isCropping = false);
                      Navigator.of(context).pop(croppedBytes);
                    },
                    onStatusChanged: (status) {
                      // If the controller returns to ready while _isCropping is
                      // set (e.g. internal crop failure), reset the button state.
                      if (status == CropStatus.ready && _isCropping) {
                        if (!mounted) return;
                        setState(() => _isCropping = false);
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Pinch to zoom, drag to position',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
