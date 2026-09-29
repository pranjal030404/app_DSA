import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../core/token_store.dart';
import '../core/web_theme_presets.dart';
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

  Future<void> register(
    String username,
    String email,
    String password, {
    String? otp,
    String? firebaseIdToken,
  }) async {
    user = await _auth.register(
      username,
      email,
      password,
      otp: otp,
      firebaseIdToken: firebaseIdToken,
    );
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

/// The selected theme, persisted.
///
/// Choices: "system" (the app's Aurora design, following the phone's
/// light/dark setting), Aurora Light / Aurora Dark, or any theme the website
/// offers. The website list comes from GET /platform-settings/public, so
/// themes an admin adds there appear in the app too.
class ThemeController extends ChangeNotifier {
  ThemeController(this._tokens, this._api) {
    _load();
  }

  static const systemId = 'system';

  final TokenStore _tokens;
  final ApiClient _api;

  String selectedId = systemId;
  List<ThemeSpec> webThemes = _parseThemes(kBundledWebThemesJson);
  final Map<String, ThemeData> _built = {};

  static const appThemes = [ThemeSpec.auroraLight, ThemeSpec.auroraDark];

  /// The fixed theme in use, or null when following the system.
  ThemeSpec? get selected {
    for (final t in [...appThemes, ...webThemes]) {
      if (t.id == selectedId) return t;
    }
    return null;
  }

  String get selectedName => selected?.name ?? 'System (Aurora)';

  ThemeMode get mode {
    final spec = selected;
    if (spec == null) return ThemeMode.system;
    return spec.dark ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeData get lightTheme => themeFor(selected ?? ThemeSpec.auroraLight);
  ThemeData get darkTheme => themeFor(selected ?? ThemeSpec.auroraDark);

  ThemeData themeFor(ThemeSpec spec) => _built.putIfAbsent(spec.id, () => buildAppTheme(spec));

  Future<void> _load() async {
    final saved = await _tokens.readThemeMode();
    // Older builds stored a plain ThemeMode name.
    selectedId = switch (saved) {
      null || '' || 'system' => systemId,
      'light' => ThemeSpec.auroraLight.id,
      'dark' => ThemeSpec.auroraDark.id,
      _ => saved,
    };
    final cached = await _tokens.readWebThemesCache();
    if (cached != null) _setWebThemes(_parseThemes(cached));
    notifyListeners();
    await refreshWebThemes();
  }

  /// Pulls the latest website themes; keeps the current list on failure.
  Future<void> refreshWebThemes() async {
    try {
      final decoded = await _api.get('/platform-settings/public');
      final data = _api.unwrap(decoded);
      final raw = data is Map ? data['themes'] : null;
      if (raw is! List) return;
      final json = jsonEncode(raw);
      final parsed = _parseThemes(json);
      if (parsed.isEmpty) return;
      _setWebThemes(parsed);
      await _tokens.writeWebThemesCache(json);
      notifyListeners();
    } catch (_) {
      // Offline — the cached or bundled list stays in place.
    }
  }

  Future<void> select(String id) async {
    selectedId = id;
    await _tokens.writeThemeMode(id);
    notifyListeners();
  }

  void _setWebThemes(List<ThemeSpec> themes) {
    webThemes = themes;
    _built.removeWhere((id, _) => !appThemes.any((t) => t.id == id));
    // A theme the admin deleted falls back to following the system.
    if (selected == null && selectedId != systemId) selectedId = systemId;
  }

  static List<ThemeSpec> _parseThemes(String json) {
    try {
      final list = jsonDecode(json);
      if (list is! List) return const [];
      return [
        for (final t in list)
          if (t is Map) ThemeSpec.fromWebTheme(Map<String, dynamic>.from(t)),
      ].whereType<ThemeSpec>().toList();
    } catch (_) {
      return const [];
    }
  }
}
