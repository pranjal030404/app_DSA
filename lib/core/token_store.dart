import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistence for the session secrets.
///
/// Mirrors the web client: an access token in local storage and the refresh
/// token as a cookie. On mobile there is no cookie jar, so we capture the
/// `refreshToken` Set-Cookie from the login response and replay it on
/// /auth/refresh (HttpOnly only restricts browsers, not native apps).
class TokenStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshCookie';
  static const _kTheme = 'themeMode';
  static const _kWebThemes = 'webThemesCache';

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<void> writeAccess(String token) => _storage.write(key: _kAccess, value: token);

  /// Raw `refreshToken=...` cookie pair (no domain/path attributes).
  Future<String?> readRefreshCookie() => _storage.read(key: _kRefresh);
  Future<void> writeRefreshCookie(String cookiePair) =>
      _storage.write(key: _kRefresh, value: cookiePair);

  Future<void> clearSession() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  Future<String?> readThemeMode() => _storage.read(key: _kTheme);
  Future<void> writeThemeMode(String mode) => _storage.write(key: _kTheme, value: mode);

  /// Last `themes` array fetched from the server, as raw JSON.
  Future<String?> readWebThemesCache() => _storage.read(key: _kWebThemes);
  Future<void> writeWebThemesCache(String json) => _storage.write(key: _kWebThemes, value: json);
}
