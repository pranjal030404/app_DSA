import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/token_store.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Shared tab index for the bottom navigation shell, so any screen can jump
/// to another tab (Home's "Continue practicing" → Problems).
final ValueNotifier<int> shellTab = ValueNotifier<int>(0);

/// Session state: bootstrap on cold start, login, logout.
class AuthController extends ChangeNotifier {
  AuthController(this._api, TokenStore tokens)
      : _tokens = tokens,
        _auth = AuthService(_api),
        _problems = ProblemService(_api);

  final ApiClient _api;
  final TokenStore _tokens;
  final AuthService _auth;
  final ProblemService _problems;

  User? user;
  bool booted = false;

  AuthService get auth => _auth;
  ProblemService get problems => _problems;

  /// Called once at startup: restore the session if a token exists.
  Future<void> bootstrap() async {
    final token = await _tokens.readAccess();
    if (token != null && token.isNotEmpty) {
      try {
        user = await _auth.profile();
      } on ApiException catch (e) {
        // One quiet refresh attempt, then decide.
        if (await _api.refreshSession()) {
          try {
            user = await _auth.profile();
          } catch (_) {
            user = null;
          }
        } else if (e.statusCode == null || e.statusCode! < 500) {
          // A definitive auth failure clears the session; a backend outage
          // (5xx / timeout) keeps the stored token for a later retry.
          user = null;
        }
      } catch (_) {
        user = null;
      }
    }
    booted = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    user = await _auth.login(email, password);
    notifyListeners();
  }

  /// Re-fetches the profile after a Settings-screen edit so the rest of the
  /// app (home stats, Collabs reputation gate, etc.) sees the fresh values.
  Future<void> refreshProfile() async {
    user = await _auth.profile();
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.logout();
    user = null;
    notifyListeners();
  }
}

/// Light / dark / system selection, persisted.
class ThemeController extends ChangeNotifier {
  ThemeController(this._tokens) {
    _load();
  }

  final TokenStore _tokens;
  ThemeMode mode = ThemeMode.system;

  Future<void> _load() async {
    final saved = await _tokens.readThemeMode();
    if (saved == 'light') mode = ThemeMode.light;
    if (saved == 'dark') mode = ThemeMode.dark;
    if (saved == 'system') mode = ThemeMode.system;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    mode = value;
    await _tokens.writeThemeMode(value.name);
    notifyListeners();
  }
}
