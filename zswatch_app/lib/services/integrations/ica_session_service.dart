import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Unofficial ICA mobile email-code sign-in. ICA has no public consumer list
/// API. The session goes to the native companion, which stores it and runs
/// every list call; nothing is persisted here.
class IcaSessionService {
  IcaSessionService({HttpClient? client}) : _http = client ?? HttpClient();

  static const _ims = 'https://ims.icagruppen.se';
  static const _redirect = 'icacurity://app';
  static const _bootstrapId = 'ica-app-dcr-registration';
  static const _bootstrapSecret =
      'uxLHTBvZ-Z2fV-SbrHl1E-tz7vB3jQFrwAdSLlbVMMu1rxDdvJU0s8KGu9d1wLS4';
  final HttpClient _http;
  final Map<String, Cookie> _cookies = {};
  Map<String, dynamic>? _clientRegistration;
  String? _verifier;
  String? _state;
  String? _emailStep;

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
    final emailPage = await _followImsResponse(
      await _request('GET', '$_ims/authn/authenticate/icase-email'),
      Uri.parse('$_ims/authn/authenticate/icase-email'),
    );
    _check(emailPage);
    final codePage = await _followImsResponse(
      await _request(
        'POST',
        '$_ims/authn/authenticate/icase-email',
        form: {'userName': email.trim()},
      ),
      Uri.parse('$_ims/authn/authenticate/icase-email'),
    );
    _check(codePage);
    if (!codePage.body.contains('name="otp"')) {
      throw StateError('ICA did not present an email code form');
    }
    _emailStep = '$_ims/authn/authenticate/icase-email/enter-otp';
  }

  /// The OAuth session for [CompanionPrototypeClient.setIcaSession].
  Future<Map<String, Object?>> finishEmailLogin(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code) ||
        _emailStep == null ||
        _clientRegistration == null ||
        _state == null ||
        _verifier == null) {
      throw StateError('Start ICA email login and enter its six-digit code');
    }
    final codeResponse = await _request(
      'POST',
      _emailStep!,
      form: {'otp': code},
    );
    if (codeResponse.status == 400) {
      throw StateError(
        'ICA rejected this code or it expired. Send a new code.',
      );
    }
    final authenticated = await _followImsResponse(
      codeResponse,
      Uri.parse(_emailStep!),
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
    final session = <String, Object?>{
      'client_id': _clientRegistration!['client_id'],
      'client_secret': _clientRegistration!['client_secret'],
      'access_token': value['access_token'],
      'refresh_token': value['refresh_token'],
      'expires_in': value['expires_in'],
    };
    _verifier = null;
    _state = null;
    _emailStep = null;
    _cookies.clear();
    return session;
  }

  Future<void> _followIms(String location) async {
    await _followImsResponse(_Reply(302, '', location), Uri.parse(_ims));
  }

  Future<_Reply> _followImsResponse(_Reply initial, Uri base) async {
    var response = initial;
    var url = base;
    for (var i = 0; i < 5; i++) {
      final location = response.location;
      if (location == null) {
        _check(response);
        return response;
      }
      url = url.resolve(location);
      if (url.host != 'ims.icagruppen.se') {
        throw StateError('Unexpected ICA redirect');
      }
      response = await _request('GET', url.toString());
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
    if (uri.scheme != 'https' || uri.host != 'ims.icagruppen.se') {
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
