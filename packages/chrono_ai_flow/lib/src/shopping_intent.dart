/// Optional "shopping" intent for the voice memo prompt. The app adds it only
/// when a shopping-list integration is connected and a cloud model analyses
/// the memo; local models never see it.
abstract final class ShoppingIntent {
  static const String intent = 'shopping';
  static const int maxItems = 64;
  static const int maxItemLength = 240;

  static const String _anchor = 'Current datetime:';

  static const String section = '''
SHOPPING LIST (connected):
- "shopping" = products to buy: groceries and household supplies ("köp mjölk", "vi behöver kaffe", "lägg ägg på inköpslistan", "we are out of dish soap"). It replaces "note" for things to buy.
- Put ALL products of the memo in ONE "shopping" item with an "items" array, one string per product. Copy each product phrase from the memo with its quantity, unit and brand ("två liter mjölk"). Never translate items.
- For "shopping", "title" is "" and both datetime fields are null.
- Not shopping: removed, crossed off, already bought or negated products, buying at a time ("köp mjölk imorgon klockan 5" is a reminder), services and big purchases (a new car, book a table).

Memo: "Köp mjölk och två paket kaffe, och ring Anna imorgon klockan 9"
[{"intent":"shopping","title":"","items":["mjölk","två paket kaffe"],"datetime_expression_original":null,"datetime_expression_english":null},{"intent":"reminder","title":"ring Anna","datetime_expression_original":"imorgon klockan 9","datetime_expression_english":"tomorrow at 9"}]

Memo: "Lägg till bröd men inte smör på inköpslistan"
[{"intent":"shopping","title":"","items":["bröd"],"datetime_expression_original":null,"datetime_expression_english":null}]

''';

  /// For the long-memo (brain dump) prompt, whose actions are objects.
  static const String brainDumpRule = '''
- SHOPPING LIST (connected): products to buy (groceries, household supplies) go in ONE action {"type": "shopping", "title": "", "items": ["product with quantity, unit and brand", ...]}. Copy each product from the transcript, never translate. Not shopping: removed, already bought or negated products, buying at a time (a reminder), services and big purchases.''';

  /// [template] with [section] before its current-time block.
  static String addTo(String template) {
    final at = template.indexOf(_anchor);
    if (at < 0) throw ArgumentError('Template has no "$_anchor" block');
    return template.replaceRange(at, at, section);
  }

  /// Product phrases from a model's "items" value: trimmed, non-empty and
  /// bounded. Anything else in the list makes the whole value invalid.
  static List<String>? items(Object? value) {
    if (value is! List || value.isEmpty || value.length > maxItems) return null;
    final items = <String>[];
    for (final item in value) {
      if (item is! String) return null;
      final text = item.trim();
      if (text.isEmpty || text.length > maxItemLength) return null;
      items.add(text);
    }
    return items;
  }
}
