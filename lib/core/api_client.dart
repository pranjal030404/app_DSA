import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'token_store.dart';

/// A failed API call, carrying the server's message when there is one.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Minimal REST client for the DSA Mentor backend.
///
/// • Attaches the stored access token as a Bearer header.
/// • On a 401 (or an expired-token 403), replays the stored refresh cookie
///   against /auth/refresh once, then retries the original call.
/// • Unwraps the backend envelope `{ success, message, data }` and throws
///   [ApiException] with the server's message on failure.
class ApiClient {
  ApiClient(this._tokens);

  final TokenStore _tokens;
  final http.Client _http = http.Client();

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _tokens.readAccess();
    return {
      // Lets the backend skip the web-only reCAPTCHA check at signup.
      'X-Client-App': 'dsa-mentor-android',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$kApiBaseUrl$path').replace(queryParameters: query);
    return _send(() async => _http.get(uri, headers: await _headers(json: false)));
  }

  dynamic post(String path, {Object? body, String? cookie}) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final headers = await _headers();
    if (cookie != null) headers['Cookie'] = cookie;
    return _send(
      () => _http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body)),
      captureCookie: true,
    );
  }

  dynamic delete(String path, {Object? body}) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    return _send(
      () async => _http.delete(
        uri,
        headers: await _headers(json: false),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  dynamic put(String path, {Object? body}) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    return _send(
      () async => _http.put(
        uri,
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  /// Multipart upload — `field` is the form field name the backend's multer
  /// middleware expects (e.g. "resume"), `filename` is only used for the
  /// content-disposition header, not read from disk.
  dynamic uploadFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    return _send(() async {
      final request = http.MultipartRequest('POST', uri);
      final headers = await _headers(json: false);
      request.headers.addAll(headers);
      request.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
  }

  dynamic _send(
    Future<http.Response> Function() request, {
    bool captureCookie = false,
    bool retried = false,
  }) async {
    http.Response response;
    try {
      response = await request().timeout(kHttpTimeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } on SocketException {
      throw ApiException('No connection to the server. Check that the backend is running.');
    } catch (_) {
      throw ApiException('Something went wrong. Please try again.');
    }

    if (captureCookie) await _maybeStoreRefreshCookie(response.headers);

    // Session expired → refresh once, then replay the original request.
    if (!retried && _isTokenFailure(response) && !captureCookie) {
      final refreshed = await refreshSession();
      if (refreshed) return _send(request, captureCookie: captureCookie, retried: true);
    }

    dynamic decoded;
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('json')) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {/* fall through with null */}
    }

    if (response.statusCode >= 400) {
      final message = (decoded is Map)
          ? (decoded['message'] ?? decoded['error'] ?? 'Request failed (${response.statusCode})')
          : 'Request failed (${response.statusCode})';
      throw ApiException(message.toString(), statusCode: response.statusCode);
    }
    return decoded;
  }

  bool _isTokenFailure(http.Response r) {
    if (r.statusCode == 401) return true;
    if (r.statusCode != 403) return false;
    final body = r.body.toLowerCase();
    return body.contains('expired') || body.contains('invalid token') || body.contains('refresh');
  }

  Future<void> _maybeStoreRefreshCookie(Map<String, String> headers) async {
    final setCookie = headers['set-cookie'];
    if (setCookie == null) return;
    final match = RegExp(r'refreshToken=([^;]+)').firstMatch(setCookie);
    if (match != null) {
      await _tokens.writeRefreshCookie('refreshToken=${match.group(1)}');
    }
  }

  /// Exchanges the stored refresh cookie for a new access token.
  /// Returns true when the session was successfully renewed.
  Future<bool> refreshSession() async {
    final refreshCookie = await _tokens.readRefreshCookie();
    final access = await _tokens.readAccess();
    if (refreshCookie == null || refreshCookie.isEmpty) return false;

    try {
      final response = await _http
          .post(Uri.parse('$kApiBaseUrl/auth/refresh'), headers: {
        if (access != null && access.isNotEmpty) 'Authorization': 'Bearer $access',
        'Cookie': refreshCookie,
      }).timeout(kHttpTimeout);

      await _maybeStoreRefreshCookie(response.headers);
      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final newToken = _extractToken(decoded);
      if (newToken == null || newToken.isEmpty) return false;
      await _tokens.writeAccess(newToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// POST /auth/login. On success persists the session and returns the
  /// server's `data` map (user + accessToken).
  Future<Map<String, dynamic>> login(String email, String password) async {
    final decoded = await post('/auth/login', body: {'email': email, 'password': password});
    final data = _unwrap(decoded);
    final token = _extractToken(decoded);
    if (token == null || token.isEmpty) {
      throw ApiException('Login succeeded but no session token was returned.');
    }
    await _tokens.writeAccess(token);
    return data;
  }

  /// POST /auth/register. Same envelope as login (user + accessToken, plus
  /// the refresh cookie), so the new account is signed in straight away.
  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password, {
    String? otp,
    String? firebaseIdToken,
  }) async {
    final decoded = await post('/auth/register', body: {
      'username': username,
      'email': email,
      'password': password,
      if (otp != null && otp.isNotEmpty) 'otp': otp,
      if (firebaseIdToken != null) 'firebaseIdToken': firebaseIdToken,
    });
    final data = _unwrap(decoded);
    final token = _extractToken(decoded);
    if (token == null || token.isEmpty) {
      throw ApiException('Account created, but no session token was returned. Please sign in.');
    }
    await _tokens.writeAccess(token);
    return data;
  }

  /// POST /auth/logout (best effort) and wipe local secrets.
  Future<void> logout() async {
    try {
      await post('/auth/logout');
    } catch (_) {/* session is being discarded anyway */}
    await _tokens.clearSession();
  }

  /// Envelope helpers ---------------------------------------------------------

  /// Unwraps `{ success, data }` and throws on `success: false`.
  dynamic _unwrap(dynamic decoded) {
    if (decoded is Map) {
      final ok = decoded['success'];
      if (ok == false) {
        throw ApiException((decoded['message'] ?? 'Request failed').toString());
      }
      return decoded['data'];
    }
    return decoded;
  }

  /// Wraps an already-fetched payload: unwraps `data` when present, then
  /// surfaces `success: false` envelopes that were returned with a 2xx.
  dynamic unwrap(dynamic decoded) => _unwrap(decoded);

  String? _extractToken(dynamic decoded) {
    if (decoded is! Map) return null;
    final data = decoded['data'];
    if (data is Map) {
      final t = data['accessToken'] ?? data['token'];
      if (t is String && t.isNotEmpty) return t;
    }
    final top = decoded['accessToken'] ?? decoded['token'];
    return top is String && top.isNotEmpty ? top : null;
  }

  void dispose() => _http.close();
}
