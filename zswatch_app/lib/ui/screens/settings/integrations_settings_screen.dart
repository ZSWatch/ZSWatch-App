import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/ica_status.dart';
import '../../../providers/integration_providers.dart';
import '../../../services/integrations/ica_session_service.dart';

/// Services voice memos can act on. Shopping items in a memo are added to
/// ICA after the watch's undo window; analysis must run on OpenRouter.
class IntegrationsSettingsScreen extends ConsumerWidget {
  const IntegrationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(icaStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations')),
      body: RefreshIndicator(
        onRefresh: ref.read(icaStatusProvider.notifier).refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const ListTile(
              leading: Icon(Icons.shopping_cart_outlined),
              title: Text('ICA shopping list'),
              subtitle: Text(
                'Say "köp mjölk och ägg" in a voice memo and the items are '
                'added to your ICA list. Needs OpenRouter analysis. Uses '
                'ICA\'s unofficial app API, which may stop working.',
              ),
            ),
            ...status.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                ListTile(
                  title: const Text('Could not read the ICA connection'),
                  subtitle: Text('$error'),
                ),
              ],
              data: (ica) => ica.connected
                  ? _connected(context, ref, ica)
                  : [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Connect ICA'),
                          onPressed: () => _connect(context, ref),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _connected(BuildContext context, WidgetRef ref, IcaStatus ica) {
    final notifier = ref.read(icaStatusProvider.notifier);
    final lists = ica.lists;
    return [
      SwitchListTile(
        title: const Text('Add to the newest list'),
        subtitle: Text(
          ica.target != null
              ? 'Items go to "${ica.target!.title}"'
              : ica.newest
              ? 'Create a list in the ICA app first'
              : 'Choose a list below',
        ),
        value: ica.newest,
        onChanged: (value) => _guard(
          context,
          notifier.setTarget(
            newest: value,
            listId: value ? null : (ica.listId ?? ica.targetId),
          ),
        ),
      ),
      if (lists == null)
        ListTile(
          leading: const Icon(Icons.cloud_off),
          title: Text(
            ica.error == 'ICA_AUTH'
                ? 'ICA signed this phone out. Reconnect.'
                : 'Could not read your ICA lists',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: notifier.refresh,
          ),
        )
      else
        RadioGroup<String>(
          groupValue: ica.targetId,
          onChanged: (id) {
            if (ica.newest || id == null) return;
            _guard(context, notifier.setTarget(newest: false, listId: id));
          },
          child: Column(
            children: [
              for (final list in lists)
                RadioListTile<String>(
                  value: list.id,
                  enabled: !ica.newest,
                  title: Text(list.title.isEmpty ? 'Untitled' : list.title),
                  subtitle: Text('${list.openItems} items'),
                ),
            ],
          ),
        ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Disconnect ICA'),
        onTap: () => _guard(context, notifier.disconnect()),
      ),
    ];
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final session = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const _IcaLoginDialog(),
    );
    if (session == null || !context.mounted) return;
    await _guard(
      context,
      ref.read(icaStatusProvider.notifier).connect(session),
    );
  }

  static Future<void> _guard(BuildContext context, Future<void> action) async {
    try {
      await action;
    } catch (error) {
      debugPrint('[IntegrationsSettingsScreen] ICA change failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ICA: $error')));
      }
    }
  }
}

/// Email, then the six-digit code ICA sends. Returns the OAuth session.
class _IcaLoginDialog extends StatefulWidget {
  const _IcaLoginDialog();

  @override
  State<_IcaLoginDialog> createState() => _IcaLoginDialogState();
}

class _IcaLoginDialogState extends State<_IcaLoginDialog> {
  final _service = IcaSessionService();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _service.close();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_codeSent) {
        await _service.startEmailLogin(_email.text);
        if (mounted) setState(() => _codeSent = true);
      } else {
        final session = await _service.finishEmailLogin(_code.text.trim());
        if (mounted) Navigator.of(context).pop(session);
      }
    } catch (error) {
      debugPrint('[IcaLoginDialog] Sign-in failed: $error');
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Connect ICA'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _email,
          enabled: !_codeSent && !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'ICA account email'),
        ),
        if (_codeSent)
          TextField(
            controller: _code,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Code from email'),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_codeSent ? 'Connect' : 'Send code'),
      ),
    ],
  );
}
