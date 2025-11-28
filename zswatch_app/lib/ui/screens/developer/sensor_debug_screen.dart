import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/sensor_reading.dart';
import '../../../providers/watch_service_provider.dart';
import '../../../services/ble/sensor_gatt_service.dart';

/// Sensor debug screen with real-time visualization
///
/// Features:
/// - Real-time charts for accelerometer, gyroscope, magnetometer, etc.
/// - Toggle switches to enable/disable each sensor's GATT notifications
/// - Current values display
/// - Basic statistics
class SensorDebugScreen extends ConsumerStatefulWidget {
  const SensorDebugScreen({super.key});

  @override
  ConsumerState<SensorDebugScreen> createState() => _SensorDebugScreenState();
}

class _SensorDebugScreenState extends ConsumerState<SensorDebugScreen> {
  final Map<SensorType, List<SensorReading>> _sensorHistory = {};
  final int _maxHistoryLength = 100;
  
  SensorGattService? _sensorService;
  final Map<SensorType, bool> _enabledSensors = {};
  final Map<SensorType, StreamSubscription<SensorReading>?> _subscriptions = {};

  @override
  void initState() {
    super.initState();
    // Initialize history and enabled state for each sensor type
    for (final type in SensorType.values) {
      _sensorHistory[type] = [];
      _enabledSensors[type] = false;
    }
    
    // Initialize sensor service after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSensorService();
    });
  }
  
  Future<void> _initializeSensorService() async {
    final watchService = ref.read(watchServiceProvider);
    final device = watchService.device;
    if (device == null) return;
    
    final services = watchService.services;
    if (services == null || services.isEmpty) return;
    
    _sensorService = SensorGattService(device);
    final success = await _sensorService!.initialize(services);
    
    if (success && mounted) {
      setState(() {});
      debugPrint('[SensorDebug] Sensor service initialized');
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions and stop sensors
    for (final sub in _subscriptions.values) {
      sub?.cancel();
    }
    _sensorService?.stopAll();
    super.dispose();
  }

  Future<void> _toggleSensor(SensorType type, bool enable) async {
    if (_sensorService == null) return;
    
    setState(() {
      _enabledSensors[type] = enable;
    });
    
    try {
      if (enable) {
        // Start the sensor and subscribe to its stream
        switch (type) {
          case SensorType.temperature:
            await _sensorService!.startTemperature();
            _subscriptions[type] = _sensorService!.temperatureStream.listen(_addReading);
          case SensorType.accelerometer:
            await _sensorService!.startAccelerometer();
            _subscriptions[type] = _sensorService!.accelerometerStream.listen(_addReading);
          case SensorType.gyroscope:
            await _sensorService!.startGyroscope();
            _subscriptions[type] = _sensorService!.gyroscopeStream.listen(_addReading);
          case SensorType.magnetometer:
            await _sensorService!.startMagnetometer();
            _subscriptions[type] = _sensorService!.magnetometerStream.listen(_addReading);
          case SensorType.light:
            await _sensorService!.startLight();
            _subscriptions[type] = _sensorService!.lightStream.listen(_addReading);
          case SensorType.humidity:
            await _sensorService!.startHumidity();
            _subscriptions[type] = _sensorService!.humidityStream.listen(_addReading);
          case SensorType.pressure:
            await _sensorService!.startPressure();
            _subscriptions[type] = _sensorService!.pressureStream.listen(_addReading);
        }
      } else {
        // Cancel subscription and stop sensor
        await _subscriptions[type]?.cancel();
        _subscriptions[type] = null;
        
        switch (type) {
          case SensorType.temperature:
            await _sensorService!.stopTemperature();
          case SensorType.accelerometer:
            await _sensorService!.stopAccelerometer();
          case SensorType.gyroscope:
            await _sensorService!.stopGyroscope();
          case SensorType.magnetometer:
            await _sensorService!.stopMagnetometer();
          case SensorType.light:
            await _sensorService!.stopLight();
          case SensorType.humidity:
            await _sensorService!.stopHumidity();
          case SensorType.pressure:
            await _sensorService!.stopPressure();
        }
      }
    } catch (e) {
      debugPrint('[SensorDebug] Error toggling $type: $e');
      // Reset state on error
      if (mounted) {
        setState(() {
          _enabledSensors[type] = !enable;
        });
      }
    }
  }

  void _addReading(SensorReading reading) {
    if (!mounted) return;
    setState(() {
      final history = _sensorHistory[reading.type]!;
      history.add(reading);
      if (history.length > _maxHistoryLength) {
        history.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(watchConnectionProvider);
    final isConnected = connection.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear history',
            onPressed: () {
              setState(() {
                for (final history in _sensorHistory.values) {
                  history.clear();
                }
              });
            },
          ),
        ],
      ),
      body: !isConnected
          ? _buildUnavailableState()
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: [
                // Status bar
                _buildStatusBar(),
                const SizedBox(height: AppTheme.spacingMd),

                // Info text
                _buildInfoText(),
                const SizedBox(height: AppTheme.spacingMd),

                // Sensor cards - based on firmware supported sensors
                _SensorCard(
                  type: SensorType.accelerometer,
                  displayName: 'Accelerometer',
                  icon: Icons.vibration,
                  history: _sensorHistory[SensorType.accelerometer]!,
                  unit: 'm/s²',
                  hasXYZ: true,
                  enabled: _enabledSensors[SensorType.accelerometer]!,
                  available: _sensorService?.hasAccelerometer ?? false,
                  onToggle: (enable) => _toggleSensor(SensorType.accelerometer, enable),
                ),

                _SensorCard(
                  type: SensorType.gyroscope,
                  displayName: 'Gyroscope',
                  icon: Icons.rotate_right,
                  history: _sensorHistory[SensorType.gyroscope]!,
                  unit: '°/s',
                  hasXYZ: true,
                  enabled: _enabledSensors[SensorType.gyroscope]!,
                  available: _sensorService?.hasGyroscope ?? false,
                  onToggle: (enable) => _toggleSensor(SensorType.gyroscope, enable),
                ),

                _SensorCard(
                  type: SensorType.magnetometer,
                  displayName: 'Magnetometer',
                  icon: Icons.explore,
                  history: _sensorHistory[SensorType.magnetometer]!,
                  unit: 'μT',
                  hasXYZ: true,
                  enabled: _enabledSensors[SensorType.magnetometer]!,
                  available: _sensorService?.hasMagnetometer ?? false,
                  onToggle: (enable) => _toggleSensor(SensorType.magnetometer, enable),
                ),

                _SensorCard(
                  type: SensorType.temperature,
                  displayName: 'Temperature',
                  icon: Icons.thermostat,
                  history: _sensorHistory[SensorType.temperature]!,
                  unit: '°C',
                  hasXYZ: false,
                  enabled: _enabledSensors[SensorType.temperature]!,
                  available: _sensorService?.hasTemperature ?? false,
                  onToggle: (enable) => _toggleSensor(SensorType.temperature, enable),
                ),

                _SensorCard(
                  type: SensorType.humidity,
                  displayName: 'Humidity',
                  icon: Icons.water_drop,
                  history: _sensorHistory[SensorType.humidity]!,
                  unit: '%',
                  hasXYZ: false,
                  enabled: _enabledSensors[SensorType.humidity]!,
                  available: _sensorService?.hasHumidity ?? false,
                  onToggle: (enable) => _toggleSensor(SensorType.humidity, enable),
                ),

                _SensorCard(
                  type: SensorType.pressure,
                  displayName: 'Pressure',
                  icon: Icons.speed,
                  history: _sensorHistory[SensorType.pressure]!,
                  unit: 'hPa',
                  hasXYZ: false,
                  enabled: _enabledSensors[SensorType.pressure]!,
                  available: _sensorService?.hasPressure ?? false,
                  onToggle: (enable) => _toggleSensor(SensorType.pressure, enable),
                ),

                _SensorCard(
                  type: SensorType.light,
                  displayName: 'Ambient Light',
                  icon: Icons.light_mode,
                  history: _sensorHistory[SensorType.light]!,
                  unit: 'lux',
                  hasXYZ: false,
                  enabled: _enabledSensors[SensorType.light]!,
                  available: _sensorService?.hasLight ?? false,
                  onToggle: (enable) => _toggleSensor(SensorType.light, enable),
                ),
              ],
            ),
    );
  }

  Widget _buildUnavailableState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sensors_off,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Sensor service not available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to a watch to access sensors',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.infoColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.infoColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Toggle sensors to enable GATT notifications. The watch will stream data when enabled.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final activeSensors = _enabledSensors.values.where((e) => e).length;
    final totalSamples = _sensorHistory.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sensors,
            color: activeSensors > 0 ? AppTheme.successColor : AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$activeSensors sensor${activeSensors == 1 ? '' : 's'} streaming',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '$totalSamples total samples received',
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

