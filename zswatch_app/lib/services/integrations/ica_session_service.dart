import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Unofficial ICA mobile OAuth flow. ICA has no public consumer list API.
/// Only the token and registered client are persisted; the email code is not.
class IcaSessionService {
  IcaSessionService({FlutterSecureStorage? storage, HttpClient? client})
    : _storage = storage ?? const FlutterSecureStorage(),
      _http = client ?? HttpClient();

  static const _ims = 'https://ims.icagruppen.se';
  static const _stateKey = 'ica_mobile_oauth_v1';
  static const _preferredListKey = 'ica_preferred_list_v1';
  static const _redirect = 'icacurity://app';
  static const _bootstrapId = 'ica-app-dcr-registration';
  static const _bootstrapSecret =
      'uxLHTBvZ-Z2fV-SbrHl1E-tz7vB3jQFrwAdSLlbVMMu1rxDdvJU0s8KGu9d1wLS4';
  final FlutterSecureStorage _storage;
  final HttpClient _http;
  final Map<String, Cookie> _cookies = {};
  Map<String, dynamic>? _saved;
  Map<String, dynamic>? _clientRegistration;
  String? _verifier;
  String? _state;
  String? _emailStep;
  Future<void>? _refreshing;

  Future<bool> get hasSession async {
    await _load();
    return _saved?['refresh_token'] is String;
  }

  Future<String?> get preferredListId => _storage.read(key: _preferredListKey);

  Future<void> setPreferredListId(String? id) async {
    if (id == null) {
      await _storage.delete(key: _preferredListKey);
    } else {
      await _storage.write(key: _preferredListKey, value: id);
    }
  }

