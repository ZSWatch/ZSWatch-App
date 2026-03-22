import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/connection.dart';
import '../../../data/models/thread_monitor_data.dart';
import '../../../providers/shell_providers.dart';
import '../../../providers/watch_service_provider.dart';

/// Shell screen with tabs: Terminal, Quick Actions, Remote Control, Live Monitor.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _smpEnabling = false;

  void _setSmpEnabling(bool value) {
    if (mounted) setState(() => _smpEnabling = value);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _enableSmp();
  }

  @override
  void deactivate() {
    // Cancel the timer immediately (no state change — safe during teardown).
    // Then defer the full state update to after the frame completes.
    final monitorNotifier = ref.read(liveMonitorProvider.notifier);
    final monitor = ref.read(liveMonitorProvider);
    if (monitor.isEnabled) {
      monitorNotifier.cancelPolling();
      Future(monitorNotifier.stop);
    }

    final watchService = ref.read(watchServiceProvider);
    unawaited(watchService.disableSmp());
    super.deactivate();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _enableSmp() async {
    if (_smpEnabling) return;
    _setSmpEnabling(true);
    try {
      final watchService = ref.read(watchServiceProvider);
      await watchService.enableSmp();
      await Future<void>.delayed(const Duration(seconds: 2));
      final hasSmp = await watchService.rediscoverServices();
      if (!hasSmp && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SMP service not found. If your watch firmware is older, '
              'you may need to manually enable it: '
              'on the watch go to Apps → Update → Enable FW Update.',
            ),
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ShellScreen] Failed to enable SMP: $e');
    } finally {
      _setSmpEnabling(false);
    }
  }

  void _onTabChanged() {
    // Stop live monitor when leaving the monitor tab (index 3)
    if (_tabController.index != 3) {
      final monitor = ref.read(liveMonitorProvider);
      if (monitor.isEnabled) {
        ref.read(liveMonitorProvider.notifier).stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(watchConnectionProvider);

    // Re-enable SMP whenever the watch reconnects while this screen is open.
    ref.listen<Connection>(watchConnectionProvider, (prev, next) {
      if (!next.isConnected) {
        final monitor = ref.read(liveMonitorProvider);
        if (monitor.isEnabled) {
          ref.read(liveMonitorProvider.notifier).stop();
        }
        return;
      }

      if (next.isConnected && prev != null && !prev.isConnected) {
        _enableSmp();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shell'),
        actions: [
          IconButton(
            icon: _smpEnabling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Re-enable SMP',
            onPressed: _smpEnabling ? null : _enableSmp,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.terminal, size: 18), text: 'Terminal'),
            Tab(icon: Icon(Icons.flash_on, size: 18), text: 'Quick Actions'),
            Tab(icon: Icon(Icons.gamepad, size: 18), text: 'Remote'),
            Tab(icon: Icon(Icons.monitor_heart, size: 18), text: 'Monitor'),
          ],
        ),
      ),
      body: !connection.isConnected
          ? const Center(child: Text('Watch not connected'))
          : TabBarView(
              controller: _tabController,
              children: const [
                _TerminalTab(),
                _QuickActionsTab(),
                _RemoteControlTab(),
                _LiveMonitorTab(),
              ],
            ),
    );
  }
}

// =============================================================================
// Terminal Tab
// =============================================================================

class _TerminalTab extends ConsumerStatefulWidget {
  const _TerminalTab();

  @override
  ConsumerState<_TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends ConsumerState<_TerminalTab> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final cmd = _commandController.text;
    if (cmd.trim().isEmpty) return;
    _commandController.clear();
    ref.read(shellTerminalProvider.notifier).execute(cmd);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(shellTerminalProvider);

