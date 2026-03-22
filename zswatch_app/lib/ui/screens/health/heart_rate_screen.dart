import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/health_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../widgets/real_time_chart.dart';

/// Heart rate screen with live streaming
///
/// Features:
/// - Real-time heart rate display
/// - Live scrolling chart
/// - Min/max/average statistics
/// - Start/stop streaming control
class HeartRateScreen extends ConsumerStatefulWidget {
  const HeartRateScreen({super.key});

  @override
  ConsumerState<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends ConsumerState<HeartRateScreen> {
  static const int _timeWindowSeconds = 60;

  @override
  Widget build(BuildContext context) {
    final hrState = ref.watch(heartRateStreamingProvider);
    final isConnected = ref.watch(isWatchConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate'),
        actions: [
          if (hrState.recentReadings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear readings',
              onPressed: () {
                ref.read(heartRateStreamingProvider.notifier).clearReadings();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current BPM display
            _CurrentBpmCard(
              currentBpm: hrState.currentBpm,
              hasData: hrState.recentReadings.isNotEmpty,
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Real-time chart
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.show_chart,
                            color: hrState.recentReadings.isNotEmpty
                                ? AppTheme.errorColor
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          Text(
                            'Heart Rate',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (hrState.recentReadings.isNotEmpty &&
                              hrState.lastUpdate != null &&
                              DateTime.now()
                                      .difference(hrState.lastUpdate!)
                                      .inSeconds <
                                  10) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.errorColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Live',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppTheme.errorColor),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      Expanded(child: _buildChart(hrState)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            // Statistics
            if (hrState.recentReadings.isNotEmpty)
              _StatisticsCard(
                average: hrState.averageBpm,
                min: hrState.minBpm,
                max: hrState.maxBpm,
                sampleCount: hrState.recentReadings.length,
              ),

            const SizedBox(height: AppTheme.spacingMd),

            // Info message when not connected
            if (!isConnected) _ConnectionWarning(),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(HeartRateStreamingState hrState) {
    if (hrState.recentReadings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'No heart rate data',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Heart rate data will appear when\nthe watch sends activity updates',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    // Convert readings to chart data
    final now = DateTime.now();
    final spots = hrState.recentReadings
        .map((reading) {
          final secondsAgo = now.difference(reading.timestamp).inSeconds;
          final x = (_timeWindowSeconds - secondsAgo).toDouble().clamp(
            0.0,
            _timeWindowSeconds.toDouble(),
          );
          return FlSpot(x.toDouble(), reading.bpm.toDouble());
        })
        .where((spot) => spot.x >= 0)
        .toList();

    // Sort by x value
    spots.sort((a, b) => a.x.compareTo(b.x));

    return RealTimeChart(
      data: spots,
      timeWindowSeconds: _timeWindowSeconds,
      lineColor: AppTheme.errorColor,
      minY: 40,
      maxY: 200,
      yAxisLabel: 'BPM',
      showGradient: true,
    );
  }
}

class _CurrentBpmCard extends StatelessWidget {
  final int? currentBpm;
  final bool hasData;

  const _CurrentBpmCard({this.currentBpm, required this.hasData});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingXl,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated heart icon
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 1.0,
                end: hasData && currentBpm != null ? 1.15 : 1.0,
              ),
              duration: const Duration(milliseconds: 300),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.favorite,
                    size: 48,
                    color: hasData && currentBpm != null
                        ? AppTheme.errorColor
                        : AppTheme.textSecondary,
                  ),
                );
              },
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentBpm?.toString() ?? '--',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: hasData && currentBpm != null
                        ? AppTheme.errorColor
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 56,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'BPM',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  final int? average;
  final int? min;
  final int? max;
  final int sampleCount;

  const _StatisticsCard({
    this.average,
    this.min,
    this.max,
    required this.sampleCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: AppTheme.textSecondary),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Session Statistics',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$sampleCount readings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Average',
                    value: average,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Min',
                    value: min,
                    color: AppTheme.successColor,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Max',
                    value: max,
                    color: AppTheme.errorColor,
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

class _StatItem extends StatelessWidget {
  final String label;
  final int? value;
  final Color color;

  const _StatItem({required this.label, this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value?.toString() ?? '--',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'BPM',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _ConnectionWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled, color: AppTheme.warningColor),
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            'Connect your watch to see heart rate',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.warningColor),
          ),
        ],
      ),
    );
  }
}