  Future<void> _load() async {
    if (_saved != null) return;
    final raw = await _storage.read(key: _stateKey);
    if (raw != null) {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) _saved = value;
    }
  }

  Future<void> startEmailLogin(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw const FormatException('Enter your ICA account email');
    }
    _cookies.clear();
    final bootstrap = await _request(
      'POST',
      '$_ims/oauth/v2/token',
      form: {
        'client_id': _bootstrapId,
        'client_secret': _bootstrapSecret,
        'grant_type': 'client_credentials',
        'scope': 'dcr',
        'response_type': 'token',
      },
    );
    _check(bootstrap);
    final registration = await _request(
      'POST',
      '$_ims/register',
      json: {'software_id': 'dcr-ica-app-template'},
      bearer: (jsonDecode(bootstrap.body) as Map)['access_token'] as String,
    );
    _check(registration);
    _clientRegistration = jsonDecode(registration.body) as Map<String, dynamic>;
    final random = _randomUrlSafe(40);
    _verifier = random;
    final digest = sha256.convert(utf8.encode(random)).bytes;
    final challenge = base64Url.encode(digest).replaceAll('=', '');
    final authorize = await _request(
      'GET',
      '$_ims/oauth/v2/authorize',
      query: {
        'client_id': _clientRegistration!['client_id'] as String,
        'scope': _clientRegistration!['scope'] as String,
        'redirect_uri': _redirect,
        'response_type': 'code',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'prompt': 'login',
      },
    );
    if (authorize.status != 302 || authorize.location == null) {
      throw StateError('ICA did not start email login');
    }
    _state = Uri.parse(authorize.location!).queryParameters['state'];
    await _followIms(authorize.location!);
    final emailPage = await _request(
      'GET',
      '$_ims/authn/authenticate/icase-email',
    );
    _check(emailPage);
    final codePage = await _request(
      'POST',
      '$_ims/authn/authenticate/icase-email',
      form: {'userName': email.trim()},
    );
    _check(codePage);
    if (!codePage.body.contains('name="otp"')) {
      throw StateError('ICA did not present an email code form');
    }
    _emailStep = '$_ims/authn/authenticate/icase-email/enter-otp';
  }

  Future<void> finishEmailLogin(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code) ||
        _emailStep == null ||
        _clientRegistration == null ||
        _state == null ||
        _verifier == null) {
      throw StateError('Start ICA email login and enter its six-digit code');
    }
    final authenticated = await _request(
      'POST',
      _emailStep!,
      form: {'otp': code},
    );
    _check(authenticated);
    final token = RegExp(
      r'<input[^>]*name="token"[^>]*value="([^"]+)"',
    ).firstMatch(authenticated.body)?.group(1);
    if (token == null) throw StateError('ICA did not accept the email code');
    final authorize = await _request(
      'POST',
      '$_ims/oauth/v2/authorize',
      query: {
        'client_id': _clientRegistration!['client_id'] as String,
        'forceAuthN': 'true',
      },
      form: {'token': token, 'state': _state!},
    );
    if (authorize.status != 303 || authorize.location == null) {
      throw StateError('ICA did not authorize this session');
    }
    final authorizationCode = Uri.parse(
      authorize.location!,
    ).queryParameters['code'];
    if (authorizationCode == null) {
      throw StateError('No ICA authorization code');
    }
    final response = await _request(
      'POST',
      '$_ims/oauth/v2/token',
      form: {
        'code': authorizationCode,
        'client_id': _clientRegistration!['client_id'] as String,
        'client_secret': _clientRegistration!['client_secret'] as String,
        'grant_type': 'authorization_code',
        'scope': _clientRegistration!['scope'] as String,
        'response_type': 'token',
        'code_verifier': _verifier!,
        'redirect_uri': _redirect,
      },
    );
    _check(response);
    final value = jsonDecode(response.body) as Map<String, dynamic>;
    _saved = {
      'client_id': _clientRegistration!['client_id'],
      'client_secret': _clientRegistration!['client_secret'],
      ...value,
      'expires_at': DateTime.now()
          .add(Duration(seconds: value['expires_in'] as int))
          .millisecondsSinceEpoch,
    };
    await _persist();
    _verifier = null;
    _state = null;
    _emailStep = null;
    _cookies.clear();
  }

  Future<String> accessToken() async {
    await _load();
    final saved = _saved;
    if (saved == null || saved['refresh_token'] is! String) {
      throw StateError('Connect your ICA account first');
    }
    final expiry = saved['expires_at'];
    if (saved['access_token'] is String &&
        expiry is int &&
        expiry >
            DateTime.now()
                .add(const Duration(minutes: 1))
                .millisecondsSinceEpoch) {
      return saved['access_token'] as String;
    }
    _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
    await _refreshing;
    return _saved!['access_token'] as String;
  }

  Future<void> _refresh() async {
    final current = _saved!;
    final basic = base64Encode(
      utf8.encode('${current['client_id']}:${current['client_secret']}'),
    );
    final response = await _request(
      'POST',
      '$_ims/oauth/v2/token',
      form: {
        'grant_type': 'refresh_token',
        'refresh_token': current['refresh_token'] as String,
      },
      authorization: 'Basic $basic',
    );
    _check(response);
    final value = jsonDecode(response.body) as Map<String, dynamic>;
    _saved = {
      ...current,
      ...value,
      'expires_at': DateTime.now()
          .add(Duration(seconds: value['expires_in'] as int))
          .millisecondsSinceEpoch,
    };
    await _persist();
  }

  Future<void> _persist() async =>
      _storage.write(key: _stateKey, value: jsonEncode(_saved));

  Future<void> disconnect() async {
    _saved = null;
    await _storage.delete(key: _stateKey);
    await _storage.delete(key: _preferredListKey);
  }

  Future<void> _followIms(String location) async {
    var url = Uri.parse(location);
    for (var i = 0; i < 5; i++) {
      if (url.host != 'ims.icagruppen.se') {
        throw StateError('Unexpected ICA redirect');
      }
      final response = await _request('GET', url.toString());
      if (response.location == null) {
        _check(response);
        return;
      }
      url = url.resolve(response.location!);
    }
    throw StateError('Too many ICA redirects');
  }

  Future<_Reply> _request(
    String method,
    String url, {
    Map<String, String>? query,
    Map<String, String>? form,
    Map<String, Object?>? json,
    String? bearer,
    String? authorization,
  }) async {
    final parsed = Uri.parse(url);
    final uri = query == null ? parsed : parsed.replace(queryParameters: query);
    if (uri.host != 'ims.icagruppen.se') {
      throw StateError('Unexpected ICA host');
    }
    final request = await _http
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 25));
    request.followRedirects = false;
    if (_cookies.isNotEmpty) request.cookies.addAll(_cookies.values);
    if (bearer != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
    }
    if (authorization != null) {
      request.headers.set(HttpHeaders.authorizationHeader, authorization);
    }
    if (form != null) {
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(Uri(queryParameters: form).query);
    }
    if (json != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(json));
    }
    final response = await request.close().timeout(const Duration(seconds: 25));
    for (final cookie in response.cookies) {
      _cookies[cookie.name] = cookie;
    }
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 25));
    return _Reply(
      response.statusCode,
      body,
      response.headers.value(HttpHeaders.locationHeader),
    );
  }

  static void _check(_Reply response) {
    if (response.status < 200 || response.status >= 300) {
      throw StateError('ICA authentication returned HTTP ${response.status}');
    }
  }

  static String _randomUrlSafe(int bytes) => base64Url
      .encode(List<int>.generate(bytes, (_) => _secureRandom.nextInt(256)))
      .replaceAll('=', '');

  static final _secureRandom = Random.secure();

  void close() => _http.close(force: true);
}

class _Reply {
  const _Reply(this.status, this.body, this.location);
  final int status;
  final String body;
  final String? location;
}