class _SensorCard extends StatelessWidget {
  final SensorType type;
  final String displayName;
  final IconData icon;
  final List<SensorReading> history;
  final String unit;
  final bool hasXYZ;
  final bool enabled;
  final bool available;
  final ValueChanged<bool> onToggle;

  const _SensorCard({
    required this.type,
    required this.displayName,
    required this.icon,
    required this.history,
    required this.unit,
    required this.hasXYZ,
    required this.enabled,
    required this.available,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final lastReading = history.isNotEmpty ? history.last : null;
    final hasData = history.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with toggle
            Row(
              children: [
                Icon(
                  icon,
                  color: enabled ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (!available)
                        Text(
                          'Not available on this device',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.warningColor,
                              ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: available ? onToggle : null,
                ),
              ],
            ),

            if (enabled && lastReading != null) ...[
              const SizedBox(height: AppTheme.spacingMd),

              // Current values
              if (hasXYZ) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ValueChip(
                      label: 'X',
                      value: lastReading.x,
                      unit: unit,
                      color: Colors.red,
                    ),
                    _ValueChip(
                      label: 'Y',
                      value: lastReading.y ?? 0,
                      unit: unit,
                      color: Colors.green,
                    ),
                    _ValueChip(
                      label: 'Z',
                      value: lastReading.z ?? 0,
                      unit: unit,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ] else ...[
                Center(
                  child: _ValueChip(
                    label: '',
                    value: lastReading.x,
                    unit: unit,
                    color: AppTheme.primaryColor,
                    large: true,
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacingMd),

              // Mini chart
              SizedBox(
                height: 60,
                child: _MiniChart(
                  history: history,
                  hasXYZ: hasXYZ,
                ),
              ),

              // Stats
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${history.length} samples',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  if (history.isNotEmpty)
                    Text(
                      'Rate: ${_calculateRate(history).toStringAsFixed(1)} Hz',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                ],
              ),
            ],

            if (enabled && lastReading == null) ...[
              const SizedBox(height: AppTheme.spacingMd),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for data...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateRate(List<SensorReading> history) {
    if (history.length < 2) return 0;
    final duration = history.last.timestamp.difference(history.first.timestamp);
    if (duration.inMilliseconds == 0) return 0;
    return (history.length - 1) / (duration.inMilliseconds / 1000);
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final bool large;

  const _ValueChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
          Text(
            value.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: large ? 18 : 14,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            unit,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<SensorReading> history;
  final bool hasXYZ;

  const _MiniChart({
    required this.history,
    required this.hasXYZ,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _ChartPainter(
        history: history,
        hasXYZ: hasXYZ,
      ),
      size: const Size(double.infinity, 60),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<SensorReading> history;
  final bool hasXYZ;

  _ChartPainter({required this.history, required this.hasXYZ});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final paintX = Paint()
      ..color = Colors.red.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintY = Paint()
      ..color = Colors.green.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintZ = Paint()
      ..color = Colors.blue.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintValue = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Calculate min/max for scaling
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (final reading in history) {
      if (hasXYZ) {
        minVal = math.min(minVal, reading.x);
        minVal = math.min(minVal, reading.y ?? 0);
        minVal = math.min(minVal, reading.z ?? 0);
        maxVal = math.max(maxVal, reading.x);
        maxVal = math.max(maxVal, reading.y ?? 0);
        maxVal = math.max(maxVal, reading.z ?? 0);
      } else {
        minVal = math.min(minVal, reading.x);
        maxVal = math.max(maxVal, reading.x);
      }
    }

    // Add padding
    final range = maxVal - minVal;
    if (range == 0) {
      minVal -= 1;
      maxVal += 1;
    } else {
      minVal -= range * 0.1;
      maxVal += range * 0.1;
    }

    // Draw center line
    final centerPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );

    // Draw data
    final pathX = Path();
    final pathY = Path();
    final pathZ = Path();
    final pathValue = Path();

    for (int i = 0; i < history.length; i++) {
      final x = (i / (history.length - 1)) * size.width;
      final reading = history[i];

      if (hasXYZ) {
        final yX = size.height - (reading.x - minVal) / (maxVal - minVal) * size.height;
        final yY = size.height - ((reading.y ?? 0) - minVal) / (maxVal - minVal) * size.height;
        final yZ = size.height - ((reading.z ?? 0) - minVal) / (maxVal - minVal) * size.height;

        if (i == 0) {
          pathX.moveTo(x, yX);
          pathY.moveTo(x, yY);
          pathZ.moveTo(x, yZ);
        } else {
          pathX.lineTo(x, yX);
          pathY.lineTo(x, yY);
          pathZ.lineTo(x, yZ);
        }
      } else {
        final yVal = size.height - (reading.x - minVal) / (maxVal - minVal) * size.height;
        if (i == 0) {
          pathValue.moveTo(x, yVal);
        } else {
          pathValue.lineTo(x, yVal);
        }
      }
    }

    if (hasXYZ) {
      canvas.drawPath(pathX, paintX);
      canvas.drawPath(pathY, paintY);
      canvas.drawPath(pathZ, paintZ);
    } else {
      canvas.drawPath(pathValue, paintValue);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.history.length != history.length ||
        (history.isNotEmpty && oldDelegate.history.isNotEmpty &&
         oldDelegate.history.last != history.last);
  }
}
