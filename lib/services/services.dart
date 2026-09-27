import '../core/api_client.dart';
import '../models/models.dart';

class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  /// POST /auth/login → persists tokens, returns the user.
  Future<User> login(String email, String password) async {
    final data = await _api.login(email.trim(), password);
    return _parseUser(data);
  }

  /// GET /auth/profile — used on cold start to restore the session.
  Future<User> profile() async {
    final decoded = await _api.get('/auth/profile');
    return _parseUser(_api.unwrap(decoded));
  }

  /// PUT /auth/profile — the fields the web Settings page edits. Only
  /// non-null arguments are sent, so a screen can update just one section.
  Future<User> updateProfile({
    String? username,
    String? email,
    String? bio,
    String? phone,
    String? github,
    String? linkedin,
    List<String>? skills,
    String? experience,
    String? education,
  }) async {
    final decoded = await _api.put('/auth/profile', body: {
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (bio != null) 'bio': bio,
      if (phone != null) 'phone': phone,
      if (github != null) 'github': github,
      if (linkedin != null) 'linkedin': linkedin,
      if (skills != null) 'skills': skills,
      if (experience != null) 'experience': experience,
      if (education != null) 'education': education,
    });
    // The backend replies `{ success, message, user }` for this endpoint —
    // no `data` wrapper — so parse the raw envelope rather than `unwrap()`.
    return _parseUser(decoded);
  }

  /// POST /auth/profile/resume — multipart PDF upload (max 5MB, backend-enforced).
  Future<void> uploadResume(List<int> bytes, String filename) async {
    await _api.uploadFile('/auth/profile/resume', field: 'resume', bytes: bytes, filename: filename);
  }

  /// DELETE /auth/profile/resume
  Future<void> deleteResume() async {
    await _api.delete('/auth/profile/resume');
  }

  /// POST /auth/forgot-password { email } — emails a one-time code (or
  /// returns it directly as `devCode` when no mail transport is configured).
  Future<String?> requestPasswordCode(String email) async {
    // Flat envelope — { success, message, devCode? } — no `data` wrapper.
    final decoded = await _api.post('/auth/forgot-password', body: {'email': email});
    if (decoded is Map) {
      final code = decoded['devCode'];
      if (code != null) return code.toString();
    }
    return null;
  }

  /// POST /auth/reset-password { email, code, password }
  Future<void> resetPassword(String email, String code, String newPassword) async {
    await _api.post('/auth/reset-password', body: {
      'email': email,
      'code': code,
      'password': newPassword,
    });
  }

  User _parseUser(dynamic data) {
    if (data is Map) {
      final u = data['user'] is Map ? data['user'] : data;
      if (u is Map && (u['id'] != null || u['_id'] != null || u['email'] != null)) {
        return User.fromMap(Map<String, dynamic>.from(u));
      }
    }
    throw ApiException('Could not read the account details.');
  }
}

class ProblemService {
  ProblemService(this._api);
  final ApiClient _api;

  /// GET /problems/public/stats — works without an account.
  Future<ProblemStats> publicStats() async {
    final decoded = await _api.get('/problems/public/stats');
    final data = _api.unwrap(decoded);
    if (data is Map) return ProblemStats.fromMap(Map<String, dynamic>.from(data));
    return ProblemStats();
  }

  /// GET /problems (auth) with a fallback to the public list so the
  /// catalogue still renders for anonymous browsing.
  Future<List<ProblemSummary>> list({int limit = 100}) async {
    List<dynamic> rows;
    try {
      final decoded = await _api.get('/problems', query: {'limit': '$limit', 'sort': 'title'});
      final data = _api.unwrap(decoded);
      rows = _rowsFrom(data);
    } on ApiException catch (e) {
      if (!e.isAuthError) rethrow;
      // Token missing/expired and refresh unavailable → public catalogue.
      final decoded = await _api.get('/problems/public', query: {'limit': '$limit'});
      rows = _rowsFrom(_api.unwrap(decoded));
    }
    return rows
        .whereType<Map>()
        .map((m) => ProblemSummary.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<dynamic> _rowsFrom(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final p = data['problems'] ?? data['items'] ?? data['rows'];
      if (p is List) return p;
    }
    return const [];
  }

  /// GET /problems/:slug (auth).
  Future<ProblemDetail> bySlug(String slug) async {
    final decoded = await _api.get('/problems/$slug');
    final data = _api.unwrap(decoded);
    final m = data is Map
        ? (data['problem'] is Map ? data['problem'] : data)
        : null;
    if (m is! Map) throw ApiException('Problem not found.');
    return ProblemDetail.fromMap(Map<String, dynamic>.from(m));
  }

  /// POST /problems/:slug/run — execute against the sample tests.
  Future<RunResult> run(String slug, String code, String language) async {
    final decoded = await _api.post('/problems/$slug/run', body: {'code': code, 'language': language});
    if (decoded is Map) return RunResult.fromMap(Map<String, dynamic>.from(decoded));
    throw ApiException('Unexpected response from the runner.');
  }

  /// POST /problems/:slug/submit — judged against hidden tests.
  Future<RunResult> submit(String slug, String code, String language) async {
    final decoded = await _api.post('/problems/$slug/submit', body: {'code': code, 'language': language});
    if (decoded is Map) return RunResult.fromMap(Map<String, dynamic>.from(decoded));
    throw ApiException('Unexpected response from the judge.');
  }
}
