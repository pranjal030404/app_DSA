import 'dart:convert';

import '../core/api_client.dart';
import '../models/content.dart';

/// Shared list-coercion helper: the backend returns bare arrays in `data`
/// for some endpoints and `{ items: [...] }` wrappers for others.
List<Map<String, dynamic>> _rows(dynamic data, [List<String> keys = const ['items', 'rows', 'results', 'tickets', 'resources', 'categories', 'articles', 'roadmaps', 'history', 'achievements', 'problems']]) {
  if (data is List) return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  if (data is Map) {
    for (final k in keys) {
      final v = data[k];
      if (v is List) return v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
  }
  return const [];
}

/* ------------------------------------------------------------------ AI mentor */

class MentorService {
  MentorService(this._api);
  final ApiClient _api;

  /// POST /chatbot/chat { message } → the mentor's reply text.
  Future<String> send(String message, {String? sessionId}) async {
    final decoded = await _api.post('/chatbot/chat', body: {
      'message': message,
      if (sessionId != null) 'sessionId': sessionId,
    });
    final data = _api.unwrap(decoded);
    if (data is Map) {
      for (final k in ['reply', 'response', 'answer', 'content', 'message', 'text']) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      if (data['data'] is Map) {
        final inner = data['data'] as Map;
        for (final k in ['reply', 'response', 'answer', 'content', 'message']) {
          final v = inner[k];
          if (v is String && v.trim().isNotEmpty) return v;
        }
      }
    }
    if (data is String && data.trim().isNotEmpty) return data;
    throw ApiException('The mentor did not return an answer. Try again.');
  }
}

/* ------------------------------------------------------------------ Playground */

class PlaygroundService {
  PlaygroundService(this._api);
  final ApiClient _api;

  static const fallbackLanguages = ['javascript', 'python', 'java', 'cpp'];

  /// GET /playground/languages — falls back to the known set.
  Future<List<String>> languages() async {
    try {
      final decoded = await _api.get('/playground/languages');
      final data = _api.unwrap(decoded);
      final List raw = data is List
          ? data
          : (data is Map && data['languages'] is List ? data['languages'] as List : const []);
      final langs = raw
          .map((l) => l is Map ? (l['id'] ?? l['name'] ?? l['language'])?.toString() : l.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      return langs.isEmpty ? fallbackLanguages : langs;
    } on ApiException {
      return fallbackLanguages;
    }
  }

  /// POST /playground/run { code, language, stdin }.
  Future<PlaygroundRun> run(String code, String language, String stdin) async {
    final decoded = await _api.post('/playground/run', body: {
      'code': code,
      'language': language,
      'stdin': stdin,
    });
    final data = _api.unwrap(decoded);
    if (data is Map) return PlaygroundRun.fromMap(Map<String, dynamic>.from(data));
    throw ApiException('Unexpected response from the runner.');
  }

  /// POST /playground/explain { code, language } — the AI walkthrough.
  Future<String> explain(String code, String language) async {
    final decoded = await _api.post('/playground/explain', body: {'code': code, 'language': language});
    final data = _api.unwrap(decoded);
    if (data is Map) {
      for (final k in ['explanation', 'reply', 'response', 'content', 'message']) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
    }
    if (data is String && data.trim().isNotEmpty) return data;
    throw ApiException('No explanation was returned.');
  }
}

/* ------------------------------------------------------------------ Interviews */

class InterviewService {
  InterviewService(this._api);
  final ApiClient _api;

  /// POST /interview/create → sessionId
  Future<String> create({
    required String interviewType,
    required String difficulty,
    int durationMinutes = 30,
    int questionCount = 2,
    List<String> topics = const [],
  }) async {
    final decoded = await _api.post('/interview/create', body: {
      'interviewType': interviewType,
      'difficulty': difficulty,
      'duration': durationMinutes,
      'questionCount': questionCount,
      'topics': topics,
    });
    final data = _api.unwrap(decoded);
    if (data is Map) {
      final id = data['sessionId'] ?? data['_id'] ?? data['id'];
      if (id != null) return id.toString();
    }
    throw ApiException('Could not start the interview.');
  }

  /// GET /interview/session/:id
  Future<InterviewSession> session(String sessionId) async {
    final decoded = await _api.get('/interview/session/$sessionId');
    final data = _api.unwrap(decoded);
    if (data is Map) return InterviewSession.fromMap(Map<String, dynamic>.from(data));
    throw ApiException('Interview session not found.');
  }

  /// POST /interview/session/:id/message { message } → interviewer reply.
  Future<String> sendMessage(String sessionId, String message, {String? code}) async {
    final decoded = await _api.post('/interview/session/$sessionId/message', body: {
      'message': message,
      if (code != null) 'code': code,
    });
    final data = _api.unwrap(decoded);
    if (data is Map) {
      final v = data['response'] ?? data['reply'] ?? data['message'];
      if (v != null) return v.toString();
    }
    if (data is String) return data;
    throw ApiException('The interviewer did not respond.');
  }

  /// POST /interview/session/:id/hint
  Future<String> hint(String sessionId) async {
    final decoded = await _api.post('/interview/session/$sessionId/hint');
    final data = _api.unwrap(decoded);
    if (data is Map) {
      final v = data['hint'] ?? data['response'] ?? data['message'];
      if (v != null) return v.toString();
    }
    if (data is String) return data;
    throw ApiException('No hint available.');
  }

  /// POST /interview/session/:id/run { code, language }
  Future<RunOutcome> run(String sessionId, String code, String language) async {
    final decoded = await _api.post('/interview/session/$sessionId/run', body: {
      'code': code,
      'language': language,
    });
    return RunOutcome.from(decoded);
  }

  /// POST /interview/session/:id/submit { code, language }
  Future<RunOutcome> submit(String sessionId, String code, String language) async {
    final decoded = await _api.post('/interview/session/$sessionId/submit', body: {
      'code': code,
      'language': language,
    });
    return RunOutcome.from(decoded);
  }

  /// POST /interview/session/:id/end
  Future<void> end(String sessionId) async {
    await _api.post('/interview/session/$sessionId/end');
  }

  /// GET /interview/history
  Future<List<InterviewHistoryItem>> history() async {
    final decoded = await _api.get('/interview/history');
    return _rows(_api.unwrap(decoded), ['history', 'interviews', 'items'])
        .map(InterviewHistoryItem.fromMap)
        .toList();
  }

  /// GET /interview/stats
  Future<InterviewStats> stats() async {
    try {
      final decoded = await _api.get('/interview/stats');
      final data = _api.unwrap(decoded);
      if (data is Map) return InterviewStats.fromMap(Map<String, dynamic>.from(data));
    } on ApiException {
      // Stats are optional chrome — the dashboard still renders without them.
    }
    return InterviewStats();
  }

  /// GET /interview/results/:id — raw map; the screen renders it generically.
  Future<Map<String, dynamic>> results(String sessionId) async {
    final decoded = await _api.get('/interview/results/$sessionId');
    final data = _api.unwrap(decoded);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException('Results not found.');
  }

  /// GET /interview/replays — completed interviews available to replay.
  Future<List<InterviewHistoryItem>> replays() async {
    // `{ success, replays, data }` — same rows either way.
    final decoded = await _api.get('/interview/replays');
    return _rows(decoded, ['replays']).map(InterviewHistoryItem.fromMap).toList();
  }

  /// GET /interview/replay/:id — the full timestamped timeline.
  Future<InterviewReplay> replay(String interviewId) async {
    final decoded = await _api.get('/interview/replay/$interviewId');
    if (decoded is Map) return InterviewReplay.fromMap(Map<String, dynamic>.from(decoded));
    throw ApiException('Replay not found.');
  }
}

/// Normalised outcome for interview run/submit calls, which come back in a
/// couple of shapes: run → {results, passedTests...}, submit → {feedback,
/// hasNextQuestion, nextQuestionIndex, results...}.
class RunOutcome {
  RunOutcome({this.feedback, this.hasNextQuestion, this.nextQuestionIndex, this.result});
  final String? feedback;
  final bool? hasNextQuestion;
  final int? nextQuestionIndex;
  final dynamic result; // RunResult-shaped map when present

  factory RunOutcome.from(dynamic decoded) {
    final data = decoded is Map && decoded['data'] is Map ? decoded['data'] : decoded;
    if (data is Map) {
      return RunOutcome(
        feedback: (data['feedback'] ?? data['summary'])?.toString(),
        hasNextQuestion: data['hasNextQuestion'] is bool ? data['hasNextQuestion'] as bool : null,
        nextQuestionIndex: data['nextQuestionIndex'] is num ? (data['nextQuestionIndex'] as num).toInt() : null,
        result: data['results'] ?? data,
      );
    }
    return RunOutcome();
  }

  int get passedTests {
    final r = result;
    if (r is Map) {
      final v = r['passedTests'] ?? r['passedCount'];
      if (v is num) return v.toInt();
    }
    return 0;
  }

  int get totalTests {
    final r = result;
    if (r is Map) {
      final v = r['totalTests'] ?? r['total'];
      if (v is num) return v.toInt();
    }
    return 0;
  }
}

/* ------------------------------------------------------------------ Roadmaps */

class RoadmapService {
  RoadmapService(this._api);
  final ApiClient _api;

  Future<List<Roadmap>> list() async {
    final decoded = await _api.get('/roadmaps');
    return _rows(_api.unwrap(decoded), ['roadmaps', 'items'])
        .map(Roadmap.fromMap)
        .toList();
  }

  Future<Roadmap> byId(String id) async {
    final decoded = await _api.get('/roadmaps/$id');
    final data = _api.unwrap(decoded);
    final m = data is Map ? (data['roadmap'] is Map ? data['roadmap'] : data) : null;
    if (m is! Map) throw ApiException('Roadmap not found.');
    return Roadmap.fromMap(Map<String, dynamic>.from(m));
  }

  /// POST /roadmaps/generate { goal, level } — AI-generated plan (may take a
  /// while, so callers show progress).
  Future<Roadmap> generate(String goal, String level) async {
    final decoded = await _api.post('/roadmaps/generate', body: {'goal': goal, 'level': level});
    final data = _api.unwrap(decoded);
    final m = data is Map ? (data['roadmap'] is Map ? data['roadmap'] : data) : null;
    if (m is! Map) throw ApiException('The roadmap could not be generated.');
    return Roadmap.fromMap(Map<String, dynamic>.from(m));
  }

  Future<void> delete(String id) async {
    await _api.delete('/roadmaps/$id');
  }
}

/* ------------------------------------------------------------------ Content */

class AchievementsService {
  AchievementsService(this._api);
  final ApiClient _api;

  /// GET /achievements/user → { achievements, badges, stats }
  Future<(List<Achievement>, List<String>)> user() async {
    final decoded = await _api.get('/achievements/user');
    final data = _api.unwrap(decoded);
    if (data is! Map) return (const <Achievement>[], const <String>[]);
    final achievements = _rows(data['achievements'], ['achievements'])
        .map(Achievement.fromMap)
        .toList();
    final badges = ((data['badges'] ?? const []) as List)
        .map((b) => b is Map ? (b['name'] ?? b['title'] ?? b['icon'] ?? '').toString() : b.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    return (achievements, badges);
  }
}

class HelpService {
  HelpService(this._api);
  final ApiClient _api;

  Future<List<HelpCategory>> categories() async {
    final decoded = await _api.get('/help/categories');
    return _rows(_api.unwrap(decoded), ['categories', 'items'])
        .map(HelpCategory.fromMap)
        .toList();
  }

  Future<List<HelpArticle>> articles(String categorySlug) async {
    final decoded = await _api.get('/help/categories/$categorySlug');
    final data = _api.unwrap(decoded);
    final list = data is Map
        ? (data['articles'] ?? data['items'] ?? const [])
        : (data is List ? data : const []);
    return (list as List).whereType<Map>().map((m) => HelpArticle.fromMap(Map<String, dynamic>.from(m))).toList();
  }

  Future<HelpArticle> article(String slug) async {
    final decoded = await _api.get('/help/articles/$slug');
    final data = _api.unwrap(decoded);
    final m = data is Map ? (data['article'] is Map ? data['article'] : data) : null;
    if (m is! Map) throw ApiException('Article not found.');
    return HelpArticle.fromMap(Map<String, dynamic>.from(m));
  }

  Future<List<HelpArticle>> search(String query) async {
    final decoded = await _api.get('/help/search', query: {'q': query});
    final data = _api.unwrap(decoded);
    final list = data is Map
        ? (data['articles'] ?? data['results'] ?? const [])
        : (data is List ? data : const []);
    return (list as List).whereType<Map>().map((m) => HelpArticle.fromMap(Map<String, dynamic>.from(m))).toList();
  }
}

class ResourcesService {
  ResourcesService(this._api);
  final ApiClient _api;

  Future<List<ResourceItem>> list() async {
    final decoded = await _api.get('/resources');
    return _rows(_api.unwrap(decoded), ['resources', 'items'])
        .map(ResourceItem.fromMap)
        .toList();
  }

  Future<ResourceItem> byId(String idOrSlug) async {
    final decoded = await _api.get('/resources/$idOrSlug');
    final data = _api.unwrap(decoded);
    final m = data is Map ? (data['resource'] is Map ? data['resource'] : data) : null;
    if (m is! Map) throw ApiException('Resource not found.');
    return ResourceItem.fromMap(Map<String, dynamic>.from(m));
  }

  /// POST /resources — requires 50+ reputation (backend-enforced; a fresh
  /// account will get a clear 403 message surfaced as an [ApiException]).
  Future<ResourceItem> create({
    required String title,
    required String content,
    required String type,
    required String category,
    String? excerpt,
    List<String> tags = const [],
    String? language,
    String? difficulty,
    String? externalUrl,
  }) async {
    // This endpoint replies `{ success, message, resource }` — no `data`
    // wrapper — so the raw envelope is read directly, same as profile update.
    final decoded = await _api.post('/resources', body: {
      'title': title,
      'content': content,
      'type': type,
      'category': category,
      if (excerpt != null && excerpt.isNotEmpty) 'excerpt': excerpt,
      if (tags.isNotEmpty) 'tags': tags,
      if (language != null) 'language': language,
      if (difficulty != null) 'difficulty': difficulty,
      if (externalUrl != null && externalUrl.isNotEmpty) 'externalUrl': externalUrl,
    });
    final resource = decoded is Map ? decoded['resource'] : null;
    if (resource is Map) return ResourceItem.fromMap(Map<String, dynamic>.from(resource));
    throw ApiException('The resource could not be created.');
  }
}

/* ------------------------------------------------------------------ Collabs (review queue) */

class CollabService {
  CollabService(this._api);
  final ApiClient _api;

  /// GET /suggested-edits/queue — requires 1000+ reputation or a review
  /// permission; a lower-reputation account gets a clear 403 to surface.
  Future<List<SuggestedEdit>> queue() async {
    // `{ success, pendingEdits, total, hasMore }` — no `data` wrapper.
    final decoded = await _api.get('/suggested-edits/queue');
    return _rows(decoded, ['pendingEdits']).map(SuggestedEdit.fromMap).toList();
  }

  /// GET /suggested-edits/user/:userId — the signed-in user's own
  /// submissions. Always available, regardless of reputation.
  ///
  /// The backend's route is `/user/:userId?` with the id meant to be
  /// optional (defaulting to the caller), but on this Express version the
  /// bare `/user` path 404s rather than matching the optional param — so the
  /// id is passed explicitly rather than relying on that fallback.
  Future<List<SuggestedEdit>> mySuggestions(String userId) async {
    // `{ success, suggestions }` — no `data` wrapper.
    final decoded = await _api.get('/suggested-edits/user/$userId');
    return _rows(decoded, ['suggestions']).map(SuggestedEdit.fromMap).toList();
  }

  /// POST /suggested-edits/:resourceType/:resourceId { proposedChanges, reason }
  Future<void> propose(String resourceType, String resourceId, Map<String, dynamic> proposedChanges, String reason) async {
    await _api.post('/suggested-edits/$resourceType/$resourceId', body: {
      'proposedChanges': proposedChanges,
      'reason': reason,
    });
  }

  /// POST /suggested-edits/:editId/vote { voteType: 'approve' | 'reject' }
  Future<void> vote(String editId, String voteType) async {
    await _api.post('/suggested-edits/$editId/vote', body: {'voteType': voteType});
  }

  /// POST /suggested-edits/:editId/approve — requires 1000+ reputation.
  Future<void> approve(String editId, {String? comment}) async {
    await _api.post('/suggested-edits/$editId/approve', body: {if (comment != null) 'comment': comment});
  }

  /// POST /suggested-edits/:editId/reject — requires 1000+ reputation.
  Future<void> reject(String editId, {String? comment}) async {
    await _api.post('/suggested-edits/$editId/reject', body: {if (comment != null) 'comment': comment});
  }
}

class SupportService {
  SupportService(this._api);
  final ApiClient _api;

  Future<List<SupportTicket>> tickets() async {
    final decoded = await _api.get('/support/tickets');
    return _rows(_api.unwrap(decoded), ['tickets', 'items'])
        .map(SupportTicket.fromMap)
        .toList();
  }

  /// POST /support/tickets { subject, description, category, priority }
  Future<SupportTicket> create({
    required String subject,
    required String description,
    String category = 'general',
    String priority = 'medium',
  }) async {
    final decoded = await _api.post('/support/tickets', body: {
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority,
    });
    final data = _api.unwrap(decoded);
    final m = data is Map ? (data['ticket'] is Map ? data['ticket'] : data) : null;
    if (m is! Map) throw ApiException('The ticket could not be created.');
    return SupportTicket.fromMap(Map<String, dynamic>.from(m));
  }
}

/// GET /dashboard/client — refreshed account stats (solved, accuracy, streak).
class DashboardService {
  DashboardService(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> client() async {
    final decoded = await _api.get('/dashboard/client');
    final data = _api.unwrap(decoded);
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }
}

/// Small helper used by the mentor screen to pretty-print nothing special —
/// kept here so screens don't import dart:convert directly.
String prettyJson(Object? o) {
  try {
    return const JsonEncoder.withIndent('  ').convert(o);
  } catch (_) {
    return '$o';
  }
}