    ref.listen(shellTerminalProvider, (prev, next) {
      if (prev != null && next.lines.length > prev.lines.length) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        // Terminal output
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: terminalState.lines.isEmpty
                ? Center(
                    child: Text(
                      'Type a command below\ne.g. "battery" or "app list"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppTheme.spacingSm),
                    itemCount: terminalState.lines.length,
                    itemBuilder: (context, index) {
                      final line = terminalState.lines[index];
                      return SelectableText(
                        line.text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: line.isError
                              ? AppTheme.errorColor
                              : line.isCommand
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimary,
                          fontWeight: line.isCommand
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Input bar
        Container(
          color: AppTheme.surfaceColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSm,
            vertical: AppTheme.spacingXs,
          ),
          child: Row(
            children: [
              const Text(
                '\$ ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _commandController,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter command...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                  enabled: !terminalState.isExecuting,
                ),
              ),
              if (terminalState.isExecuting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: _submit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => ref.read(shellTerminalProvider.notifier).clear(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Quick Actions Tab
// =============================================================================

class _QuickActionsTab extends ConsumerWidget {
  const _QuickActionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        const _SectionHeader(title: 'System Info'),
        _QuickActionCard(
          icon: Icons.battery_full,
          title: 'Battery Status',
          command: 'battery',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.power_settings_new,
          title: 'Power Status',
          command: 'power status',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.speed,
          title: 'CPU Frequency',
          command: 'cpu freq',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.apps,
          title: 'App State',
          command: 'app state',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.list,
          title: 'App List',
          command: 'app list',
          ref: ref,
        ),

        const SizedBox(height: AppTheme.spacingMd),
        const _SectionHeader(title: 'Hardware'),
        _QuickActionCard(
          icon: Icons.light_mode,
          title: 'Get Brightness',
          command: 'display get_brightness',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.vibration,
          title: 'Vibrate (Click)',
          command: 'vibration run_pattern click',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.notifications_active,
          title: 'Vibrate (Notification)',
          command: 'vibration run_pattern notification',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.mic,
          title: 'Mic Gain',
          command: 'mic gain_get',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.bluetooth,
          title: 'BLE FOTA Status',
          command: 'ble_fota status',
          ref: ref,
        ),

        const SizedBox(height: AppTheme.spacingMd),
        const _SectionHeader(title: 'Debug'),
        _QuickActionCard(
          icon: Icons.bug_report,
          title: 'Coredump Summary',
          command: 'coredump summary',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.record_voice_over,
          title: 'Voice Memo Status',
          command: 'voice_memo status',
          ref: ref,
        ),
        _QuickActionCard(
          icon: Icons.system_update,
          title: 'Enter Bootloader',
          command: 'boot start',
          ref: ref,
          isDestructive: true,
        ),
        _QuickActionCard(
          icon: Icons.restore,
          title: 'Factory Reset',
          command: 'factory_reset',
          ref: ref,
          isDestructive: true,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String command;
  final WidgetRef ref;
  final bool isDestructive;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.command,
    required this.ref,
    this.isDestructive = false,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  String? _result;
  bool _isLoading = false;
  bool _isError = false;

  Future<void> _execute() async {
    if (widget.isDestructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm'),
          content: Text('Execute "${widget.command}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Execute', style: TextStyle(color: AppTheme.errorColor)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _isError = false;
    });

    try {
      final shellService = widget.ref.read(shellServiceProvider);
      final result = await shellService.execute(widget.command);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _result = result.output;
          _isError = result.returnCode != 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _result = e.toString();
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingXs),
      child: InkWell(
        onTap: _isLoading ? null : _execute,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: widget.isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          widget.command,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.play_arrow, size: 20, color: AppTheme.textSecondary),
                ],
              ),
              if (_result != null) ...[
                const Divider(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: SelectableText(
                    _result!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: _isError ? AppTheme.errorColor : AppTheme.textPrimary,
                    ),
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

// =============================================================================
// Remote Control Tab
// =============================================================================

class _RemoteControlTab extends ConsumerStatefulWidget {
  const _RemoteControlTab();

  @override
  ConsumerState<_RemoteControlTab> createState() => _RemoteControlTabState();
}

class _RemoteControlTabState extends ConsumerState<_RemoteControlTab> {
  List<String>? _appList;
  bool _isLoadingApps = false;
  String? _status;
  bool _touchpadScrollLocked = false;

  // Button key codes: KEY_1=2, KEY_2=3, KEY_3=4, KEY_4=5 (EV_KEY=1)
  static const _buttonCodes = {'1': 2, '2': 3, '3': 4, '4': 5};

  Future<void> _sendButton(String buttonId, String label) async {
    setState(() => _status = 'Sending $label...');
    try {
      final shellService = ref.read(shellServiceProvider);
      final code = _buttonCodes[buttonId]!;
      await shellService.execute('input report 1 $code 1 true');
      await shellService.execute('input report 1 $code 0 true');
      if (mounted) setState(() => _status = '$label sent');
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _sendTouchDown(int x, int y) async {
    setState(() => _status = 'Down ($x, $y)');
    try {
      await ref.read(shellServiceProvider).execute('touchdown $x $y');
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _sendTouchMove(int x, int y) async {
    setState(() => _status = 'Move ($x, $y)');
    try {
      await ref.read(shellServiceProvider).execute('touchmove $x $y');
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _sendTouchUp() async {
    setState(() => _status = 'Touch up');
    try {
      await ref.read(shellServiceProvider).execute('touchup');
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _loadApps() async {
    setState(() => _isLoadingApps = true);
    try {
      final shellService = ref.read(shellServiceProvider);
      final result = await shellService.execute('app list');
      if (mounted) {
        // Parse app names from firmware output.
        // Format: "  [0] AppName (stopped)" or "  [1] My App (visible) [hidden]"
        final nameRegex = RegExp(r'\[\d+\]\s+(.+?)\s+\((?:stopped|visible|hidden|unknown)\)');
        final names = <String>[];
        for (final line in result.output.split('\n')) {
          final match = nameRegex.firstMatch(line);
          if (match != null) {
            names.add(match.group(1)!);
          }
        }
        setState(() {
          _appList = names;
          _isLoadingApps = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingApps = false;
          _status = 'Error loading apps: $e';
        });
      }
    }
  }

  Future<void> _launchApp(String app) async {
    setState(() => _status = 'Launching $app...');
    try {
      final shellService = ref.read(shellServiceProvider);
      await shellService.execute('app close');
      await shellService.execute('app launch $app');
      if (mounted) setState(() => _status = '$app launched');
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: _touchpadScrollLocked ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      children: [
        // Touchpad in center, hardware buttons at 45° corners (like the watch)
        const _SectionHeader(title: 'Input'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Center(
              child: SizedBox(
                width: 240 + 52 + 8, // touchpad + button + gap
                height: 240 + 52 + 8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _WatchTouchpad(
                      onDown: _sendTouchDown,
                      onMove: _sendTouchMove,
                      onUp: _sendTouchUp,
                      onScrollLock: (locked) =>
                          setState(() => _touchpadScrollLocked = locked),
                    ),
                    // Top-Left: Next
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _RemoteButton(
                        label: 'Next',
                        icon: Icons.skip_next,
                        onPressed: () => _sendButton('4', 'Next (Top-Left)'),
                      ),
                    ),
                    // Bottom-Left: Prev
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: _RemoteButton(
                        label: 'Prev',
                        icon: Icons.skip_previous,
                        onPressed: () => _sendButton('2', 'Prev (Bot-Left)'),
                      ),
                    ),
                    // Top-Right: Select
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _RemoteButton(
                        label: 'Select',
                        icon: Icons.check_circle_outline,
                        onPressed: () => _sendButton('1', 'Select (Top-Right)'),
                      ),
                    ),
                    // Bottom-Right: Back
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _RemoteButton(
                        label: 'Back',
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => _sendButton('3', 'Back (Bot-Right)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (_status != null) ...[
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            _status!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontFamily: 'monospace',
                ),
          ),
        ],

        const SizedBox(height: AppTheme.spacingLg),
        // App launcher
        const _SectionHeader(title: 'App Launcher'),
        Row(
          children: [
            if (_appList == null)
              Expanded(
                child: Center(
                  child: _isLoadingApps
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _loadApps,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Load App List'),
                        ),
                ),
              )
            else ...[              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadApps,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ),
            ],
          ],
        ),
        if (_appList != null) ...[          const SizedBox(height: AppTheme.spacingSm),
          ...(_appList!.map((app) => Card(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingXs),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.apps, size: 20, color: AppTheme.primaryColor),
                  title: Text(app),
                  trailing: IconButton(
                    icon: const Icon(Icons.launch, size: 18),
                    onPressed: () => _launchApp(app),
                  ),
                ),
              ))),
        ],
      ],
    );
  }
}

class _RemoteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _RemoteButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: AppTheme.elevatedSurfaceColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppTheme.textSecondary),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Watch Touchpad Widget
// =============================================================================

class _WatchTouchpad extends StatefulWidget {
  final Future<void> Function(int x, int y) onDown;
  final Future<void> Function(int x, int y) onMove;
  final Future<void> Function() onUp;
  final ValueChanged<bool>? onScrollLock;

  const _WatchTouchpad({
    required this.onDown,
    required this.onMove,
    required this.onUp,
    this.onScrollLock,
  });

  @override
  State<_WatchTouchpad> createState() => _WatchTouchpadState();
}

class _WatchTouchpadState extends State<_WatchTouchpad> {
  static const double _displaySize = 240.0;
  static const int _watchSize = 240;
  static const int _moveIntervalMs = 50;

  Offset? _pointerPos;
  DateTime _lastMoveSent = DateTime.fromMillisecondsSinceEpoch(0);

  (int, int) _localToWatch(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(global);
    const center = Offset(_displaySize / 2, _displaySize / 2);
    const radius = _displaySize / 2;
    final fromCenter = local - center;
    final clamped = fromCenter.distance > radius
        ? center + fromCenter / fromCenter.distance * radius
        : local;
    setState(() => _pointerPos = clamped);
    final x = (clamped.dx / _displaySize * _watchSize).round().clamp(0, _watchSize - 1);
    final y = (clamped.dy / _displaySize * _watchSize).round().clamp(0, _watchSize - 1);
    return (x, y);
  }

  bool _tracking = false;

  void _handlePointerDown(PointerDownEvent event) {
    _tracking = true;
    widget.onScrollLock?.call(true);
    final (x, y) = _localToWatch(event.position);
    widget.onDown(x, y);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_tracking) return;
    final now = DateTime.now();
    if (now.difference(_lastMoveSent).inMilliseconds >= _moveIntervalMs) {
      _lastMoveSent = now;
      final (x, y) = _localToWatch(event.position);
      widget.onMove(x, y);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_tracking) return;
    _tracking = false;
    widget.onScrollLock?.call(false);
    widget.onUp();
    if (mounted) setState(() => _pointerPos = null);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_tracking) return;
    _tracking = false;
    widget.onScrollLock?.call(false);
    widget.onUp();
    if (mounted) setState(() => _pointerPos = null);
  }

  @override
  Widget build(BuildContext context) {
    // Listener gets raw pointer events immediately (no gesture arena delay).
    // RawGestureDetector with _EagerGestureRecognizer immediately wins the
    // gesture arena, preventing parent ListView/TabBarView from scrolling.
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_EagerGestureRecognizer>(
            _EagerGestureRecognizer.new,
            (_) {},
          ),
        },
        child: SizedBox(
          width: _displaySize,
          height: _displaySize,
          child: CustomPaint(
            painter: _TouchpadPainter(pointerPos: _pointerPos),
          ),
        ),
      ),
    );
  }
}

/// Gesture recognizer that immediately claims victory in the arena on pointer
/// down, preventing any parent scrollable (ListView, TabBarView) from
/// intercepting the touch.
class _EagerGestureRecognizer extends OneSequenceGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {}

  @override
  String get debugDescription => 'eager';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}

class _TouchpadPainter extends CustomPainter {
  final Offset? pointerPos;

  const _TouchpadPainter({this.pointerPos});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white10,
    );

    // Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Crosshair lines
    final linePaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx, center.dy - radius * 0.8),
        Offset(center.dx, center.dy + radius * 0.8), linePaint);
    canvas.drawLine(Offset(center.dx - radius * 0.8, center.dy),
        Offset(center.dx + radius * 0.8, center.dy), linePaint);

    // Touch indicator dot
    if (pointerPos != null) {
      canvas.drawCircle(
        pointerPos!,
        8,
        Paint()..color = Colors.blueAccent.withValues(alpha: 0.8),
      );
      canvas.drawCircle(
        pointerPos!,
        8,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_TouchpadPainter old) => old.pointerPos != pointerPos;
}

// =============================================================================
// Live Monitor Tab
// =============================================================================

class _LiveMonitorTab extends ConsumerWidget {
  const _LiveMonitorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(liveMonitorProvider);

    return Column(
      children: [
        // Toggle bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMd,
            vertical: AppTheme.spacingSm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Icon(
                monitor.isEnabled ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: monitor.isEnabled ? AppTheme.successColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monitor.isEnabled ? 'Monitoring active' : 'Monitoring paused',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (monitor.lastUpdate != null)
                      Text(
                        'Last update: ${_formatTime(monitor.lastUpdate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                      ),
                  ],
                ),
              ),
              if (monitor.threadHistories.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.restart_alt, size: 20),
                  tooltip: 'Reset history',
                  onPressed: () => ref.read(liveMonitorProvider.notifier).resetHistory(),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              Switch(
                value: monitor.isEnabled,
                onChanged: (_) => ref.read(liveMonitorProvider.notifier).toggle(),
                activeThumbColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),

        if (monitor.error != null)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            child: Text(
              monitor.error!,
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
            ),
          ),

        // Data display
        Expanded(
          child: !monitor.isEnabled && monitor.lastUpdate == null
              ? const Center(
                  child: Text(
                    'Enable monitoring to see live status\ndata from the watch',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : monitor.isEnabled && monitor.lastUpdate == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spacingSm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // System info row
                          _SystemInfoCard(monitor: monitor),
                          const SizedBox(height: AppTheme.spacingSm),
                          // Threads (stack bars + state + priority + cycles/s)
                          if (monitor.threadHistories.isNotEmpty) ...[
                            _ThreadsCard(histories: monitor.threadHistories),
                            const SizedBox(height: AppTheme.spacingSm),
                          ],
                          // Cycles/s chart
                          if (monitor.pollCount > 1 && monitor.threadHistories.isNotEmpty)
                            _CyclesChartCard(histories: monitor.threadHistories, pollCount: monitor.pollCount),
                          if (monitor.threadHistories.isEmpty && monitor.isEnabled)
                            const Padding(
                              padding: EdgeInsets.all(AppTheme.spacingMd),
                              child: Text(
                                'Thread data not available — check firmware thread monitor support',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// System Info Card (CPU + Power as labels)
// =============================================================================

class _SystemInfoCard extends StatelessWidget {
  final LiveMonitorState monitor;
  const _SystemInfoCard({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final power = monitor.powerInfo;
    final cpuFreq = monitor.cpuFreq;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingSm),
                Text('System', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.speed,
                    label: 'CPU',
                    value: cpuFreq ?? '—',
                    color: cpuFreq == 'fast' ? AppTheme.warningColor : AppTheme.successColor,
                  ),
                ),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.power_settings_new,
                    label: 'Power',
                    value: power?.state ?? '—',
                    color: power?.state == 'Active' ? AppTheme.successColor : AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.timer_outlined,
                    label: 'Sleep in',
                    value: power != null ? '${power.timeToSleepSec}s' : '—',
                    color: AppTheme.textSecondary,
                  ),
                ),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.schedule,
                    label: 'Uptime',
                    value: power != null ? _formatUptime(power.uptimeSec) : '—',
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (monitor.schedulerCycles != null) ...[
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                'Scheduler: ${monitor.schedulerCycles} cycles since last call',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 11,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 9,
              ),
        ),
      ],
    );
  }
}

// =============================================================================
// Stack Usage Card (horizontal bars with max marker)
// =============================================================================

class _ThreadsCard extends StatelessWidget {
  final Map<String, ThreadHistory> histories;
  const _ThreadsCard({required this.histories});

  @override
  Widget build(BuildContext context) {
    final sorted = histories.values.toList()
      ..sort((a, b) {
        // Active threads first, removed threads at the bottom.
        if (a.removed != b.removed) return a.removed ? 1 : -1;
        return b.currentUsagePercent.compareTo(a.currentUsagePercent);
      });

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.memory, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingSm),
                Text('Threads (${sorted.length})', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('max', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            ...sorted.map((t) => _ThreadEntry(thread: t)),
          ],
        ),
      ),
    );
  }
}

class _ThreadEntry extends StatelessWidget {
  final ThreadHistory thread;
  const _ThreadEntry({required this.thread});

  @override
  Widget build(BuildContext context) {
    final isRemoved = thread.removed;
    final dimAlpha = isRemoved ? 0.4 : 1.0;
    final currentFrac = thread.stackSize > 0 ? thread.currentStackUsed / thread.stackSize : 0.0;
    final maxFrac = thread.stackSize > 0 ? thread.maxStackUsed / thread.stackSize : 0.0;
    final maxPct = thread.stackSize > 0
        ? ((thread.maxStackUsed / thread.stackSize) * 100).round()
        : 0;

    Color barColor;
    if (isRemoved) {
      barColor = AppTheme.textSecondary;
    } else if (currentFrac > 0.85) {
      barColor = AppTheme.errorColor;
    } else if (currentFrac > 0.65) {
      barColor = AppTheme.warningColor;
    } else {
      barColor = AppTheme.primaryColor;
    }

    final lastCps = thread.cyclesPerSecHistory.isNotEmpty
        ? thread.cyclesPerSecHistory.last
        : 0.0;
    final cpsText = lastCps > 1e6
        ? '${(lastCps / 1e6).toStringAsFixed(1)}M/s'
        : lastCps > 1e3
            ? '${(lastCps / 1e3).toStringAsFixed(1)}K/s'
            : '${lastCps.toStringAsFixed(0)}/s';

    return Opacity(
      opacity: dimAlpha,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: name, state, priority, cycles/s
          Row(
            children: [
              Expanded(
                child: Text(
                  thread.name,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  thread.state,
                  style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'P${thread.priority}',
                style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                cpsText,
                style: TextStyle(fontSize: 9, color: AppTheme.primaryColor.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Row 2: stack bar with labels
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 10,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Container(
                            width: maxWidth * currentFrac.clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              color: barColor.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          if (maxFrac > currentFrac)
                            Positioned(
                              left: (maxWidth * maxFrac.clamp(0.0, 1.0)) - 1,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: AppTheme.warningColor.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${thread.currentStackUsed}/${thread.stackSize}',
                style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontFamily: 'monospace'),
              ),
              if (maxPct > thread.currentUsagePercent) ...[                const SizedBox(width: 4),
                Text(
                  '(max $maxPct%)',
                  style: TextStyle(fontSize: 8, color: AppTheme.warningColor.withValues(alpha: 0.8)),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
    );
  }
}

// =============================================================================
// Cycles/s Line Chart
// =============================================================================

class _CyclesChartCard extends StatelessWidget {
  final Map<String, ThreadHistory> histories;
  final int pollCount;
  const _CyclesChartCard({required this.histories, required this.pollCount});

  static const int _windowSize = 30;

  static const _chartColors = [
    AppTheme.primaryColor,
    AppTheme.warningColor,
    AppTheme.errorColor,
    AppTheme.successColor,
    AppTheme.infoColor,
    Color(0xFFE040FB), // purple
    Color(0xFFFF6E40), // deep orange
    Color(0xFF64FFDA), // teal accent
  ];

  @override
  Widget build(BuildContext context) {
    // Only show threads that have had non-zero cycles and are not removed.
    final active = histories.entries.where((e) {
      return !e.value.removed && e.value.cyclesPerSecHistory.any((v) => v > 0);
    }).toList()
      ..sort((a, b) {
        final aMax = a.value.cyclesPerSecHistory.isEmpty
            ? 0.0
            : a.value.cyclesPerSecHistory.reduce((a, b) => a > b ? a : b);
        final bMax = b.value.cyclesPerSecHistory.isEmpty
            ? 0.0
            : b.value.cyclesPerSecHistory.reduce((a, b) => a > b ? a : b);
        return bMax.compareTo(aMax);
      });

    if (active.isEmpty) return const SizedBox.shrink();

    // Limit to top 8 most active threads for readability
    final shown = active.take(8).toList();

    // Rolling window: only show the last _windowSize samples
    final xMax = (pollCount - 1).toDouble();
    final xMin = (pollCount - _windowSize).toDouble();

    final lines = <LineChartBarData>[];
    for (int idx = 0; idx < shown.length; idx++) {
      final th = shown[idx].value;
      final history = th.cyclesPerSecHistory;
      final offset = pollCount - history.length;
      final spots = <FlSpot>[];
      for (int i = 0; i < history.length; i++) {
        final x = (offset + i).toDouble();
        if (x < xMin) continue;
        spots.add(FlSpot(x, history[i]));
      }
      if (spots.isEmpty) continue;
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: _chartColors[idx % _chartColors.length],
        barWidth: 1.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingSm),
                Text('Cycles/s', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (int idx = 0; idx < shown.length; idx++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 3,
                        color: _chartColors[idx % _chartColors.length],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        shown[idx].key,
                        style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            SizedBox(
              height: 150,
              child: LineChart(
                duration: Duration.zero,
                LineChartData(
                  minX: xMin,
                  maxX: xMax,
                  lineBarsData: lines,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: null,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          String text;
                          if (value >= 1000000) {
                            text = '${(value / 1000000).toStringAsFixed(1)}M';
                          } else if (value >= 1000) {
                            text = '${(value / 1000).toStringAsFixed(1)}k';
                          } else {
                            text = value.toInt().toString();
                          }
                          return Text(text, style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary));
                        },
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.elevatedSurfaceColor,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final name = shown[spot.barIndex].key;
                          return LineTooltipItem(
                            '$name: ${spot.y.toStringAsFixed(0)}',
                            TextStyle(
                              fontSize: 10,
                              color: _chartColors[spot.barIndex % _chartColors.length],
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


