/// Filesystem constants for MCUmgr filesystem upload operations
class FilesystemConstants {
  FilesystemConstants._();

  /// Target path on the watch for the LVGL resources filesystem image
  ///
  /// This is where the lvgl_resources_raw.bin gets uploaded via MCUmgr filesystem commands.
  /// The path corresponds to the external flash partition used for LVGL resources.
  static const String targetPath = '/S/full_fs';

  /// Expected filename for LVGL resources in release zips
  static const String lvglResourcesFilename = 'lvgl_resources_raw.bin';

  /// Alternative filenames that might be used
  static const List<String> alternativeFilenames = [
    'lvgl_resources_raw.bin',
    'lvgl_resources.bin',
    'full_fs.bin',
  ];

  /// Check if a filename is a filesystem image
  static bool isFilesystemImage(String filename) {
    final lower = filename.toLowerCase();
    return alternativeFilenames.any(
      (name) => lower.endsWith(name.toLowerCase()),
    );
  }
}
