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
        if (isAtBottom) {
          _autoScroll = true;
        }
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
    final entries = ref.watch(logEntriesProvider);
    final connection = ref.watch(watchConnectionProvider);
    final logStreamingState = ref.watch(logStreamingStateProvider);

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
            autoScroll: _autoScroll,
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
  final bool autoScroll;

  const _StatsBar({
    required this.entryCount,
    required this.autoScroll,
  });

  @override
  Widget build(BuildContext context) {
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
            '$entryCount entries',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
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
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isIncoming = entry.direction == LogDirection.incoming;
    final typeColor = _getTypeColor(entry.type);

    return InkWell(
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
            // Timestamp
            SizedBox(
              width: 85,
              child: Text(
                entry.formattedTimestamp,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
              ),
            ),

            // Direction indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                isIncoming ? Icons.arrow_back : Icons.arrow_forward,
                size: 14,
                color: isIncoming ? AppTheme.successColor : AppTheme.primaryColor,
              ),
            ),

            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.typeDisplayName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: typeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            // Message
            Expanded(
              child: Text(
                entry.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(LogEntryType type) {
    switch (type) {
      case LogEntryType.log:
        return Colors.grey;
      case LogEntryType.notification:
        return Colors.orange;
      case LogEntryType.music:
        return Colors.purple;
      case LogEntryType.activity:
        return Colors.green;
      case LogEntryType.status:
        return Colors.blue;
      case LogEntryType.gps:
        return Colors.teal;
      case LogEntryType.weather:
        return Colors.cyan;
      case LogEntryType.call:
        return Colors.red;
      case LogEntryType.find:
        return Colors.amber;
      case LogEntryType.navigation:
        return Colors.indigo;
      case LogEntryType.http:
        return Colors.brown;
      case LogEntryType.alarm:
        return Colors.pink;
      case LogEntryType.calendar:
        return Colors.deepPurple;
      case LogEntryType.alert:
        return Colors.redAccent;
      case LogEntryType.other:
        return Colors.blueGrey;
    }
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
