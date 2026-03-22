import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A circular ring widget that displays battery level
///
/// Features:
/// - Animated fill based on battery percentage
/// - Color changes based on level (green/amber/red)
/// - Optional center content (percentage text, icon, etc.)
/// - Customizable size and stroke width
class BatteryRing extends StatelessWidget {
  /// Battery level (0-100)
  final int level;

  /// Size of the ring (diameter)
  final double size;

  /// Width of the ring stroke
  final double strokeWidth;

  /// Whether to show percentage text in center
  final bool showPercentage;

  /// Optional custom center widget
  final Widget? centerWidget;

  /// Whether the watch is charging
  final bool isCharging;

  /// Animation duration
  final Duration animationDuration;

  const BatteryRing({
    super.key,
    required this.level,
    this.size = 80,
    this.strokeWidth = 8,
    this.showPercentage = true,
    this.centerWidget,
    this.isCharging = false,
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0, 100);
    final color = AppTheme.getBatteryColor(clampedLevel);
    final gradient = AppTheme.getBatteryGradient(clampedLevel);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CustomPaint(
            size: Size(size, size),
            painter: _BatteryRingPainter(
              progress: 1.0,
              strokeWidth: strokeWidth,
              color: AppTheme.surfaceColor,
              gradient: null,
            ),
          ),
          // Foreground ring (animated)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clampedLevel / 100),
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CustomPaint(
                size: Size(size, size),
                painter: _BatteryRingPainter(
                  progress: value,
                  strokeWidth: strokeWidth,
                  color: color,
                  gradient: gradient,
                ),
              );
            },
          ),
          // Center content
          if (centerWidget != null)
            centerWidget!
          else if (showPercentage)
            _buildCenterContent(clampedLevel, color),
        ],
      ),
    );
  }

  Widget _buildCenterContent(int level, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCharging)
          Icon(Icons.bolt_rounded, size: size * 0.2, color: color),
        Text(
          '$level%',
          style: TextStyle(
            fontSize: size * 0.22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BatteryRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final List<Color>? gradient;

  _BatteryRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (gradient != null && gradient!.length >= 2) {
      paint.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: gradient!,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      paint.color = color;
    }

    // Start from top (-90 degrees)
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// A compact battery indicator with icon and percentage
class BatteryIndicator extends StatelessWidget {
  final int level;
  final bool isCharging;
  final bool showPercentage;
  final double iconSize;

  const BatteryIndicator({
    super.key,
    required this.level,
    this.isCharging = false,
    this.showPercentage = true,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0, 100);
    final color = AppTheme.getBatteryColor(clampedLevel);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getBatteryIcon(clampedLevel, isCharging),
          color: color,
          size: iconSize,
        ),
        if (showPercentage) ...[
          const SizedBox(width: 4),
          Text(
            '$clampedLevel%',
            style: TextStyle(
              color: color,
              fontSize: iconSize * 0.7,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  IconData _getBatteryIcon(int level, bool charging) {
    if (charging) {
      return Icons.battery_charging_full_rounded;
    }
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 70) return Icons.battery_6_bar_rounded;
    if (level >= 50) return Icons.battery_5_bar_rounded;
    if (level >= 35) return Icons.battery_4_bar_rounded;
    if (level >= 20) return Icons.battery_3_bar_rounded;
    if (level >= 10) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }
}
