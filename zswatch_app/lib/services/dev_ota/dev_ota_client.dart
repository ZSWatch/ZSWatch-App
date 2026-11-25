import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A firmware build published by `scripts/dev_ota/dev_ota.py`.
@immutable
class DevOtaBuild {
  final String id;
  final String sha256;
  final int size;
  final String note;
  final String branch;
  final String commit;
  final DateTime? created;

  const DevOtaBuild({
    required this.id,
    required this.sha256,
    required this.size,
    this.note = '',
    this.branch = '',
    this.commit = '',
    this.created,
  });

  static DevOtaBuild? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final sha = json['sha256'];
    final size = json['size'];
    if (id is! String || sha is! String || size is! int) return null;
    return DevOtaBuild(
      id: id,
      sha256: sha,
      size: size,
      note: json['note'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      commit: json['commit'] as String? ?? '',
      created: DateTime.tryParse(json['created'] as String? ?? ''),
    );
  }

  String get shortCommit => commit.length > 8 ? commit.substring(0, 8) : commit;
}

class DevOtaException implements Exception {
  final String message;
  const DevOtaException(this.message);
  @override
  String toString() => message;
}

/// HTTP client for the dev OTA server. [baseUrl] may include a path prefix,
/// e.g. `https://mac.tailnet.ts.net/zswatch-ota`.
class DevOtaClient {
  final Uri baseUrl;
  final String token;
  final http.Client _http;

  DevOtaClient(String baseUrl, this.token, {http.Client? client})
    : baseUrl = Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '')),
      _http = client ?? http.Client();

  Map<String, String> get _headers => {'Authorization': 'Bearer $token'};

  Uri _api(String path, [Map<String, String>? query]) => baseUrl.replace(
    path: '${baseUrl.path}/api/$path',
    queryParameters: query,
  );

  /// Returns the latest build. With [wait], the server holds the request
  /// until a build other than [after] exists or the wait runs out.
  Future<DevOtaBuild?> latest({String? after, Duration? wait}) async {
    final response = await _http
        .get(
          _api('latest', {
            if (after != null) 'after': after,
            if (wait != null) 'wait': '${wait.inSeconds}',
          }),
          headers: _headers,
        )
        .timeout((wait ?? Duration.zero) + const Duration(seconds: 15));
    _check(response);
    final body = jsonDecode(response.body);
    return body is Map ? DevOtaBuild.fromJson(body['build']) : null;
  }

  /// Downloads [build] to [target] and verifies its SHA-256.
  Future<File> download(DevOtaBuild build, File target) async {
    final response = await _http
        .get(_api('builds/${build.id}.zip'), headers: _headers)
        .timeout(const Duration(minutes: 3));
    _check(response);
    final digest = sha256.convert(response.bodyBytes).toString();
    if (digest != build.sha256) {
      throw const DevOtaException('Downloaded firmware hash does not match');
    }
    await target.writeAsBytes(response.bodyBytes, flush: true);
    return target;
  }

  Future<void> report(String buildId, String state, {String? detail}) async {
    final response = await _http
        .post(
          _api('status'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': buildId,
            'state': state,
            if (detail != null && detail.isNotEmpty) 'detail': detail,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _check(response);
  }

  void _check(http.Response response) {
    if (response.statusCode == 401) {
      throw const DevOtaException('Dev server rejected the token');
    }
    if (response.statusCode != 200) {
      throw DevOtaException('Dev server returned ${response.statusCode}');
    }
  }

  void close() => _http.close();
}
