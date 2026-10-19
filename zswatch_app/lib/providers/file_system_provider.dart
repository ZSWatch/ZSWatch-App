import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models/fs_file_entry.dart';
import '../services/filesystem/file_system_service.dart';
import '../services/watch_service.dart';
import 'watch_service_provider.dart';
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
  final FileSystemService _service;
  final WatchService? _watchService;
  final Future<CompanionLogFiles> Function(String? path)? _nativeInspect;
  final String? _cacheScope;

  FileSystemNotifier(
    this._service,
    this._watchService, {
    Future<CompanionLogFiles> Function(String? path)? nativeInspect,
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
    if (native != null) {
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
      return;
    }
    final device = _watchService!.device;
    if (device == null) {
      state = state.copyWith(loadError: 'No device connected');
      return;
    }

    state = state.copyWith(isLoadingLogs: true, loadError: null);
    final smpGen = _watchService.connectionGeneration;
    try {
      await _watchService.enableSmp();
      await Future<void>.delayed(const Duration(seconds: 2));
      final smpReady = await _watchService.rediscoverServices();
      if (!smpReady) {
        throw Exception('SMP service did not become available');
      }

      final files = await _service.probeFiles(
        FileSystemService.logDir,
        FileSystemService.logFilePrefix,
        FileSystemService.logFilesLimit,
        device.remoteId.str,
      );
      state = state.copyWith(isLoadingLogs: false, logFiles: files);
    } catch (e) {
      _log('refreshLogs failed: $e');
      state = state.copyWith(isLoadingLogs: false, loadError: e.toString());
    } finally {
      try {
        await _watchService.disableSmpIfConnectionUnchanged(smpGen);
      } catch (e) {
        _log('Failed to disable SMP: $e');
      }
    }
  }

  Future<void> refreshFiles() async {
    state = state.copyWith(isLoadingFiles: false, otherFiles: const []);
  }

  Future<void> downloadFile(FsFileEntry entry) async {
    if (state.downloadingPath != null || state.isLoadingLogs) return;
    final native = _nativeInspect;
    if (native != null) {
      state = state.copyWith(
        downloadingPath: entry.path,
        downloadProgress: 0.0,
      );
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
      return;
    }

    final device = _watchService!.device;
    if (device == null) {
      _log('No device connected');
      return;
    }

    state = state.copyWith(downloadingPath: entry.path, downloadProgress: 0.0);

    final smpGen = _watchService.connectionGeneration;
    try {
      _log('Enabling SMP server for file download');
      await _watchService.enableSmp();
      await Future<void>.delayed(const Duration(seconds: 2));
      final smpReady = await _watchService.rediscoverServices();
      if (!smpReady) {
        throw Exception('SMP service did not become available');
      }

      final data = await _service.downloadFile(
        entry.path,
        device.remoteId.str,
        (progress) {
          state = state.copyWith(downloadProgress: progress);
        },
      );

      final localPath = await _saveToLocalStorage(entry.name, data);
      _log('Saved to: $localPath');

      final updated = Map<String, String>.from(state.downloadedPaths);
      updated[entry.path] = localPath;

      state = state.copyWith(
        downloadingPath: null,
        downloadProgress: 0.0,
        downloadedPaths: updated,
      );
    } catch (e) {
      _log('downloadFile failed: $e');
      state = state.copyWith(downloadingPath: null, downloadProgress: 0.0);
      rethrow;
    } finally {
      _log('Disabling SMP server');
      try {
        await _watchService.disableSmpIfConnectionUnchanged(smpGen);
      } catch (e) {
        _log('Failed to disable SMP: $e');
      }
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

  void _log(String message) {
    debugPrint('[FileSystem] $message');
  }
}

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

final fileSystemProvider =
    StateNotifierProvider<FileSystemNotifier, FileSystemState>((ref) {
      final service = ref.watch(fileSystemServiceProvider);
      if (ref.watch(nativeCompanionRuntimeProvider)) {
        // Replacing the selected watch disposes in-flight UI state. Reconnects
        // and unrelated status updates keep the same notifier; native generation
        // fences still protect the service-owned SMP operation itself.
        final address = ref.watch(
          companionSnapshotProvider.select(
            (snapshot) => snapshot.valueOrNull?.fields['address'] as String?,
          ),
        );
        return FileSystemNotifier(
          service,
          null,
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
      }
      return FileSystemNotifier(service, ref.watch(watchServiceProvider));
    });
