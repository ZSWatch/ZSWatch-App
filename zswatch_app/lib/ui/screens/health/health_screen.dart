import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/app_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/health_sample.dart';
import '../../../providers/health_providers.dart';
import '../../../providers/watch_service_provider.dart';
import '../../widgets/real_time_chart.dart';

/// Activity state colors
const _activityColors = {
  ActivityState.unknown: Color(0xFF757575),     // Dark Gray
  ActivityState.notWorn: Color(0xFF9E9E9E),     // Gray
  ActivityState.deepSleep: Color(0xFF3F51B5),   // Indigo
  ActivityState.lightSleep: Color(0xFF7986CB),  // Light Indigo
  ActivityState.remSleep: Color(0xFF9C27B0),    // Purple
  ActivityState.still: Color(0xFF2196F3),       // Blue
  ActivityState.running: Color(0xFFFF5722),     // Deep Orange
  ActivityState.walking: Color(0xFF4CAF50),     // Green
  ActivityState.swimming: Color(0xFF00BCD4),    // Cyan
  ActivityState.cycling: Color(0xFFFFEB3B),     // Yellow
  ActivityState.exercise: Color(0xFFE91E63),    // Pink
};

/// Health screen showing step counts and heart rate data
///
/// Features:
/// - Today's step summary
/// - Hourly/daily/weekly step breakdown charts
/// - Heart rate card with link to live streaming
class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final range = switch (_tabController.index) {
        0 => StepsHistoryRange.day,
        1 => StepsHistoryRange.week,
        2 => StepsHistoryRange.month,
        _ => StepsHistoryRange.day,
      };
      ref.read(stepsHistoryProvider.notifier).loadData(range);
      ref.read(activityBreakdownProvider.notifier).loadData(range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepsHistory = ref.watch(stepsHistoryProvider);
    final hrHistory = ref.watch(heartRateHistoryProvider);
    final activityBreakdownState = ref.watch(activityBreakdownProvider);
    final isConnected = ref.watch(isWatchConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(stepsHistoryProvider.notifier).refresh();
              ref.read(heartRateHistoryProvider.notifier).refresh();
              ref.read(activityBreakdownProvider.notifier).refresh();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Week'),
            Tab(text: 'Month'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(stepsHistoryProvider.notifier).refresh();
          await ref.read(heartRateHistoryProvider.notifier).refresh();
          await ref.read(activityBreakdownProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Activity breakdown card (pie chart)
              _ActivityBreakdownCard(
                breakdown: activityBreakdownState.breakdown,
                range: activityBreakdownState.range,
                isLoading: activityBreakdownState.isLoading,
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Steps summary card
              _StepsSummaryCard(
                totalSteps: stepsHistory.totalSteps,
                isLoading: stepsHistory.isLoading,
                range: stepsHistory.range,
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Steps chart
              _StepsChartCard(
                data: stepsHistory.data,
                isLoading: stepsHistory.isLoading,
                range: stepsHistory.range,
                error: stepsHistory.error,
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Heart rate card
              _HeartRateCard(
                latestHr: hrHistory.todayAggregate?.average.round(),
                minHr: hrHistory.todayAggregate?.min.round(),
                maxHr: hrHistory.todayAggregate?.max.round(),
                sampleCount: hrHistory.todayReadings.length,
                isConnected: isConnected,
                onTap: () => context.push(AppRoutes.heartRate),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // Info about data sync
              if (!isConnected)
                const _ConnectionWarning(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepsSummaryCard extends StatelessWidget {
  final int totalSteps;
  final bool isLoading;
  final StepsHistoryRange range;

  const _StepsSummaryCard({
    required this.totalSteps,
    required this.isLoading,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    final rangeLabel = switch (range) {
      StepsHistoryRange.day => "Today's",
      StepsHistoryRange.week => 'This Week',
      StepsHistoryRange.month => 'This Month',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            Text(
              rangeLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            if (isLoading)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.directions_walk,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    _formatSteps(totalSteps),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'steps',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 10000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }
}

class _ActivityBreakdownCard extends StatelessWidget {
  final ActivityBreakdown breakdown;
  final StepsHistoryRange range;
  final bool isLoading;

  const _ActivityBreakdownCard({
    required this.breakdown,
    required this.range,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = breakdown.totalDuration > Duration.zero;
    
    final rangeLabel = switch (range) {
      StepsHistoryRange.day => "Today's",
      StepsHistoryRange.week => 'This Week',
      StepsHistoryRange.month => 'This Month',
    };
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  '$rangeLabel Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (breakdown.currentState != null && range == StepsHistoryRange.day)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
                      vertical: AppTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: _activityColors[breakdown.currentState]?.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _activityColors[breakdown.currentState],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          breakdown.currentState!.displayName,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _activityColors[breakdown.currentState],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            if (isLoading)
              const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!hasData)
              SizedBox(
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.watch_later_outlined,
                        size: 48,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        range == StepsHistoryRange.day 
                            ? 'Waiting for activity data...'
                            : 'No activity data for this period',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Pie chart
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: _buildPieSections(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingLg),
                  // Legend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildLegendItems(context),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final sections = <PieChartSectionData>[];
    
    for (final state in ActivityState.values) {
      if (state == ActivityState.unknown) continue;
      
      final percentage = breakdown.getPercentage(state);
      if (percentage <= 0) continue;
      
      sections.add(
        PieChartSectionData(
          value: percentage * 100,
          color: _activityColors[state],
          radius: 25,
          showTitle: false,
        ),
      );
    }
    
    return sections;
  }

  List<Widget> _buildLegendItems(BuildContext context) {
    final items = <Widget>[];
    
    for (final state in ActivityState.values) {
      if (state == ActivityState.unknown) continue;
      
      final duration = breakdown.durations[state] ?? Duration.zero;
      final percentage = breakdown.getPercentage(state);
      
      if (duration > Duration.zero || state == breakdown.currentState) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _activityColors[state],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    state.displayName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    if (items.isEmpty) {
      items.add(
        Text(
          'No activity recorded',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }
    
    return items;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${duration.inSeconds}s';
  }
}

class _StepsChartCard extends StatelessWidget {
  final List<HealthAggregate> data;
  final bool isLoading;
  final StepsHistoryRange range;
  final String? error;

  const _StepsChartCard({
    required this.data,
    required this.isLoading,
    required this.range,
    this.error,
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
                const Icon(Icons.bar_chart, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  'Step Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            if (isLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              )
            else
              StepsBarChart(
                data: _convertToBarData(),
                height: 200,
                stepGoal: range == StepsHistoryRange.day ? 10000 : null,
              ),
          ],
        ),
      ),
    );
  }

  List<StepsBarData> _convertToBarData() {
    if (data.isEmpty) return [];

    return data.map((aggregate) {
      final label = switch (range) {
        StepsHistoryRange.day => _formatHour(aggregate.periodStart),
        StepsHistoryRange.week => _formatWeekday(aggregate.periodStart),
        StepsHistoryRange.month => _formatDayOfMonth(aggregate.periodStart),
      };
      return StepsBarData(
        label: label,
        steps: aggregate.total.round(),
      );
    }).toList();
  }

  String _formatHour(DateTime dt) {
    final hour = dt.hour;
    if (hour == 0) return '12a';
    if (hour == 12) return '12p';
    if (hour < 12) return '${hour}a';
    return '${hour - 12}p';
  }

  String _formatWeekday(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  String _formatDayOfMonth(DateTime dt) {
    return '${dt.day}';
  }
}

class _HeartRateCard extends StatelessWidget {
  final int? latestHr;
  final int? minHr;
  final int? maxHr;
  final int sampleCount;
  final bool isConnected;
  final VoidCallback onTap;

  const _HeartRateCard({
    this.latestHr,
    this.minHr,
    this.maxHr,
    required this.sampleCount,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: AppTheme.errorColor),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'Heart Rate',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              if (latestHr == null && sampleCount == 0)
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.heart_broken,
                        size: 48,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'No heart rate data today',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      Text(
                        'Tap to start live monitoring',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _HrStatItem(
                        label: 'Avg',
                        value: latestHr,
                        unit: 'BPM',
                      ),
                    ),
                    Expanded(
                      child: _HrStatItem(
                        label: 'Min',
                        value: minHr,
                        unit: 'BPM',
                      ),
                    ),
                    Expanded(
                      child: _HrStatItem(
                        label: 'Max',
                        value: maxHr,
                        unit: 'BPM',
                      ),
                    ),
                  ],
                ),
              if (sampleCount > 0) ...[
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  '$sampleCount readings today',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HrStatItem extends StatelessWidget {
  final String label;
  final int? value;
  final String unit;

  const _HrStatItem({
    required this.label,
    this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value?.toString() ?? '--',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectionWarning extends StatelessWidget {
  const _ConnectionWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bluetooth_disabled,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watch not connected',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  'Connect your watch to sync health data',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
