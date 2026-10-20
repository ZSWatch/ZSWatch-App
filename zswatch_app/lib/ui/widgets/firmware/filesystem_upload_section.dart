import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_theme.dart';

/// Section for selecting a local firmware package or raw resource file for upload.
class FilesystemUploadSection extends StatelessWidget {
  final void Function(String) onFileSelected;

  const FilesystemUploadSection({super.key, required this.onFileSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
          child: Text(
            'Or Select Downloaded File',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Card(
          child: InkWell(
            onTap: () => _pickFile(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'Select .zip or .bin file',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _PushedFiles(onFileSelected: onFileSelected),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          'Select a firmware package .zip or lvgl_resources_raw.bin.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'bin'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          onFileSelected(file.path!);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not access the selected file'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

/// Packages pushed into `Application Support/dev_drop` from a computer, e.g.
/// `xcrun devicectl device copy to --domain-type appDataContainer ...`, or on
/// Android `adb push` to `Android/data/<package>/files/dev_drop`.
/// Lets hardware tests run a firmware update without the document picker.
/// Shows nothing unless such files exist.
class _PushedFiles extends StatelessWidget {
  final void Function(String) onFileSelected;

  const _PushedFiles({required this.onFileSelected});

  static Future<List<File>> _list() async {
    // Android: adb cannot write a release app's internal storage, but it can
    // write its external files directory.
    final roots = [
      await getApplicationSupportDirectory(),
      if (Platform.isAndroid) await getExternalStorageDirectory(),
    ].whereType<Directory>();
    final files = <File>[];
    for (final root in roots) {
      final dir = Directory('${root.path}/dev_drop');
      if (!dir.existsSync()) continue;
      files.addAll(
        await dir
            .list()
            .where(
              (e) =>
                  e is File &&
                  (e.path.endsWith('.zip') || e.path.endsWith('.bin')),
            )
            .cast<File>()
            .toList(),
      );
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<File>>(
      future: _list(),
      builder: (context, snapshot) {
        final files = snapshot.data ?? const <File>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final file in files)
              TextButton.icon(
                onPressed: () => onFileSelected(file.path),
                icon: const Icon(Icons.developer_mode),
                label: Text('Use pushed file: ${file.uri.pathSegments.last}'),
              ),
          ],
        );
      },
    );
  }
}
