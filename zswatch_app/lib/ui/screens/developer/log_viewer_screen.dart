import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/log_entry.dart';
import '../../../data/models/log_filter.dart'; // For LogStreamingState
import '../../../providers/developer_providers.dart';
import '../../../providers/watch_service_provider.dart';

/// Log viewer screen displaying all incoming BLE NUS data
///
/// Features:
/// - Display ALL incoming BLE NUS data (logs + protocol messages)
/// - Timestamp and direction for each entry
/// - Auto-scroll with pause option
/// - Clear log button
/// - Filter by message type
/// - Enable/disable log streaming on watch
class LogViewerScreen extends ConsumerStatefulWidget {
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _isAtBottom = true;
  LogLevel? _levelFilter; // null = all levels

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isAtBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50;
    if (isAtBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = isAtBottom;
        // Enable auto-scroll when at bottom, disable when scrolling away
        _autoScroll = isAtBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(logEntriesProvider);
    final connection = ref.watch(watchConnectionProvider);
    final logStreamingState = ref.watch(logStreamingStateProvider);

    // Apply level filter
    final entries = _levelFilter == null
        ? allEntries
        : allEntries.where((e) => e.level == _levelFilter).toList();

    // Auto-scroll to bottom when new entries arrive
    ref.listen(logEntriesProvider, (previous, next) {
      if (_autoScroll && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
        actions: [
          // Log level filter
          PopupMenuButton<_LogLevelFilter>(
            icon: Icon(
              Icons.filter_list,
              color: _levelFilter != null ? AppTheme.primaryColor : null,
            ),
            tooltip: 'Filter by level',
            onSelected: (filter) {
              setState(() {
                _levelFilter = filter.level;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: const _LogLevelFilter(null),
                child: Row(
                  children: [
                    Icon(
                      _levelFilter == null ? Icons.check : null,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('All levels'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: const _LogLevelFilter(LogLevel.debug),
                child: Row(
                  children: [
                    Icon(
                      _levelFilter == LogLevel.debug ? Icons.check : null,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text('Debug', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const _LogLevelFilter(LogLevel.info),
                child: Row(
                  children: [
                    Icon(
                      _levelFilter == LogLevel.info ? Icons.check : null,
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const Text('Info', style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const _LogLevelFilter(LogLevel.warning),
                child: Row(
                  children: [
                    Icon(
                      _levelFilter == LogLevel.warning ? Icons.check : null,
                      size: 18,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    const Text('Warning', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const _LogLevelFilter(LogLevel.error),
                child: Row(
                  children: [
                    Icon(
                      _levelFilter == LogLevel.error ? Icons.check : null,
                      size: 18,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    const Text('Error', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),

          // Clear button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () {
              ref.read(logEntriesProvider.notifier).clear();
            },
          ),

          // More options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'copy':
                  _copyAllLogs(entries);
                  break;
                case 'scroll':
                  setState(() {
                    _autoScroll = !_autoScroll;
                  });
                  if (_autoScroll) _scrollToBottom();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy',
                child: const Row(
                  children: [
                    Icon(Icons.copy, size: 18),
                    SizedBox(width: 8),
                    Text('Copy all logs'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'scroll',
                child: Row(
                  children: [
                    Icon(
                      _autoScroll ? Icons.pause : Icons.play_arrow,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(_autoScroll ? 'Pause auto-scroll' : 'Resume auto-scroll'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Log streaming control bar
          _LogStreamingBar(
            isConnected: connection.isConnected,
            streamingState: logStreamingState,
            onToggle: () {
              ref.read(logStreamingStateProvider.notifier).toggle();
            },
          ),

          // Stats bar
          _StatsBar(
            entryCount: entries.length,
            totalCount: allEntries.length,
            autoScroll: _autoScroll,
            levelFilter: _levelFilter,
          ),

          // Log entries list
          Expanded(
            child: entries.isEmpty
                ? _EmptyState(isConnected: connection.isConnected)
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return _LogEntryTile(entry: entries[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: !_isAtBottom
          ? FloatingActionButton.small(
              onPressed: () {
                _autoScroll = true;
                _scrollToBottom();
              },
              child: const Icon(Icons.arrow_downward),
            )
          : null,
    );
  }

  void _copyAllLogs(List<LogEntry> entries) {
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer.writeln('[${entry.formattedTimestamp}] ${entry.directionArrow} ${entry.message}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${entries.length} log entries'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _LogStreamingBar extends StatelessWidget {
  final bool isConnected;
  final LogStreamingState streamingState;
  final VoidCallback onToggle;

  const _LogStreamingBar({
    required this.isConnected,
    required this.streamingState,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.podcasts,
            size: 18,
            color: streamingState.enabledOnWatch
                ? AppTheme.successColor
                : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watch Log Streaming',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  streamingState.enabledOnWatch
                      ? 'Enabled'
                      : streamingState.pending
                          ? 'Updating...'
                          : 'Disabled',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: streamingState.requestedByApp,
            onChanged: isConnected && !streamingState.pending
                ? (_) => onToggle()
                : null,
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final int entryCount;
  final int totalCount;
  final bool autoScroll;
  final LogLevel? levelFilter;

  const _StatsBar({
    required this.entryCount,
    required this.totalCount,
    required this.autoScroll,
    this.levelFilter,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = levelFilter != null;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            isFiltered ? '$entryCount / $totalCount entries' : '$entryCount entries',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          if (isFiltered) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getLevelColor(levelFilter!).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getLevelName(levelFilter!),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _getLevelColor(levelFilter!),
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
          const Spacer(),
          if (autoScroll)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward,
                  size: 12,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Auto-scroll',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.unknown:
        return Colors.grey;
    }
  }

  String _getLevelName(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.unknown:
        return 'UNKNOWN';
    }
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(entry.level);

    return InkWell(
      onTap: () => _showFullLogDialog(context),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: entry.message));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingXs,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timestamp with milliseconds
            Text(
              entry.formattedTimestamp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
            ),

            const SizedBox(width: 6),

            // Message (colored by log level)
            Expanded(
              child: Text(
                entry.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: levelColor,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue.shade300;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.unknown:
        return Colors.white70;
    }
  }

  void _showFullLogDialog(BuildContext context) {
    final levelColor = _getLevelColor(entry.level);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (entry.level != LogLevel.unknown) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.levelDisplayName,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            Text(
              entry.formattedTimestamp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            entry.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: levelColor,
                ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isConnected;

  const _EmptyState({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No log entries',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? 'Waiting for data from watch...'
                : 'Connect to watch to see logs',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

/// Wrapper class for LogLevel to allow null values in PopupMenuButton
/// (PopupMenuButton doesn't call onSelected for null values)
class _LogLevelFilter {
  final LogLevel? level;
  const _LogLevelFilter(this.level);
}
