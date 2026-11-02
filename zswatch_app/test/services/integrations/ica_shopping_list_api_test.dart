import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zswatch_app/services/integrations/ica_shopping_list_api.dart';

void main() {
  test('newest list follows ICA numeric ID rather than response order', () {
    IcaShoppingList list(int? numericId, String name) =>
        IcaShoppingList.fromJson({
          'id': numericId,
          'offlineId': name,
          'title': name,
          'rows': <Object>[],
        });
    final older = list(100, 'older');
    final newer = list(101, 'newer');
    expect(IcaShoppingListApi.newestList([older, newer]), newer);
    expect(IcaShoppingListApi.newestList([newer, older]), newer);
    expect(IcaShoppingListApi.newestList([]), isNull);
    expect(
      () => IcaShoppingListApi.newestList([older, list(null, 'unknown')]),
      throwsFormatException,
    );
  });

  test(
    'creates a list and adds rows using the verified mobile contract',
    () async {
      String? listId;
      String? rowId;
      var listReads = 0;
      final requests = <String>[];
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        requests.add('${request.method} ${request.url.path}');
        if (request.method == 'POST' &&
            request.url.path.endsWith('/shoppinglists')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          listId = body['offlineId'] as String;
          expect(body['title'], 'Test list');
          expect(body['rows'], isEmpty);
          return http.Response('{}', 200);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/sync')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final rows = body['createdRows'] as List;
          expect(rows, hasLength(1));
          final row = rows.single as Map<String, dynamic>;
          rowId = row['offlineId'] as String;
          expect(row['productName'], 'två liter mjölk');
          expect(row['sourceId'], lessThan(0));
          expect(row['isStrikedOver'], false);
          return http.Response('{}', 200);
        }
        if (request.method == 'GET' && request.url.path.endsWith('/$listId')) {
          listReads++;
          return http.Response(
            jsonEncode({
              'offlineId': listId,
              'title': 'Test list',
              'rows': rowId == null
                  ? <Object>[]
                  : [
                      {
                        'offlineId': rowId,
                        'productName': 'två liter mjölk',
                        'isStrikedOver': false,
                      },
                    ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });
      final api = IcaShoppingListApi(() async => 'test-token', client: client);
      final created = await api.create('Test list');
      final updated = await api.addItems(created.id, ['två liter mjölk']);
      expect(updated.rows.single.text, 'två liter mjölk');
      expect(listReads, 2);
      expect(requests.map((r) => r.split(' ').first), [
        'POST',
        'GET',
        'POST',
        'GET',
      ]);
      api.close();
      client.close();
    },
  );

  test(
    'a failed sync does not retry and cannot silently duplicate rows',
    () async {
      var writes = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST') writes++;
        return http.Response('{}', 500);
      });
      final api = IcaShoppingListApi(() async => 'test-token', client: client);
      await expectLater(api.addItems('test-list', ['mjölk']), throwsStateError);
      expect(writes, 1);
      api.close();
      client.close();
    },
  );
}
