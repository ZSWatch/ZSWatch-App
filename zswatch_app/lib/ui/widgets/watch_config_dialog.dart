import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';

/// Dialog for watch management (rename, forget) - T117
///
/// Shows:
/// - Editable watch name text field
/// - "Save" button to save custom name
/// - "Forget Watch" button with red styling
/// - "Cancel" button
class WatchConfigDialog extends StatefulWidget {
  final WatchEntity watch;
  final Future<void> Function(String watchId, String? customName) onRename;
  final Future<void> Function(String watchId) onForget;

  const WatchConfigDialog({
    super.key,
    required this.watch,
    required this.onRename,
    required this.onForget,
  });

  /// Show the dialog and return true if the watch was forgotten (deleted)
  static Future<bool?> show({
    required BuildContext context,
    required WatchEntity watch,
    required Future<void> Function(String watchId, String? customName) onRename,
    required Future<void> Function(String watchId) onForget,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => WatchConfigDialog(
        watch: watch,
        onRename: onRename,
        onForget: onForget,
      ),
    );
  }

  @override
  State<WatchConfigDialog> createState() => _WatchConfigDialogState();
}

class _WatchConfigDialogState extends State<WatchConfigDialog> {
  late TextEditingController _nameController;
  bool _isSaving = false;
  bool _isForgetting = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate with custom name if set, otherwise use default name
    _nameController = TextEditingController(
      text: widget.watch.customName ?? widget.watch.name,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _displayName => widget.watch.customName ?? widget.watch.name;

  bool get _hasChanges {
    final newName = _nameController.text.trim();
    final currentName = widget.watch.customName ?? widget.watch.name;
    return newName != currentName && newName.isNotEmpty;
  }

  Future<void> _handleSave() async {
    if (_isSaving || _isForgetting) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      // If new name equals the original advertised name, clear customName
      final customName = newName == widget.watch.name ? null : newName;
      await widget.onRename(widget.watch.id, customName);

      if (mounted) {
        Navigator.of(context).pop(false); // false = not forgotten
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to rename: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleForget() async {
    if (_isSaving || _isForgetting) return;

    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget Watch'),
        content: Text(
          'Are you sure you want to forget "$_displayName"?\n\n'
          'This will remove the watch from your saved devices and unpair it. '
          'You will need to pair it again to use it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Forget'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isForgetting = true);

    try {
      await widget.onForget(widget.watch.id);

      if (mounted) {
        Navigator.of(context).pop(true); // true = was forgotten
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forget watch: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isForgetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isSaving || _isForgetting;

    return AlertDialog(
      title: const Text('Watch Settings'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Watch info header
            _buildWatchInfo(),
            const SizedBox(height: AppTheme.spacingLg),

            // Name text field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Custom Name',
                hintText: widget.watch.name,
                helperText: 'Leave empty to use default name',
                border: const OutlineInputBorder(),
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _nameController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              enabled: !isLoading,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Forget watch button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : _handleForget,
                icon: _isForgetting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('Forget Watch'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isLoading || !_hasChanges ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildWatchInfo() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: SvgPicture.asset(
            'assets/images/ZSWatch_Logo.svg',
            width: 28,
            height: 28,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.watch.customName != null)
                Text(
                  'Original: ${widget.watch.name}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              if (widget.watch.firmwareVersion != null)
                Text(
                  'v${widget.watch.firmwareVersion}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
