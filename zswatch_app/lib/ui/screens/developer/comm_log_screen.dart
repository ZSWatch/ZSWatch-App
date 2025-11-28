import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/comm_log_entry.dart';
import '../../../providers/developer_providers.dart';

/// Communication log screen showing all raw BLE traffic
///
/// Features:
/// - View all BLE communication (TX and RX)
/// - See data size and direction
/// - Filter by characteristic
/// - Export capability
class CommLogScreen extends ConsumerStatefulWidget {
  const CommLogScreen({super.key});

  @override
  ConsumerState<CommLogScreen> createState() => _CommLogScreenState();
}

class _CommLogScreenState extends ConsumerState<CommLogScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _isAtBottom = true;
  CommDirection? _directionFilter; // null = all, rx = incoming only, tx = outgoing only
  bool _showHex = false;

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
    final entries = ref.watch(commLogEntriesProvider);
    final stats = ref.watch(commLogStatsProvider);

    // Apply direction filter
    final filteredEntries = _directionFilter == null
        ? entries
        : entries.where((e) => e.direction == _directionFilter).toList();

    // Auto-scroll
    ref.listen(commLogEntriesProvider, (previous, next) {
      if (_autoScroll && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communication Log'),
        actions: [
          // Hex toggle
          IconButton(
            icon: Icon(_showHex ? Icons.text_fields : Icons.code),
            tooltip: _showHex ? 'Show text' : 'Show hex',
            onPressed: () {
              setState(() {
                _showHex = !_showHex;
              });
            },
          ),

          // Direction filter
          PopupMenuButton<_DirectionFilter>(
            icon: Badge(
              isLabelVisible: _directionFilter != null,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filter by direction',
            onSelected: (filter) {
              setState(() {
                _directionFilter = filter.direction;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: const _DirectionFilter(null),
                child: Row(
                  children: [
                    if (_directionFilter == null)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    const Text('All'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const _DirectionFilter(CommDirection.rx),
                child: Row(
                  children: [
                    if (_directionFilter == CommDirection.rx)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_downward, size: 16, color: AppTheme.successColor),
                    const SizedBox(width: 4),
                    const Text('RX (Incoming)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const _DirectionFilter(CommDirection.tx),
                child: Row(
                  children: [
                    if (_directionFilter == CommDirection.tx)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_upward, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    const Text('TX (Outgoing)'),
                  ],
                ),
              ),
            ],
          ),

          // Clear
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear log',
            onPressed: () {
              ref.read(commLogRepositoryProvider.notifier).clear();
            },
          ),

          // More options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'copy':
                  _copyAllEntries(filteredEntries);
                  break;
                case 'export':
                  _exportEntries(filteredEntries);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 18),
                    SizedBox(width: 8),
                    Text('Copy all'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 8),
                    Text('Export to file'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          _StatsBar(stats: stats),

          // Entries list
          Expanded(
            child: filteredEntries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      return _CommLogEntryTile(
                        entry: filteredEntries[index],
                        showHex: _showHex,
                      );
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.swap_horiz,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No communication data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'BLE traffic will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  void _copyAllEntries(List<CommLogEntry> entries) {
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer.writeln('[${entry.formattedTimestamp}] ${entry.directionArrow} ${entry.data}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${entries.length} entries'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportEntries(List<CommLogEntry> entries) {
    // TODO: Implement file export using share_plus or similar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final CommLogStats stats;

  const _StatsBar({required this.stats});

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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Entries',
            value: stats.totalEntries.toString(),
            icon: Icons.list,
          ),
          _StatItem(
            label: 'TX',
            value: _formatBytes(stats.totalTxBytes),
            icon: Icons.arrow_upward,
            color: AppTheme.primaryColor,
          ),
          _StatItem(
            label: 'RX',
            value: _formatBytes(stats.totalRxBytes),
            icon: Icons.arrow_downward,
            color: AppTheme.successColor,
          ),
          _StatItem(
            label: 'Total',
            value: _formatBytes(stats.totalBytes),
            icon: Icons.storage,
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? AppTheme.textSecondary,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}

class _CommLogEntryTile extends StatelessWidget {
  final CommLogEntry entry;
  final bool showHex;

  const _CommLogEntryTile({
    required this.entry,
    required this.showHex,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming = entry.direction == CommDirection.rx;
    final data = showHex ? _toHex(entry.data) : entry.data;

    return InkWell(
      onTap: () => _showFullEntryDialog(context, data, isIncoming),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: entry.data));
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
          color: isIncoming
              ? AppTheme.successColor.withValues(alpha: 0.05)
              : AppTheme.primaryColor.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timestamp and direction
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.formattedTimestamp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                  ),
                  Row(
                    children: [
                      Icon(
                        isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 12,
                        color: isIncoming ? AppTheme.successColor : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.sizeBytes} B',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Data
            Expanded(
              child: Text(
                data,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _toHex(String data) {
    return data.codeUnits
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();
  }

  void _showFullEntryDialog(BuildContext context, String displayData, bool isIncoming) {
    final directionColor = isIncoming ? AppTheme.successColor : AppTheme.primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: directionColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isIncoming ? 'RX' : 'TX',
                style: TextStyle(
                  color: directionColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              entry.formattedTimestamp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontFamily: 'monospace',
                  ),
            ),
            const Spacer(),
            Text(
              entry.formattedSize,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            displayData,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.data));
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

/// Wrapper class for CommDirection to allow null values in PopupMenuButton
/// (PopupMenuButton doesn't call onSelected for null values)
class _DirectionFilter {
  final CommDirection? direction;
  const _DirectionFilter(this.direction);
}
