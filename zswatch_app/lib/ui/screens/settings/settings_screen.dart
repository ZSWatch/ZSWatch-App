import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/demo_mode_provider.dart';
import '../../../providers/settings_providers.dart';
import '../../navigation/app_router.dart';

import 'companion_settings_view.dart';
import 'companion_permissions_summary.dart';

/// Settings screen for app configuration
///
/// Displays:
/// - DFU settings (keep screen on)
/// - About section (app version, links)
final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // TODO: Update these URLs to point to the correct repositories
  static const String _appGithubUrl =
      'https://github.com/ZSWatch/ZSWatch-App'; // <-- Change to app repo
  static const String _firmwareGithubUrl =
      'https://github.com/ZSWatch/ZSWatch'; // <-- Change to firmware repo

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Connection Settings
          const _SectionHeader(title: 'Connection'),
          const CompanionConnectionSettings(),

          const Divider(height: 32),

          // Permissions Section (consolidated)
          const _SectionHeader(title: 'Permissions'),
          const CompanionPermissionsSummary(),

          const Divider(height: 32),

          // Firmware Update Settings
          const _SectionHeader(title: 'Firmware Update'),
          _SettingsTile(
            leading: const Icon(
              Icons.screen_lock_portrait,
              color: AppTheme.textSecondary,
            ),
            title: 'Keep Screen On During DFU',
            subtitle: 'Prevent screen timeout during firmware updates',
            trailing: Switch(
              value: ref.watch(keepScreenOnDuringDfuProvider),
              onChanged: (value) {
                ref
                    .read(keepScreenOnDuringDfuProvider.notifier)
                    .setEnabled(value);
              },
            ),
          ),

          const Divider(height: 32),

          // Voice Memo AI (sub-page)
          const _SectionHeader(title: 'Voice Memo AI'),
          _SettingsTile(
            leading: const Icon(Icons.mic, color: AppTheme.primaryColor),
            title: 'Voice memo models',
            subtitle: 'Transcription, analysis and automatic processing',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.aiModels),
          ),

          const Divider(height: 32),

          // About Section
          const _SectionHeader(title: 'About'),
          _SettingsTile(
            leading: const Icon(
              Icons.info_outline,
              color: AppTheme.textSecondary,
            ),
            title: 'App Version',
            subtitle: ref.watch(_appVersionProvider).valueOrNull ?? '',
          ),
          _SettingsTile(
            leading: const Icon(
              Icons.phone_android,
              color: AppTheme.textSecondary,
            ),
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
            leading: const Icon(
              Icons.description_outlined,
              color: AppTheme.textSecondary,
            ),
            title: 'Licenses',
            subtitle: 'Open source licenses',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLicensesPage(
              context,
              ref.read(_appVersionProvider).valueOrNull,
            ),
          ),

          const Divider(height: 32),

          // Demo Mode (for app store reviewers without hardware)
          const _SectionHeader(title: 'Developer'),
          _SettingsTile(
            leading: Icon(
              Icons.science,
              color: ref.watch(demoModeProvider)
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
            title: 'Demo Mode',
            subtitle:
                ('Preview the app; a real watch is temporarily disconnected'),
            trailing: Switch(
              value: ref.watch(demoModeProvider),
              onChanged: ref.watch(demoModeBusyProvider)
                  ? null
                  : (value) async {
                      try {
                        await ref.read(demoModeControllerProvider).set(value);
                        if (value && context.mounted) {
                          context.go(AppRoutes.home);
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
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

  void _showLicensesPage(BuildContext context, String? version) {
    showLicensePage(
      context: context,
      applicationName: 'ZSWatch Companion',
      applicationVersion: version,
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
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
