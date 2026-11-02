import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'ica_session_service.dart';

class IcaShoppingList {
  const IcaShoppingList({
    required this.id,
    required this.title,
    required this.rows,
  });

  factory IcaShoppingList.fromJson(Map<String, dynamic> json) =>
      IcaShoppingList(
        id: json['offlineId'] as String,
        title: json['title'] as String,
        rows: [
          for (final row in (json['rows'] as List?) ?? const [])
            if (row is Map)
              IcaShoppingRow(
                id: row['offlineId'] as String,
                text: row['productName'] as String,
                checked: row['isStrikedOver'] == true,
              ),
        ],
      );

  final String id;
  final String title;
  final List<IcaShoppingRow> rows;
}

class IcaShoppingRow {
  const IcaShoppingRow({
    required this.id,
    required this.text,
    required this.checked,
  });
  final String id;
  final String text;
  final bool checked;
}

/// Small ICA-specific adapter. It sends only an OAuth access token to ICA;
/// OpenRouter never sees list contents, IDs or account credentials.
class IcaShoppingListApi {
  IcaShoppingListApi(IcaSessionService session, {http.Client? client})
    : _token = session.accessToken,
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  IcaShoppingListApi.withToken(this._token, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _base =
      'https://apimgw-pub.ica.se/sverige/digx/mobile/shoppinglistservice/v1/shoppinglists';
  final Future<String> Function() _token;
  final http.Client _client;
  final bool _ownsClient;
  static const _uuid = Uuid();
  static final _random = Random.secure();

  Future<List<IcaShoppingList>> lists() async {
    final json = await _request('GET', '');
    final rawLists = json['shoppingLists'];
    if (rawLists is! List<Object?>) {
      throw const FormatException('Unexpected ICA list collection');
    }
    return [
      for (final list in rawLists)
        if (list is Map<String, dynamic>) IcaShoppingList.fromJson(list),
    ];
  }

  Future<IcaShoppingList> list(String id) async => IcaShoppingList.fromJson(
    await _request('GET', '/${Uri.encodeComponent(id)}'),
  );

  Future<IcaShoppingList> create(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 160) {
      throw const FormatException('Enter a list name up to 160 characters');
    }
    final id = _uuid.v4().toUpperCase();
    await _request(
      'POST',
      '',
      body: {
        'offlineId': id,
        'title': trimmed,
        'commentText': '',
        'sortingStore': 0,
        'rows': <Object>[],
        'latestChange': _timestamp(),
      },
    );
    return list(id);
  }

  Future<IcaShoppingList> addItems(String listId, List<String> items) async {
    if (items.isEmpty ||
        items.length > 64 ||
        items.any((item) => item.trim().isEmpty || item.length > 240)) {
      throw const FormatException('Invalid shopping items');
    }
    final ids = <String>[];
    final rows = [
      for (final item in items)
        {
          'offlineId': _newId(ids),
          'productName': item.trim(),
          'sourceId': -(_random.nextInt(999000000) + 1000000),
          'isStrikedOver': false,
          'recipes': <Object>[],
        },
    ];
    await _request(
      'POST',
      '/${Uri.encodeComponent(listId)}/sync',
      body: {'createdRows': rows},
    );
    final updated = await list(listId);
    if (!updated.rows.map((row) => row.id).toSet().containsAll(ids)) {
      throw StateError(
        'ICA did not confirm every added item; refresh the list',
      );
    }
    return updated;
  }

  String _newId(List<String> ids) {
    final id = _uuid.v4().toUpperCase();
    ids.add(id);
    return id;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('$_base$path');
    final headers = {
      'Authorization': 'Bearer ${await _token()}',
      'Content-Type': 'application/json',
    };
    final response =
        await (method == 'GET'
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'ICA shopping list returned HTTP ${response.statusCode}',
      );
    }
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected ICA shopping list response');
    }
    return decoded;
  }

  static String _timestamp() =>
      '${DateTime.now().toUtc().toIso8601String().split('.').first}Z';

  void close() {
    if (_ownsClient) _client.close();
  }
}
