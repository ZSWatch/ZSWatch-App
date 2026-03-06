import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/demo_mode_provider.dart';
import '../../../providers/permission_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/voice_memo_providers.dart';
import '../../../services/voice_memo/transcription_engine.dart';
import '../onboarding/permission_onboarding_screen.dart';

/// Settings screen for app configuration
///
/// Displays:
/// - DFU settings (keep screen on)
/// - About section (app version, links)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // TODO: Update these URLs to point to the correct repositories
  static const String _appGithubUrl = 'https://github.com/ZSWatch/ZSWatch-App';  // <-- Change to app repo
  static const String _firmwareGithubUrl = 'https://github.com/ZSWatch/ZSWatch';  // <-- Change to firmware repo
  static const String _appVersion = '1.0.0';
  static const String _buildNumber = '1';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Connection Settings
          _SectionHeader(title: 'Connection'),
          _SettingsTile(
            leading: Icon(
              ref.watch(backgroundConnectionEnabledProvider)
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: ref.watch(backgroundConnectionEnabledProvider)
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
            title: 'Persistent Connection',
            subtitle: 'Keep watch connected when app is in background',
            trailing: Switch(
              value: ref.watch(backgroundConnectionEnabledProvider),
              onChanged: (value) async {
                if (value && Platform.isAndroid) {
                  // Check notification permission before enabling
                  final permState = ref.read(permissionNotifierProvider);
                  if (!permState.status.isNotificationGranted) {
                    // Request notification permission
                    final result = await ref
                        .read(permissionNotifierProvider.notifier)
                        .requestNotificationPermission();
                    if (!result.isGranted && context.mounted) {
                      // Show warning that feature won't work properly
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification permission is required for the persistent connection indicator'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                }
                ref.read(backgroundConnectionEnabledProvider.notifier).setEnabled(value);
                // If disabling while connected, the service will keep running
                // until the watch is disconnected
                if (!value) {
                  _showPersistentConnectionDisabledDialog(context);
                }
              },
            ),
          ),

          const Divider(height: 32),

          // Permissions Section (consolidated)
          _SectionHeader(title: 'Permissions'),
          _PermissionsSummaryTile(),

          const Divider(height: 32),

          // Firmware Update Settings
          _SectionHeader(title: 'Firmware Update'),
          _SettingsTile(
            leading: const Icon(Icons.screen_lock_portrait, color: AppTheme.textSecondary),
            title: 'Keep Screen On During DFU',
            subtitle: 'Prevent screen timeout during firmware updates',
            trailing: Switch(
              value: ref.watch(keepScreenOnDuringDfuProvider),
              onChanged: (value) {
                ref.read(keepScreenOnDuringDfuProvider.notifier).setEnabled(value);
              },
            ),
          ),

          const Divider(height: 32),

          // Voice Memos / Transcription Settings
          _SectionHeader(title: 'Voice Memos'),
          _TranscriptionModelsSection(),

          const Divider(height: 32),

          // About Section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            leading: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
            title: 'App Version',
            subtitle: '$_appVersion ($_buildNumber)',
            onTap: () => _showVersionDialog(context),
          ),
          _SettingsTile(
            leading: const Icon(Icons.phone_android, color: AppTheme.textSecondary),
            title: 'Companion App Source',
            subtitle: 'View app source code on GitHub',
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => _launchUrl(_appGithubUrl),
          ),
          _SettingsTile(
            leading: SvgPicture.asset(
              'assets/images/ZSWatch_Logo.svg',
              width: 24,
              height: 24,
            ),
            title: 'ZSWatch Firmware',
            subtitle: 'Open-source smartwatch firmware',
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => _launchUrl(_firmwareGithubUrl),
          ),
          _SettingsTile(
            leading: const Icon(Icons.description_outlined, color: AppTheme.textSecondary),
            title: 'Licenses',
            subtitle: 'Open source licenses',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLicensesPage(context),
          ),

          const Divider(height: 32),

          // Demo Mode (for app store reviewers without hardware)
          _SectionHeader(title: 'Developer'),
          _SettingsTile(
            leading: Icon(
              Icons.science,
              color: ref.watch(demoModeProvider)
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
            title: 'Demo Mode',
            subtitle: 'Simulate a connected watch without hardware',
            trailing: Switch(
              value: ref.watch(demoModeProvider),
              onChanged: (value) {
                ref.read(demoModeProvider.notifier).state = value;
                if (value) {
                  context.go('/');
                }
              },
            ),
          ),

          const SizedBox(height: 32),

          // App description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/images/ZSWatch_Logo.svg',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'ZSWatch Companion',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Companion app for the open-source ZSWatch smartwatch',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showVersionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Version', value: _appVersion),
            _InfoRow(label: 'Build', value: _buildNumber),
            const _InfoRow(label: 'Platform', value: 'Flutter'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLicensesPage(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'ZSWatch Companion',
      applicationVersion: '$_appVersion ($_buildNumber)',
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SvgPicture.asset(
          'assets/images/ZSWatch_Logo.svg',
          width: 48,
          height: 48,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showPersistentConnectionDisabledDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Persistent Connection Disabled'),
        content: const Text(
          'The background connection service will stop when you disconnect from '
          'your watch. Notifications will not be forwarded while the app is in '
          'the background.\n\n'
          'Your current connection will remain active until you disconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingSm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TranscriptionModelsSection extends ConsumerWidget {
  const _TranscriptionModelsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(transcriptionEngineTypeProvider);
    final actionsState = ref.watch(voiceMemoActionsProvider);
    final isBusy = actionsState.isLoading;

    return Column(
      children: [
        for (final info in TranscriptionModelCatalog.all)
          _TranscriptionModelTile(
            info: info,
            isSelected: selectedType == info.type,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingSm,
            AppTheme.spacingMd,
            0,
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(isBusy
                  ? 'Re-transcribing...'
                  : 'Re-transcribe all with selected model'),
              onPressed: isBusy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Re-transcribe all memos?'),
                              content: const Text(
                                'This will overwrite existing transcriptions '
                                'using the currently selected language/model.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Re-transcribe'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!confirmed || !context.mounted) return;

                      try {
                        final count = await ref
                            .read(voiceMemoActionsProvider.notifier)
                            .retranscribeAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                count == 0
                                    ? 'No downloaded memos to re-transcribe'
                                    : 'Started re-transcribing $count memos',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Re-transcription failed: $e'),
                            ),
                          );
                        }
                      }
                    },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingSm,
            AppTheme.spacingMd,
            0,
          ),
          child: Text(
            'Use this after changing the language/model to regenerate old transcriptions.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

class _TranscriptionModelTile extends ConsumerStatefulWidget {
  final TranscriptionModelInfo info;
  final bool isSelected;

  const _TranscriptionModelTile({
    required this.info,
    required this.isSelected,
  });

  @override
  ConsumerState<_TranscriptionModelTile> createState() =>
      _TranscriptionModelTileState();
}

class _TranscriptionModelTileState extends ConsumerState<_TranscriptionModelTile> {
  bool _isDownloading = false;
  double _downloadProgress = 0;

  void _selectModel(WidgetRef ref) {
    ref
        .read(transcriptionEngineTypeProvider.notifier)
        .setType(widget.info.type);
    ref.invalidate(transcriptionConfiguredProvider);
  }

  static String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  Future<void> _downloadModel(BuildContext context, WidgetRef ref) async {
    final engine = createTranscriptionEngine(widget.info.type);
    StreamSubscription<TranscriptionEngineState>? sub;

    try {
      if (mounted) {
        setState(() {
          _isDownloading = true;
          _downloadProgress = 0;
        });
      }

      sub = engine.stateStream.listen((state) {
        if (!mounted) return;
        if (state.status == TranscriptionEngineStatus.downloading) {
          setState(() {
            _isDownloading = true;
            _downloadProgress = state.downloadProgress;
          });
        }
      });

      await engine.initialize();

      final downloaded = await engine.isAvailable();
      if (!downloaded) {
        throw Exception('Model file not found after download');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${widget.info.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      await sub?.cancel();
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });
      }

      engine.dispose();
      ref.invalidate(transcriptionModelStatusProvider(widget.info.type));
      ref.invalidate(transcriptionConfiguredProvider);
      ref.invalidate(transcriptionEngineProvider);
      ref.invalidate(transcriptionEngineStateProvider);
    }
  }

  Future<void> _deleteModel(BuildContext context, WidgetRef ref) async {
      final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete model?'),
            content: Text('Delete ${widget.info.name} from local storage?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    final engine = createTranscriptionEngine(widget.info.type);
    try {
      await engine.deleteModel();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${widget.info.name}')),
        );
      }
    } finally {
      engine.dispose();
      ref.invalidate(transcriptionModelStatusProvider(widget.info.type));
      ref.invalidate(transcriptionConfiguredProvider);
      ref.invalidate(transcriptionEngineProvider);
      ref.invalidate(transcriptionEngineStateProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(transcriptionModelStatusProvider(widget.info.type));

    return statusAsync.when(
      data: (status) {
        final downloadedSize = status.localSizeBytes != null
            ? _formatBytes(status.localSizeBytes!)
            : 'Not downloaded';

        return Column(
          children: [
            ListTile(
              onTap: () => _selectModel(ref),
              leading: Icon(
                Icons.memory,
                color: widget.isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              title: Text(widget.info.name),
              subtitle: Text(
                'Language: ${widget.info.language.toUpperCase()}\n'
                'Size: ${_formatBytes(widget.info.expectedSizeBytes)}\n'
                'Local: $downloadedSize',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              isThreeLine: true,
              trailing: Checkbox(
                value: widget.isSelected,
                onChanged: (_) => _selectModel(ref),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source URL',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.info.sourceUrl,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppTheme.spacingSm),
                    LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _downloadProgress > 0
                          ? 'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                          : 'Downloading...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppTheme.spacingSm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!status.downloaded)
                    TextButton.icon(
                      onPressed: _isDownloading
                          ? null
                          : () => _downloadModel(context, ref),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(48, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 16),
                      label: Text(_isDownloading ? 'Downloading' : 'Download'),
                    )
                  else
                    TextButton.icon(
                      onPressed: _isDownloading
                          ? null
                          : () => _deleteModel(context, ref),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(48, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                    ),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(widget.info.sourceUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(48, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open source'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
          ],
        );
      },
      loading: () => const ListTile(
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Loading model info...'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.error, color: AppTheme.errorColor),
        title: Text(widget.info.name),
        subtitle: Text('Error loading model status: $e'),
      ),
    );
  }
}

/// Consolidated permissions summary tile
/// 
/// Shows an overview of permission status and allows users to manage all permissions
class _PermissionsSummaryTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permState = ref.watch(permissionNotifierProvider);
    final status = permState.status;
    final missingCount = status.missingPermissions.length;
    
    // Calculate overall status
    final allGranted = status.hasAllPermissions;
    final hasCritical = status.hasCriticalPermissions;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (allGranted) {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle;
      statusText = 'All permissions granted';
    } else if (hasCritical) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.warning_amber;
      statusText = '$missingCount optional permission${missingCount > 1 ? 's' : ''} missing';
    } else {
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.error;
      statusText = 'Required permissions missing';
    }

    return Column(
      children: [
        _SettingsTile(
          leading: Icon(statusIcon, color: statusColor),
          title: 'App Permissions',
          subtitle: statusText,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPermissionsScreen(context),
        ),
        
        // Show quick status for each permission
        if (!allGranted) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Column(
              children: [
                // Bluetooth
                _QuickPermissionRow(
                  icon: Icons.bluetooth,
                  label: 'Bluetooth',
                  isGranted: status.bluetoothGranted,
                ),
                
                // Notifications (Android only)
                if (Platform.isAndroid)
                  _QuickPermissionRow(
                    icon: Icons.notifications,
                    label: 'Notifications',
                    isGranted: status.isNotificationGranted,
                  ),
                
                // Battery Optimization (Android only)
                if (Platform.isAndroid)
                  _QuickPermissionRow(
                    icon: Icons.battery_full,
                    label: 'Battery Optimization',
                    isGranted: status.batteryOptimizationDisabled,
                  ),
                
                // Location
                _QuickPermissionRow(
                  icon: Icons.location_on,
                  label: 'Location',
                  isGranted: status.isLocationGranted,
                ),
                
                // Notification Listener (Android only)
                if (Platform.isAndroid)
                  _QuickPermissionRow(
                    icon: Icons.notifications_active,
                    label: 'Notification Access',
                    isGranted: status.notificationListenerEnabled,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openPermissionsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const PermissionOnboardingScreen(
          isInitialOnboarding: false,
        ),
      ),
    );
  }
}

/// Quick permission status row
class _QuickPermissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isGranted;

  const _QuickPermissionRow({
    required this.icon,
    required this.label,
    required this.isGranted,
  });

  @override
  Widget build(BuildContext context) {
    final color = isGranted ? AppTheme.successColor : AppTheme.warningColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: color,
          ),
        ],
      ),
    );
  }
}