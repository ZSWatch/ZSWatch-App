import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/ai_providers.dart';
import '../../../providers/demo_mode_provider.dart';
import '../../../providers/permission_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/voice_memo_providers.dart';
import '../../../services/ai/llm_service.dart';
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

          // AI Processing Section
          _SectionHeader(title: 'AI Processing'),
          _AiProcessingSection(),

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

/// AI Processing section
class _AiProcessingSection extends ConsumerWidget {
  const _AiProcessingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localAiEnabled = ref.watch(localAiEnabledProvider);
    final autoProcessEnabled = ref.watch(autoProcessVoiceNotesProvider);
    final aiActionsState = ref.watch(aiActionsProvider);
    final isBusy = aiActionsState.isLoading;

    return Column(
      children: [
        // Local AI Processing toggle
        _SettingsTile(
          leading: Icon(
            Icons.auto_awesome,
            color: localAiEnabled ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
          title: 'Local AI Processing',
          subtitle: 'Enable AI processing of voice notes',
          trailing: Switch(
            value: localAiEnabled,
            onChanged: (value) {
              ref.read(localAiEnabledProvider.notifier).setEnabled(value);
            },
          ),
        ),

        // Auto-process after transcription toggle
        Opacity(
          opacity: localAiEnabled ? 1.0 : 0.5,
          child: _SettingsTile(
            leading: Icon(
              Icons.autorenew,
              color: autoProcessEnabled && localAiEnabled
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
            title: 'Auto-process after transcription',
            subtitle: localAiEnabled
                ? 'Automatically process voice notes after transcription'
                : 'Enable Local AI Processing first',
            trailing: Switch(
              value: autoProcessEnabled,
              onChanged: localAiEnabled
                  ? (value) {
                      ref
                          .read(autoProcessVoiceNotesProvider.notifier)
                          .setEnabled(value);
                    }
                  : null,
            ),
          ),
        ),

        // LLM Model tile
        const _LlmModelTile(),

        // Process all unprocessed button
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
                  : const Icon(Icons.auto_awesome),
              label: Text(isBusy
                  ? 'Processing...'
                  : 'Process all unprocessed'),
              onPressed: isBusy || !localAiEnabled
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Process all unprocessed memos?'),
                              content: const Text(
                                'This will process all voice memos that have not yet been processed with AI.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Process'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!confirmed || !context.mounted) return;

                      try {
                        await ref
                            .read(aiActionsProvider.notifier)
                            .processAllUnprocessed();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Started processing unprocessed memos'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Processing failed: $e'),
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
            'Process voice memos with AI to extract tasks, summaries, and more.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

/// LLM Model tile showing download status
class _LlmModelTile extends ConsumerStatefulWidget {
  const _LlmModelTile();

  @override
  ConsumerState<_LlmModelTile> createState() => _LlmModelTileState();
}

class _LlmModelTileState extends ConsumerState<_LlmModelTile> {
  static String _formatBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    }
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  void _refreshModelProviders() {
    ref.invalidate(llmAvailableModelsProvider);
    ref.invalidate(selectedLlmModelInfoProvider);
    ref.invalidate(llmModelDownloadedProvider);
    ref.invalidate(llmModelSizeProvider);
    ref.invalidate(llmServiceStateProvider);
  }

  Future<void> _downloadModel(BuildContext context) async {
    final llmService = ref.read(llmServiceProvider);

    try {
      await llmService.downloadModel();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model downloaded successfully')),
        );
      }

      _refreshModelProviders();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteModel(BuildContext context) async {
    final selectedModel = await ref.read(selectedLlmModelInfoProvider.future);
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete model?'),
            content: Text(
              selectedModel.userProvided
                  ? 'Delete this imported model from local storage?'
                  : 'Delete the selected model from local storage?',
            ),
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

    final llmService = ref.read(llmServiceProvider);

    try {
      await llmService.deleteModel();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model deleted')),
        );
      }

      _refreshModelProviders();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _importModel(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select a GGUF model file',
      );

      final path = result?.files.single.path;
      if (path == null) {
        return;
      }

      if (!path.toLowerCase().endsWith('.gguf')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only .gguf model files can be imported'),
            ),
          );
        }
        return;
      }

      final llmService = ref.read(llmServiceProvider);
      final imported = await llmService.importModel(path);
      ref.read(selectedAiModelIdProvider.notifier).setModelId(imported.id);
      _refreshModelProviders();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${imported.filename}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedModelId = ref.watch(selectedAiModelIdProvider);
    final availableModelsAsync = ref.watch(llmAvailableModelsProvider);
    final selectedModelAsync = ref.watch(selectedLlmModelInfoProvider);
    final isDownloadedAsync = ref.watch(llmModelDownloadedProvider);
    final modelSizeAsync = ref.watch(llmModelSizeProvider);
    final serviceStateAsync = ref.watch(llmServiceStateProvider);

    return selectedModelAsync.when(
      data: (selectedModel) {
        return isDownloadedAsync.when(
          data: (isDownloaded) {
        final localSize = modelSizeAsync.when(
          data: (size) => size != null ? _formatBytes(size) : null,
          loading: () => null,
          error: (_, __) => null,
        );

        final isDownloading = serviceStateAsync.when(
          data: (state) => state.status == LlmServiceStatus.downloading,
          loading: () => false,
          error: (_, __) => false,
        );

        final downloadProgress = serviceStateAsync.when(
          data: (state) => state.downloadProgress,
          loading: () => 0.0,
          error: (_, __) => 0.0,
        );

        final canDownload = selectedModel.isDownloadable && !selectedModel.userProvided;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Active model status banner ---
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                AppTheme.spacingSm,
                AppTheme.spacingMd,
                0,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDownloaded
                    ? AppTheme.successColor.withValues(alpha: 0.08)
                    : AppTheme.warningColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: isDownloaded
                      ? AppTheme.successColor.withValues(alpha: 0.3)
                      : AppTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDownloaded ? Icons.check_circle : Icons.warning_amber,
                    size: 20,
                    color: isDownloaded
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDownloaded ? 'Active model' : 'Model not downloaded',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: isDownloaded
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedModel.displayName,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (localSize != null)
                          Text(
                            localSize,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- Model selector dropdown ---
            availableModelsAsync.when(
              data: (models) => Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  12,
                  AppTheme.spacingMd,
                  0,
                ),
                child: DropdownButtonFormField<String>(
                  value: models.any((m) => m.id == selectedModelId)
                      ? selectedModelId
                      : models.isNotEmpty
                          ? models.first.id
                          : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Change model',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: models
                      .map(
                        (model) => DropdownMenuItem<String>(
                          value: model.id,
                          child: Text(
                            model.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isDownloading
                      ? null
                      : (value) {
                          if (value == null) return;
                          ref
                              .read(selectedAiModelIdProvider.notifier)
                              .setModelId(value);
                          _refreshModelProviders();
                        },
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppTheme.spacingMd),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Text('Error loading models: $e',
                    style: const TextStyle(color: AppTheme.errorColor)),
              ),
            ),

            // --- Download progress ---
            if (isDownloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  12,
                  AppTheme.spacingMd,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: downloadProgress > 0 ? downloadProgress : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      downloadProgress > 0
                          ? 'Downloading... ${(downloadProgress * 100).toStringAsFixed(0)}%'
                          : 'Starting download...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

            // --- Action buttons ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                12,
                AppTheme.spacingMd,
                AppTheme.spacingSm,
              ),
              child: Row(
                children: [
                  // Primary action: Download or Delete for the selected model
                  if (isDownloaded)
                    OutlinedButton.icon(
                      onPressed: isDownloading
                          ? null
                          : () => _deleteModel(context),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                    )
                  else if (canDownload)
                    FilledButton.icon(
                      onPressed: isDownloading
                          ? null
                          : () => _downloadModel(context),
                      icon: isDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download, size: 18),
                      label: Text(
                          isDownloading ? 'Downloading...' : 'Download'),
                    ),
                  const SizedBox(width: AppTheme.spacingSm),
                  // Secondary action: Import a custom GGUF
                  OutlinedButton.icon(
                    onPressed: isDownloading
                        ? null
                        : () => _importModel(context),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Import .gguf'),
                  ),
                ],
              ),
            ),
          ],
        );
          },
          loading: () => const ListTile(
            leading: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Loading model status...'),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.error, color: AppTheme.errorColor),
            title: Text(selectedModel.displayName),
            subtitle: Text('Error loading model status: $e'),
          ),
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
        title: const Text('AI model'),
        subtitle: Text('Error loading model status: $e'),
      ),
    );
  }
}