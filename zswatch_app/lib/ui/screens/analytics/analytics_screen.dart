import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/connection_analytics_repository.dart';
import '../../../providers/analytics_providers.dart';

/// Analytics screen showing Battery and Connection analytics
///
/// Features:
/// - Battery level history charts (24h / 7d)
/// - Battery drain rate and estimated time remaining
/// - Connection uptime and stability metrics
/// - Disconnection history and reasons
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedWatchId = ref.watch(selectedWatchIdProvider);
    
    // Ensure analytics services are started
    ref.watch(analyticsServicesInitializedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.battery_std), text: 'Battery'),
            Tab(icon: Icon(Icons.bluetooth_connected), text: 'Connection'),
          ],
        ),
      ),
      body: selectedWatchId == null
          ? const _NoWatchSelected()
          : TabBarView(
              controller: _tabController,
              children: [
                _BatteryAnalyticsTab(watchId: selectedWatchId),
                _ConnectionAnalyticsTab(watchId: selectedWatchId),
              ],
            ),
    );
  }
}

// ============================================================================
// No Watch Selected Placeholder
// ============================================================================

class _NoWatchSelected extends StatelessWidget {
  const _NoWatchSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.watch_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'No watch selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Connect to a watch to view analytics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Battery Analytics Tab
// ============================================================================

class _BatteryAnalyticsTab extends ConsumerWidget {
  final String watchId;

