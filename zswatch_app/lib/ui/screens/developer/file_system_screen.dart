import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/fs_file_entry.dart';
import '../../../providers/file_system_provider.dart';

class FileSystemScreen extends ConsumerStatefulWidget {
  const FileSystemScreen({super.key});

  @override
  ConsumerState<FileSystemScreen> createState() => _FileSystemScreenState();
}

class _FileSystemScreenState extends ConsumerState<FileSystemScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fileSystemProvider.notifier).refreshLogs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File System'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Logs'),
            Tab(text: 'Files'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LogsTab(),
          _FilesTab(),
        ],
      ),
    );
  }
}

class _LogsTab extends ConsumerWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fsState = ref.watch(fileSystemProvider);

    return Stack(
      children: [
        _LogsContent(fsState: fsState),
        if (fsState.downloadingPath != null)
          _DownloadOverlay(progress: fsState.downloadProgress),
      ],
    );
  }
}

class _LogsContent extends ConsumerWidget {
  final FileSystemState fsState;

  const _LogsContent({required this.fsState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(fileSystemProvider.notifier).refreshLogs(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (fsState.isLoadingLogs)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (fsState.loadError != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    fsState.loadError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else if (fsState.logFiles.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No log files found. Enable filesystem logging in debug firmware.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = fsState.logFiles[index];
                  final isDownloading = fsState.downloadingPath == entry.path;
                  final localPath = fsState.downloadedPaths[entry.path];

                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(entry.name),
                    subtitle: Text(entry.formattedSize),
                    trailing: isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : localPath != null
                        ? const Icon(Icons.check_circle_outline, color: Colors.green)
                        : const Icon(Icons.download_outlined),
                    onTap: isDownloading || fsState.downloadingPath != null
                        ? null
                        : () => _handleTap(context, ref, entry, localPath),
                  );
                },
                childCount: fsState.logFiles.length,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    FsFileEntry entry,
    String? localPath,
  ) async {
    if (localPath != null) {
      _showLogContent(context, entry, localPath);
      return;
    }

    try {
      await ref.read(fileSystemProvider.notifier).downloadFile(entry);
      final updatedPath = ref.read(fileSystemProvider).downloadedPaths[entry.path];
      if (updatedPath != null && context.mounted) {
        _showLogContent(context, entry, updatedPath);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  void _showLogContent(BuildContext context, FsFileEntry entry, String localPath) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _LogContentDialog(entry: entry, localPath: localPath),
    );
  }
}

class _LogContentDialog extends StatefulWidget {
  final FsFileEntry entry;
  final String localPath;

  const _LogContentDialog({required this.entry, required this.localPath});

  @override
  State<_LogContentDialog> createState() => _LogContentDialogState();
}

class _LogContentDialogState extends State<_LogContentDialog> {
  String? _content;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await File(widget.localPath).readAsString();
      if (mounted) setState(() => _content = content);
    } catch (e) {
      if (mounted) setState(() => _content = 'Error reading file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry.name),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _content == null
            ? const Center(child: CircularProgressIndicator())
            : Scrollbar(
                child: SingleChildScrollView(
                  child: SelectableText.rich(
                    _buildColoredText(_content!, context),
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _content ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () async {
            await Share.shareXFiles([XFile(widget.localPath)]);
          },
          child: const Text('Share'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  TextSpan _buildColoredText(String content, BuildContext context) {
    final lines = content.split('\n');
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11,
        ) ??
        const TextStyle(fontFamily: 'monospace', fontSize: 11);

    final spans = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      Color color;
      if (line.contains('<err>')) {
        color = Colors.red;
      } else if (line.contains('<wrn>')) {
        color = Colors.orange;
      } else if (line.contains('<inf>')) {
        color = Colors.lightBlue;
      } else if (line.contains('<dbg>')) {
        color = Colors.grey;
      } else {
        color = baseStyle.color ?? Colors.white;
      }

      spans.add(
        TextSpan(
          text: i < lines.length - 1 ? '$line\n' : line,
          style: baseStyle.copyWith(color: color),
        ),
      );
    }

    return TextSpan(children: spans);
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Recording files are managed via the Voice Memos screen.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _DownloadOverlay extends StatelessWidget {
  final double progress;

  const _DownloadOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: progress > 0 ? progress : null),
                const SizedBox(height: 16),
                Text(
                  progress > 0
                      ? 'Downloading… ${(progress * 100).toStringAsFixed(0)}%'
                      : 'Connecting…',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
