import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zswatch_app/services/dev_ota/dev_ota_client.dart';

void main() {
  final zip = utf8.encode('firmware');
  final build = {
    'id': '20261125-abc',
    'sha256': sha256.convert(zip).toString(),
    'size': zip.length,
    'note': 'Fix X',
    'branch': 'main',
    'commit': 'abcdef1234',
  };

  test('uses the URL prefix, token and long-poll arguments', () async {
    late Uri seen;
    late String? auth;
    final client = DevOtaClient(
      'https://mac.ts.net/zswatch-ota/',
      'secret',
      client: MockClient((request) async {
        seen = request.url;
        auth = request.headers['Authorization'];
        return http.Response(jsonEncode({'build': build}), 200);
      }),
    );
    final latest = await client.latest(
      after: 'old',
      wait: const Duration(seconds: 25),
    );
    expect(seen.path, '/zswatch-ota/api/latest');
    expect(seen.queryParameters, {'after': 'old', 'wait': '25'});
    expect(auth, 'Bearer secret');
    expect(latest?.id, '20261125-abc');
    expect(latest?.shortCommit, 'abcdef12');
  });

  test('rejects a download whose hash does not match', () async {
    final dir = await Directory.systemTemp.createTemp('dev_ota');
    addTearDown(() => dir.delete(recursive: true));
    final parsed = DevOtaBuild.fromJson(build)!;
    final good = DevOtaClient(
      'http://x',
      't',
      client: MockClient((_) async => http.Response.bytes(zip, 200)),
    );
    final file = await good.download(parsed, File('${dir.path}/a.zip'));
    expect(await file.readAsBytes(), zip);

    final bad = DevOtaClient(
      'http://x',
      't',
      client: MockClient((_) async => http.Response('other', 200)),
    );
    expect(
      () => bad.download(parsed, File('${dir.path}/b.zip')),
      throwsA(isA<DevOtaException>()),
    );
  });

  test('reports a rejected token', () async {
    final client = DevOtaClient(
      'http://x',
      't',
      client: MockClient((_) async => http.Response('', 401)),
    );
    expect(client.latest(), throwsA(isA<DevOtaException>()));
  });
}