  const _BatteryAnalyticsTab({required this.watchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings24h = ref.watch(batteryReadings24HoursProvider(watchId));
    final drainRate = ref.watch(batteryDrainRateProvider(watchId));
    final estimatedTime = ref.watch(estimatedBatteryTimeProvider(watchId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(batteryReadings24HoursProvider(watchId));
        ref.invalidate(batteryDrainRateProvider(watchId));
        ref.invalidate(estimatedBatteryTimeProvider(watchId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Battery Stats Card
            _BatteryStatsCard(
              drainRate: drainRate.valueOrNull,
              estimatedTime: estimatedTime.valueOrNull,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // 24-hour chart
            _BatteryChartCard(
              title: 'Last 24 Hours',
              readings: readings24h.valueOrNull ?? [],
              isLoading: readings24h.isLoading,
              error: readings24h.error?.toString(),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Info card
            _BatteryInfoCard(),
          ],
        ),
      ),
    );
  }
}

class _BatteryStatsCard extends StatelessWidget {
  final double? drainRate;
  final Duration? estimatedTime;

  const _BatteryStatsCard({
    required this.drainRate,
    required this.estimatedTime,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery Stats',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.trending_down,
                    iconColor: Colors.orange,
                    label: 'Drain Rate',
                    value: drainRate != null
                        ? '${drainRate!.toStringAsFixed(1)}%/hr'
                        : '--',
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: _StatTile(
                    icon: Icons.access_time,
                    iconColor: colorScheme.primary,
                    label: 'Est. Remaining',
                    value: estimatedTime != null
                        ? _formatDuration(estimatedTime!)
                        : '--',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 24) {
      final days = duration.inHours ~/ 24;
      final hours = duration.inHours % 24;
      return '${days}d ${hours}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}

class _BatteryChartCard extends StatelessWidget {
  final String title;
  final List<BatteryReadingEntity> readings;
  final bool isLoading;
  final String? error;

  const _BatteryChartCard({
    required this.title,
    required this.readings,
    required this.isLoading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            SizedBox(
              height: 200,
              child: _buildContent(context, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: TextStyle(color: colorScheme.error),
        ),
      );
    }

    if (readings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.battery_unknown,
              size: 48,
              color: colorScheme.outline,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'No battery data yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              'Battery level is recorded when\nthe watch sends status updates',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.surfaceContainerHighest,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == 50 || value == 100) {
                  return Text(
                    '${value.toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _calculateInterval(readings),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= readings.length) {
                  return const SizedBox.shrink();
                }
                final time = readings[index].timestamp;
                return Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: readings.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.level.toDouble());
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withOpacity(0.2),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= readings.length) return null;
                final reading = readings[index];
                final time = reading.timestamp;
                return LineTooltipItem(
                  '${reading.level}%\n${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                  TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _calculateInterval(List<BatteryReadingEntity> readings) {
    if (readings.length <= 6) return 1;
    return (readings.length / 6).ceilToDouble();
  }
}

class _BatteryInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: colorScheme.outline,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text(
                'Battery data is recorded when the watch sends status updates. '
                'More accurate estimates require at least 1 hour of data.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Connection Analytics Tab
// ============================================================================

class _ConnectionAnalyticsTab extends ConsumerWidget {
  final String watchId;

  const _ConnectionAnalyticsTab({required this.watchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats24h = ref.watch(connectionStats24HoursProvider(watchId));
    final stats7d = ref.watch(connectionStats7DaysProvider(watchId));
    final eventsAsync = ref.watch(connectionEventsStreamProvider(watchId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(connectionStats24HoursProvider(watchId));
        ref.invalidate(connectionStats7DaysProvider(watchId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Uptime Card
            _UptimeCard(
              stats24h: stats24h.valueOrNull,
              stats7d: stats7d.valueOrNull,
              isLoading: stats24h.isLoading || stats7d.isLoading,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Connection Stats Card
            _ConnectionStatsCard(
              stats: stats24h.valueOrNull,
              isLoading: stats24h.isLoading,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Recent Events Card
            _RecentEventsCard(
              events: eventsAsync.valueOrNull ?? [],
              isLoading: eventsAsync.isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _UptimeCard extends StatelessWidget {
  final ConnectionStats? stats24h;
  final ConnectionStats? stats7d;
  final bool isLoading;

  const _UptimeCard({
    required this.stats24h,
    required this.stats7d,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Uptime',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: _UptimeIndicator(
                      label: '24 Hours',
                      percentage: stats24h?.uptimePercentage ?? 0,
                      colorScheme: colorScheme,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingLg),
                  Expanded(
                    child: _UptimeIndicator(
                      label: '7 Days',
                      percentage: stats7d?.uptimePercentage ?? 0,
                      colorScheme: colorScheme,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UptimeIndicator extends StatelessWidget {
  final String label;
  final double percentage;
  final ColorScheme colorScheme;

  const _UptimeIndicator({
    required this.label,
    required this.percentage,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getUptimeColor(percentage);

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Color _getUptimeColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 70) return Colors.orange;
    return Colors.red;
  }
}

class _ConnectionStatsCard extends StatelessWidget {
  final ConnectionStats? stats;
  final bool isLoading;

  const _ConnectionStatsCard({
    required this.stats,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 24 Hours',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.link_off,
                      iconColor: Colors.orange,
                      label: 'Disconnections',
                      value: stats?.disconnectionCount.toString() ?? '0',
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.timer,
                      iconColor: colorScheme.primary,
                      label: 'Avg Session',
                      value: stats != null
                          ? _formatDuration(stats!.averageSessionDuration)
                          : '--',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.replay,
                    iconColor: Colors.blue,
                    label: 'Reconnects',
                    value: stats != null
                        ? (stats!.successfulReconnections + stats!.failedReconnections).toString()
                        : '0',
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: _StatTile(
                    icon: Icons.schedule,
                    iconColor: Colors.green,
                    label: 'Total Connected',
                    value: stats?.totalConnectedTime != null
                        ? _formatDuration(stats!.totalConnectedTime)
                        : '--',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 24) {
      final days = duration.inHours ~/ 24;
      final hours = duration.inHours % 24;
      return '${days}d ${hours}h';
    } else if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}

class _RecentEventsCard extends StatelessWidget {
  final List<ConnectionEventEntity> events;
  final bool isLoading;

  const _RecentEventsCard({
    required this.events,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Events',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (events.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'No connection events yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.take(10).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _EventListTile(event: event);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final ConnectionEventEntity event;

  const _EventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = _getEventDisplay(event);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        _formatTimestamp(event.timestamp),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: event.reason != null
          ? Chip(
              label: Text(
                event.reason!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }

  (IconData, Color, String) _getEventDisplay(ConnectionEventEntity event) {
    switch (event.eventType) {
      case 'connected':
        return (Icons.bluetooth_connected, Colors.green, 'Connected');
      case 'disconnected':
        return (Icons.bluetooth_disabled, Colors.red, 'Disconnected');
      case 'reconnect_attempt':
        return (Icons.replay, Colors.orange, 'Reconnecting...');
      case 'reconnect_failed':
        return (Icons.error_outline, Colors.red, 'Reconnect Failed');
      default:
        return (Icons.help_outline, Colors.grey, event.eventType);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

// ============================================================================
// Shared Widgets
// ============================================================================

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppTheme.spacingXs),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
