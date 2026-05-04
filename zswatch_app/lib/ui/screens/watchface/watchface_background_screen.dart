import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/filesystem_image.dart';
import '../../../providers/filesystem_providers.dart';
import '../../../providers/watchface_background_provider.dart';
import 'watchface_crop_screen.dart';

class WatchfaceBackgroundScreen extends ConsumerStatefulWidget {
  const WatchfaceBackgroundScreen({super.key});

  @override
  ConsumerState<WatchfaceBackgroundScreen> createState() =>
      _WatchfaceBackgroundScreenState();
}

class _WatchfaceBackgroundScreenState
    extends ConsumerState<WatchfaceBackgroundScreen> {
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final bgState = ref.watch(watchfaceBackgroundProvider);
    final uploadState = ref.watch(filesystemUploadStateProvider);

    // Show snackbar on success/error
    ref.listen<WatchfaceBackgroundState>(watchfaceBackgroundProvider,
        (prev, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppTheme.successColor,
          ),
        );
        ref.read(watchfaceBackgroundProvider.notifier).clearMessages();
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        ref.read(watchfaceBackgroundProvider.notifier).clearMessages();
      }
    });

    final isBusy = bgState.isUploading || bgState.isApplying;

    return Scaffold(
      appBar: AppBar(title: const Text('Watchface Background')),
      body: Column(
        children: [
          // Upload progress
          if (bgState.isUploading) _UploadProgressBar(uploadState: uploadState),
          if (bgState.isApplying)
            const LinearProgressIndicator(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in backgroundGroups) ...[
                    Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: AppTheme.spacingSm,
                        crossAxisSpacing: AppTheme.spacingSm,
                      ),
                      itemCount: group.backgrounds.length,
                      itemBuilder: (context, index) {
                        final bg = group.backgrounds[index];
                        return _BackgroundTile(
                          name: bg.name,
                          previewAsset: bg.assetPreviewPath,
                          onTap: isBusy
                              ? null
                              : () => ref
                                  .read(watchfaceBackgroundProvider.notifier)
                                  .uploadBuiltin(bg),
                        );
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                  ],

                  Text(
                    'Custom Image',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Card(
                    child: InkWell(
                      onTap: isBusy ? null : _pickCustomImage,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMedium),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 48,
                              color: isBusy
                                  ? Theme.of(context).disabledColor
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: AppTheme.spacingSm),
                            Text(
                              'Pick from Gallery',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isBusy
                                        ? Theme.of(context).disabledColor
                                        : null,
                                  ),
                            ),
                            const SizedBox(height: AppTheme.spacingXs),
                            Text(
                              'Image will be cropped to 240x240 circle',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withValues(alpha: 0.6),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Reset button
                  OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => ref
                            .read(watchfaceBackgroundProvider.notifier)
                            .resetToDefault(),
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Default'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomImage() async {
    // maxWidth + imageQuality force Android to transcode HEIC/motion-photos
    // to JPEG, avoiding codec failures on formats Flutter can't decode.
    // 4096 is large enough to preserve quality for a 240×240 crop.
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 4096,
      imageQuality: 100,
    );
    if (file == null) return;

    if (!mounted) return;
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => WatchfaceCropScreen(imagePath: file.path),
      ),
    );
    if (croppedBytes == null) return;

    unawaited(
      ref
        .read(watchfaceBackgroundProvider.notifier)
        .uploadCroppedImage(croppedBytes),
    );
  }
}

class _BackgroundTile extends StatelessWidget {
  final String name;
  final String previewAsset;
  final VoidCallback? onTap;

  const _BackgroundTile({
    required this.name,
    required this.previewAsset,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(
              child: Image.asset(
                previewAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                color: Colors.black54,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgressBar extends StatelessWidget {
  final FilesystemUploadState uploadState;

  const _UploadProgressBar({required this.uploadState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppTheme.spacingSm),
          LinearProgressIndicator(value: uploadState.progress),
          const SizedBox(height: AppTheme.spacingXs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${uploadState.progressPercent}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${uploadState.formattedSpeed} - ETA ${uploadState.formattedTimeRemaining}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
        ],
      ),
    );
  }
}
