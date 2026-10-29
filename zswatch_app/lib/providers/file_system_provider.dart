import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/models/fs_file_entry.dart';

import 'companion_runtime_providers.dart';
import '../data/models/companion_log_files.dart';

class FileSystemState {
  final List<FsFileEntry> logFiles;
  final List<FsFileEntry> otherFiles;
  final bool isLoadingLogs;
  final bool isLoadingFiles;
  final String? loadError;
  final String? downloadingPath;
  final double downloadProgress;
  final Map<String, String> downloadedPaths;

  const FileSystemState({
    this.logFiles = const [],
    this.otherFiles = const [],
    this.isLoadingLogs = false,
    this.isLoadingFiles = false,
    this.loadError,
    this.downloadingPath,
    this.downloadProgress = 0.0,
    this.downloadedPaths = const {},
  });

  FileSystemState copyWith({
    List<FsFileEntry>? logFiles,
    List<FsFileEntry>? otherFiles,
    bool? isLoadingLogs,
    bool? isLoadingFiles,
    String? loadError,
    Object? downloadingPath = _sentinel,
    double? downloadProgress,
    Map<String, String>? downloadedPaths,
  }) {
    return FileSystemState(
      logFiles: logFiles ?? this.logFiles,
      otherFiles: otherFiles ?? this.otherFiles,
      isLoadingLogs: isLoadingLogs ?? this.isLoadingLogs,
      isLoadingFiles: isLoadingFiles ?? this.isLoadingFiles,
      loadError: loadError,
      downloadingPath: downloadingPath == _sentinel
          ? this.downloadingPath
          : downloadingPath as String?,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedPaths: downloadedPaths ?? this.downloadedPaths,
    );
  }
}

const _sentinel = Object();

class FileSystemNotifier extends StateNotifier<FileSystemState> {
  final Future<CompanionLogFiles> Function(String? path) _nativeInspect;
  final String? _cacheScope;

  FileSystemNotifier({
    required Future<CompanionLogFiles> Function(String? path) nativeInspect,
    String? nativeAddress,
  }) : _nativeInspect = nativeInspect,
       _cacheScope = nativeAddress == null
           ? null
           : sha256
                 .convert(utf8.encode(nativeAddress.toUpperCase()))
                 .toString(),
       super(const FileSystemState());

  Future<void> refreshLogs() async {
    if (state.isLoadingLogs || state.downloadingPath != null) return;
    final native = _nativeInspect;

    // The firmware exposes sizes, not a revision or content hash. A fresh
    // listing cannot establish that a previously downloaded file is unchanged.
    state = state.copyWith(
      isLoadingLogs: true,
      loadError: null,
      downloadedPaths: const {},
    );
    try {
      final result = await native(null);
      if (mounted) {
        state = state.copyWith(isLoadingLogs: false, logFiles: result.files);
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          isLoadingLogs: false,
          loadError: error.toString(),
        );
      }
    }
  }

  Future<void> refreshFiles() async {
    state = state.copyWith(isLoadingFiles: false, otherFiles: const []);
  }

  Future<void> downloadFile(FsFileEntry entry) async {
    if (state.downloadingPath != null || state.isLoadingLogs) return;
    final native = _nativeInspect;

    state = state.copyWith(downloadingPath: entry.path, downloadProgress: 0.0);
    try {
      final result = await native(entry.path);
      if (!mounted) return;
      final localPath = await _saveToLocalStorage(
        result.files.single.name,
        result.bytes!,
      );
      if (mounted) {
        state = state.copyWith(
          downloadingPath: null,
          downloadProgress: 0.0,
          downloadedPaths: {...state.downloadedPaths, entry.path: localPath},
        );
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(downloadingPath: null, downloadProgress: 0.0);
      }
      rethrow;
    }
  }

  Future<String> _saveToLocalStorage(String name, List<int> data) async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(
      p.join(appDir.path, 'fs_downloads', _cacheScope ?? ''),
    );
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }
    final file = File(p.join(downloadDir.path, name));
    await file.writeAsBytes(data);
    return file.path;
  }
}

final fileSystemProvider =
    StateNotifierProvider<FileSystemNotifier, FileSystemState>((ref) {
      // Replacing the selected watch disposes in-flight UI state. Reconnects
      // and unrelated status updates keep the same notifier; native generation
      // fences still protect the service-owned SMP operation itself.
      final address = ref.watch(
        companionSnapshotProvider.select(
          (snapshot) => snapshot.valueOrNull?.fields['address'] as String?,
        ),
      );
      return FileSystemNotifier(
        nativeAddress: address,
        nativeInspect: (path) async {
          final snapshot = ref.read(companionSnapshotProvider).requireValue;
          if (!snapshot.protocolReady ||
              snapshot.fields['address'] != address) {
            throw StateError('Current Ready session required');
          }
          final client = ref.read(companionClientProvider);
          final generation = await client.prepareShell(snapshot.generation);
          return client.inspectLogs(generation, path: path);
        },
      );
    });
