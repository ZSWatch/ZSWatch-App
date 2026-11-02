/// The native owner's ICA connection. Tokens never leave native code.
class IcaStatus {
  final bool connected;
  final bool newest;
  final String? listId;

  /// Null when the lists could not be read; [error] says why.
  final List<IcaListSummary>? lists;
  final String? targetId;
  final String? error;

  const IcaStatus({
    required this.connected,
    this.newest = true,
    this.listId,
    this.lists,
    this.targetId,
    this.error,
  });

  static const disconnected = IcaStatus(connected: false);

  IcaListSummary? get target =>
      lists?.where((l) => l.id == targetId).firstOrNull;

  factory IcaStatus.decode(Object? value) {
    if (value is! Map || value['version'] != 1 || value['connected'] is! bool) {
      throw const FormatException('Invalid ICA status');
    }
    final lists = value['lists'];
    return IcaStatus(
      connected: value['connected'] as bool,
      newest: value['newest'] != false,
      listId: value['list_id'] as String?,
      lists: lists is List
          ? [
              for (final l in lists.cast<Map<Object?, Object?>>())
                IcaListSummary(
                  l['id']! as String,
                  l['title'] as String? ?? '',
                  l['items'] as int? ?? 0,
                ),
            ]
          : null,
      targetId: value['target_id'] as String?,
      error: value['error'] as String?,
    );
  }
}

class IcaListSummary {
  final String id;
  final String title;
  final int openItems;

  const IcaListSummary(this.id, this.title, this.openItems);
}
