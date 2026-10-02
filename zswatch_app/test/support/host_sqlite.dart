import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

/// Linux runners can have SQLite's runtime SONAME without the development link.
/// Only host tests use this loader; mobile keeps sqlite3_flutter_libs packaging.
void configureHostSqlite() {
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
}
