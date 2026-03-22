import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A real-time line chart widget for streaming data
///
/// Displays a scrolling line chart that updates in real-time.
/// Used for heart rate monitoring and other streaming health data.
class RealTimeChart extends StatelessWidget {
  /// Data points to display as (x: seconds ago, y: value)
  final List<FlSpot> data;

  /// Maximum value for Y axis (auto-scaled if null)
  final double? maxY;

  /// Minimum value for Y axis (auto-scaled if null)
  final double? minY;

  /// Time window in seconds to display
  final int timeWindowSeconds;

  /// Color for the line
  final Color lineColor;

  /// Whether to show the gradient below the line
  final bool showGradient;

  /// Whether to show grid lines
  final bool showGrid;

  /// Whether to show left axis labels
  final bool showLeftAxis;

  /// Whether to show bottom axis labels
  final bool showBottomAxis;

  /// Unit label for Y axis (e.g., "BPM")
  final String? yAxisLabel;

  /// Height of the chart
  final double height;

  const RealTimeChart({
    super.key,
    required this.data,
    this.maxY,
    this.minY,
    this.timeWindowSeconds = 60,
    this.lineColor = AppTheme.primaryColor,
    this.showGradient = true,
    this.showGrid = true,
    this.showLeftAxis = true,
    this.showBottomAxis = true,
    this.yAxisLabel,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Auto-calculate Y bounds if not specified
    final calculatedMinY = minY ?? _calculateMinY();
    final calculatedMaxY = maxY ?? _calculateMaxY();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: timeWindowSeconds.toDouble(),
          minY: calculatedMinY,
          maxY: calculatedMaxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: showGrid,
            drawVerticalLine: true,
            horizontalInterval: _calculateYInterval(
              calculatedMinY,
              calculatedMaxY,
            ),
            verticalInterval: timeWindowSeconds / 6,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppTheme.elevatedSurfaceColor, strokeWidth: 1),
            getDrawingVerticalLine: (value) =>
                FlLine(color: AppTheme.elevatedSurfaceColor, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showLeftAxis,
                reservedSize: 45,
                interval: _calculateYInterval(calculatedMinY, calculatedMaxY),
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showBottomAxis,
                reservedSize: 25,
                interval: timeWindowSeconds / 6,
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        'Now',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }
                  final secondsAgo = (timeWindowSeconds - value).toInt();
                  if (secondsAgo <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '-${secondsAgo}s',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.isEmpty ? [const FlSpot(0, 0)] : data,
              isCurved: true,
              curveSmoothness: 0.2,
              color: lineColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: showGradient
                  ? BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          lineColor.withValues(alpha: 0.3),
                          lineColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    )
                  : BarAreaData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => AppTheme.elevatedSurfaceColor,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final secondsAgo = (timeWindowSeconds - spot.x).toInt();
                  return LineTooltipItem(
                    '${spot.y.toInt()}${yAxisLabel != null ? ' $yAxisLabel' : ''}\n',
                    const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: secondsAgo == 0 ? 'Now' : '${secondsAgo}s ago',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 150),
      ),
    );
  }

  double _calculateMinY() {
    if (data.isEmpty) return 0;
    final minValue = data.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    // Add 10% padding below
    return (minValue - minValue * 0.1).floorToDouble();
  }

  double _calculateMaxY() {
    if (data.isEmpty) return 100;
    final maxValue = data.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    // Add 10% padding above
    return (maxValue + maxValue * 0.1).ceilToDouble();
  }

  double _calculateYInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 0) return 10;
    // Aim for ~5 grid lines
    final rawInterval = range / 5;
    // Round to nice numbers
    if (rawInterval <= 5) return 5;
    if (rawInterval <= 10) return 10;
    if (rawInterval <= 20) return 20;
    if (rawInterval <= 50) return 50;
    return (rawInterval / 50).ceil() * 50;
  }
}

/// A bar chart for displaying step history
class StepsBarChart extends StatelessWidget {
  /// Step data as (label, value) pairs
  final List<StepsBarData> data;

  /// Maximum steps for Y axis (auto-scaled if null)
  final double? maxY;

  /// Height of the chart
  final double height;

  /// Whether to show left axis labels
  final bool showLeftAxis;

  /// Whether to show grid lines
  final bool showGrid;

  /// Color for the bars
  final Color barColor;

  /// Daily step goal (shows as horizontal line)
  final int? stepGoal;

  const StepsBarChart({
    super.key,
    required this.data,
    this.maxY,
    this.height = 200,
    this.showLeftAxis = true,
    this.showGrid = true,
    this.barColor = AppTheme.primaryColor,
    this.stepGoal,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No step data available',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final calculatedMaxY = maxY ?? _calculateMaxY();

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: calculatedMaxY,
          minY: 0,
          gridData: FlGridData(
            show: showGrid,
            drawVerticalLine: false,
            horizontalInterval: calculatedMaxY / 5,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppTheme.elevatedSurfaceColor, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showLeftAxis,
                reservedSize: 50,
                interval: calculatedMaxY / 5,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _formatStepCount(value.toInt()),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  // Only show every Nth label to avoid crowding
                  final interval = _calculateLabelInterval();
                  if (index % interval != 0 && index != data.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.steps.toDouble(),
                  color: barColor,
                  width: _calculateBarWidth(),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
          extraLinesData: stepGoal != null
              ? ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: stepGoal!.toDouble(),
                      color: AppTheme.warningColor,
                      strokeWidth: 2,
                      dashArray: [8, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        labelResolver: (line) =>
                            'Goal: ${_formatStepCount(stepGoal!)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ],
                )
              : null,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => AppTheme.elevatedSurfaceColor,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = data[group.x];
                return BarTooltipItem(
                  '${item.label}\n',
                  const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: _formatStepCount(item.steps),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _calculateMaxY() {
    if (data.isEmpty) return 10000;
    final maxValue = data.map((d) => d.steps).reduce((a, b) => a > b ? a : b);
    // Round up to next nice number
    if (maxValue <= 1000) return 1000;
    if (maxValue <= 5000) return 5000;
    if (maxValue <= 10000) return 10000;
    return ((maxValue / 5000).ceil() * 5000).toDouble();
  }

  double _calculateBarWidth() {
    // Adjust bar width based on number of data points
    if (data.length <= 7) return 20;
    if (data.length <= 14) return 12;
    if (data.length <= 24) return 8;
    return 6;
  }

  int _calculateLabelInterval() {
    // Show fewer labels when there are many data points
    if (data.length <= 7) return 1; // Show all labels for weekly view
    if (data.length <= 12) return 2; // Every 2nd for monthly view
    if (data.length <= 24) return 4; // Every 4th for hourly view (6 labels)
    return (data.length / 6).ceil(); // Aim for ~6 labels max
  }

  String _formatStepCount(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }
}

/// Data class for steps bar chart
class StepsBarData {
  final String label;
  final int steps;

  const StepsBarData({required this.label, required this.steps});
}
