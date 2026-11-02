import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_integrations/llm_integrations.dart';

import '../../../providers/companion_runtime_providers.dart';
import '../../../providers/openrouter_providers.dart';
import '../../../services/ai/openrouter_client.dart';
import '../../../services/integrations/ica_session_service.dart';
import '../../../services/integrations/ica_shopping_list_api.dart';
import '../../../services/integrations/ica_shopping_proposal_service.dart';

/// Optional, phone-side ICA integration. The model only prepares proposals;
/// the user chooses the list and confirms each write here.
class IcaIntegrationScreen extends ConsumerStatefulWidget {
  const IcaIntegrationScreen({super.key});

  @override
  ConsumerState<IcaIntegrationScreen> createState() =>
      _IcaIntegrationScreenState();
}

class _IcaIntegrationScreenState extends ConsumerState<IcaIntegrationScreen> {
  final _session = IcaSessionService();
  late final IcaShoppingListApi _api = IcaShoppingListApi(_session.accessToken);
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _listName = TextEditingController();
  final _item = TextEditingController();
  final _memo = TextEditingController();
  bool _connected = false;
  bool _awaitingCode = false;
  bool _busy = false;
  bool _useNewestList = true;
  String? _error;
  String? _selectedId;
  List<IcaShoppingList> _lists = const [];
  IcaShoppingList? _selected;
  ShoppingExtractionResult? _proposal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final connected = await _session.hasSession;
      final preferredId = connected ? await _session.preferredListId : null;
      final useNewest = await _session.useNewestList;
      if (!mounted) return;
      setState(() {
        _connected = connected;
        _selectedId = preferredId;
        _useNewestList = useNewest;
      });
      if (connected) await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (mounted) setState(() => _error = error.toString());
  }

  Future<void> _refresh() async {
    final lists = await _api.lists();
    final hasSelection = lists.any((list) => list.id == _selectedId);
    final id = _useNewestList || !hasSelection
        ? IcaShoppingListApi.newestList(lists)?.id
        : _selectedId;
    final selected = id == null ? null : await _api.list(id);
    await _session.setPreferredListId(id);
    if (mounted) {
      setState(() {
        _lists = lists;
        _selectedId = id;
        _selected = selected;
      });
    }
  }

  Future<void> _propose() async {
    final key = await ref.read(companionClientProvider).cloudCredential();
    if (key == null || key.isEmpty) {
      throw StateError('Add an OpenRouter key under Voice memo models first');
    }
    final client = OpenRouterClient(key);
    try {
      final service = IcaShoppingProposalService(
        client,
        ref.read(openRouterAnalysisModelProvider),
      );
      final result = await service.propose(_memo.text);
      if (mounted) setState(() => _proposal = result);
    } finally {
      client.close();
    }
  }

  Future<void> _confirmAdd(List<String> items, {String? hint}) async {
    final currentLists = await _api.lists();
    final target = hint == null
        ? _useNewestList
              ? IcaShoppingListApi.newestList(currentLists)
              : currentLists.where((list) => list.id == _selectedId).firstOrNull
        : currentLists
              .where((list) => list.title.toLowerCase() == hint.toLowerCase())
              .firstOrNull;
    if (target == null) {
      throw StateError(
        hint == null
            ? 'Create or select an ICA list first'
            : 'No ICA list named "$hint". Create that list or change the memo.',
      );
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to ICA list?'),
        content: SingleChildScrollView(
          child: Text('${target.title}\n\n${items.join('\n')}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add items'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (hint == null && _useNewestList) {
      final newest = IcaShoppingListApi.newestList(await _api.lists());
      if (newest?.id != target.id) {
        await _refresh();
        throw StateError(
          'A newer ICA list appeared. Review the destination again.',
        );
      }
    }
    final updated = await _api.addItems(target.id, items);
    if (hint == null && _useNewestList) {
      await _session.setPreferredListId(target.id);
    }
    if (mounted) {
      setState(() {
        if (_selectedId == target.id || (hint == null && _useNewestList)) {
          _selectedId = target.id;
          _selected = updated;
          _lists = currentLists;
        }
        _item.clear();
        _proposal = null;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _listName.dispose();
    _item.dispose();
    _memo.dispose();
    _api.close();
    _session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'ICA shopping lists',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional integration. ICA uses an unofficial API that may change. '
            'OpenRouter sees only the text you submit for a proposal; ICA credentials and lists stay outside the model request.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          if (!_connected) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'ICA account email'),
            ),
            const SizedBox(height: 8),
            if (!_awaitingCode)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await _session.startEmailLogin(_email.text);
                        if (mounted) setState(() => _awaitingCode = true);
                      }),
                child: const Text('Send email code'),
              ),
            if (_awaitingCode) ...[
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Six-digit email code',
                ),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await _session.finishEmailLogin(_code.text.trim());
                        _code.clear();
                        if (mounted) {
                          setState(() {
                            _connected = true;
                            _awaitingCode = false;
                          });
                        }
                        await _refresh();
                      }),
                child: const Text('Connect ICA'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await _session.startEmailLogin(_email.text);
                        _code.clear();
                      }),
                child: const Text('Send a new code'),
              ),
            ],
          ] else ...[
            Row(
              children: [
                const Expanded(child: Text('Connected to ICA')),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _session.disconnect();
                          if (mounted) {
                            setState(() {
                              _connected = false;
                              _lists = const [];
                              _selected = null;
                              _selectedId = null;
                              _proposal = null;
                              _useNewestList = true;
                            });
                          }
                        }),
                  child: const Text('Disconnect'),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('Always use newest ICA list'),
              subtitle: const Text(
                'Automatically follows the latest list you create in ICA.',
              ),
              value: _useNewestList,
              onChanged: _busy
                  ? null
                  : (value) => _run(() async {
                      await _session.setUseNewestList(value);
                      _useNewestList = value;
                      await _refresh();
                    }),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedId),
              initialValue: _selectedId,
              decoration: InputDecoration(
                labelText: _useNewestList
                    ? 'Newest ICA list'
                    : 'Selected ICA list',
              ),
              items: [
                for (final list in _lists)
                  DropdownMenuItem(value: list.id, child: Text(list.title)),
              ],
              onChanged: _busy || _useNewestList
                  ? null
                  : (id) => _run(() async {
                      if (id == null) return;
                      _selectedId = id;
                      _selected = await _api.list(id);
                      await _session.setPreferredListId(id);
                      if (mounted) setState(() {});
                    }),
            ),
            TextButton.icon(
              onPressed: _busy ? null : () => _run(_refresh),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh lists'),
            ),
            TextField(
              controller: _listName,
              decoration: const InputDecoration(labelText: 'New ICA list name'),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final created = await _api.create(_listName.text);
                      _selectedId = created.id;
                      _listName.clear();
                      await _refresh();
                    }),
              child: const Text('Create list'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _item,
              decoration: const InputDecoration(labelText: 'Item to add'),
            ),
            FilledButton(
              onPressed: _busy || _selectedId == null
                  ? null
                  : () => _run(() => _confirmAdd([_item.text])),
              child: const Text('Review and add item'),
            ),
            const Divider(height: 32),
            Text(
              'OpenRouter proposal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              controller: _memo,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Lägg två liter mjölk och ägg på inköpslistan',
              ),
            ),
            FilledButton.tonal(
              onPressed: _busy ? null : () => _run(_propose),
              child: const Text('Suggest items from text'),
            ),
            if (_proposal != null && !_proposal!.isValid)
              Text(_proposal!.problem ?? 'Could not read proposal'),
            if (_proposal != null &&
                _proposal!.isValid &&
                _proposal!.drafts.isEmpty)
              const Text('No shopping items found.'),
            for (final draft in _proposal?.drafts ?? <ShoppingListDraft>[])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.listName ??
                            (_useNewestList
                                ? 'Use newest ICA list'
                                : 'Use selected list'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      for (final item in draft.items) Text('• $item'),
                      TextButton(
                        onPressed: _busy || _selectedId == null
                            ? null
                            : () => _run(
                                () => _confirmAdd(
                                  draft.items,
                                  hint: draft.listName,
                                ),
                              ),
                        child: const Text('Review and add'),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 32),
            Text(
              'Current list',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final row in _selected?.rows ?? <IcaShoppingRow>[])
              ListTile(
                title: Text(row.text),
                leading: Icon(
                  row.checked ? Icons.check_box : Icons.check_box_outline_blank,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
