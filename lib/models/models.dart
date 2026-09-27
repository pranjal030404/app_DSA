/// Data models mirroring the backend envelope and the Problem/User schemas.

class User {
  User({
    required this.id,
    this.username,
    required this.email,
    this.role,
    this.problemsSolved = 0,
    this.accuracy = 0,
    this.currentLevel = 'Beginner',
    this.streak = 0,
    this.bio = '',
    this.phone = '',
    this.github = '',
    this.linkedin = '',
    this.skills = const [],
    this.experience = '',
    this.education = '',
    this.reputation = 1,
    this.resumeUrl,
    this.resumeUploadedAt,
  });

  final String id;
  final String? username;
  final String email;
  final String? role;
  final int problemsSolved;
  final int accuracy;
  final String currentLevel;
  final int streak;
  final String bio;
  final String phone;
  final String github;
  final String linkedin;
  final List<String> skills;
  final String experience;
  final String education;
  final int reputation;
  final String? resumeUrl;
  final DateTime? resumeUploadedAt;

  bool get hasResume => resumeUrl != null && resumeUrl!.isNotEmpty;

  /// Minimum reputation the backend requires to create a resource or have a
  /// suggested edit auto-approved-eligible for review (see resourceController
  /// / suggestedEditController on the backend).
  bool get canCreateResources => reputation >= 50;
  bool get canReviewEdits => reputation >= 1000;

  factory User.fromMap(Map<String, dynamic> m) {
    return User(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      username: m['username']?.toString(),
      email: (m['email'] ?? '').toString(),
      role: m['role']?.toString(),
      problemsSolved: _toInt(m['problemsSolved']),
      accuracy: _toInt(m['accuracy']),
      currentLevel: (m['currentLevel'] ?? 'Beginner').toString(),
      streak: _toInt(m['streak']),
      bio: (m['bio'] ?? '').toString(),
      phone: (m['phone'] ?? '').toString(),
      github: (m['github'] ?? '').toString(),
      linkedin: (m['linkedin'] ?? '').toString(),
      skills: (m['skills'] as List?)?.map((s) => s.toString()).toList() ?? const [],
      experience: (m['experience'] ?? '').toString(),
      education: (m['education'] ?? '').toString(),
      reputation: _toInt(m['reputation']) == 0 ? 1 : _toInt(m['reputation']),
      resumeUrl: m['resumeUrl']?.toString(),
      resumeUploadedAt: DateTime.tryParse('${m['resumeUploadedAt'] ?? ''}'),
    );
  }

  static int _toInt(dynamic v) =>
      v is num ? v.round() : int.tryParse('$v') ?? 0;
}

/// One row in the problems list.
class ProblemSummary {
  ProblemSummary({
    required this.slug,
    required this.title,
    required this.difficulty,
    this.topics = const [],
  });

  final String slug;
  final String title;
  final String difficulty;
  final List<String> topics;

  factory ProblemSummary.fromMap(Map<String, dynamic> m) {
    return ProblemSummary(
      slug: (m['slug'] ?? m['_id'] ?? '').toString(),
      title: (m['title'] ?? 'Untitled').toString(),
      difficulty: (m['difficulty'] ?? 'Medium').toString(),
      topics: (m['topics'] as List?)?.map((t) => t.toString()).toList() ?? const [],
    );
  }
}

/// A visible (sample) test case shown on the problem page.
class TestCase {
  TestCase({required this.input, required this.output});
  final String input;
  final String output;

  factory TestCase.fromMap(Map<String, dynamic> m) => TestCase(
        input: (m['input'] ?? '').toString(),
        output: (m['output'] ?? '').toString(),
      );
}

/// Full problem document — fields match models/Problem.js.
class ProblemDetail {
  ProblemDetail({
    required this.slug,
    required this.title,
    required this.difficulty,
    this.description = '',
    this.topics = const [],
    this.companies = const [],
    this.constraints,
    this.inputFormat,
    this.outputFormat,
    this.sampleTestCases = const [],
    this.hints = const [],
    this.starterCode = const {},
  });

  final String slug;
  final String title;
  final String difficulty;
  final String description;
  final List<String> topics;
  final List<String> companies;
  final String? constraints;
  final String? inputFormat;
  final String? outputFormat;
  final List<TestCase> sampleTestCases;
  final List<String> hints;

  /// keys: javascript | python | java | cpp (as stored in the DB)
  final Map<String, String> starterCode;

  /// Ordered language choices that actually have starter code or are runnable.
  List<String> get languages {
    const order = ['javascript', 'python', 'cpp', 'java'];
    final present = order.where((l) => starterCode[l]?.trim().isNotEmpty == true).toList();
    return present.isEmpty ? const ['javascript'] : present;
  }

  factory ProblemDetail.fromMap(Map<String, dynamic> m) {
    final starter = <String, String>{};
    if (m['starterCode'] is Map) {
      (m['starterCode'] as Map).forEach((k, v) {
        if (v != null) starter[k.toString()] = v.toString();
      });
    }
    return ProblemDetail(
      slug: (m['slug'] ?? '').toString(),
      title: (m['title'] ?? 'Untitled').toString(),
      difficulty: (m['difficulty'] ?? 'Medium').toString(),
      description: _stripHtml((m['description'] ?? '').toString()),
      topics: (m['topics'] as List?)?.map((t) => t.toString()).toList() ?? const [],
      companies: (m['companies'] as List?)?.map((t) => t.toString()).toList() ?? const [],
      constraints: m['constraints']?.toString(),
      inputFormat: m['inputFormat']?.toString(),
      outputFormat: m['outputFormat']?.toString(),
      sampleTestCases: (m['sampleTestCases'] as List? ?? [])
          .whereType<Map>()
          .map((e) => TestCase.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      hints: (m['hints'] as List?)?.map((h) => h.toString()).toList() ?? const [],
      starterCode: starter,
    );
  }

  /// The API stores rich text; render plain text to avoid an HTML dependency.
  static String _stripHtml(String html) {
    final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return withoutTags
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }
}

/// Catalogue totals from GET /problems/public/stats.
class ProblemStats {
  ProblemStats({this.total, this.topicsCount, this.difficulties = const {}});
  final int? total;
  final int? topicsCount;
  final Map<String, int> difficulties; // Easy / Medium / Hard

  factory ProblemStats.fromMap(Map<String, dynamic> m) {
    final topics = m['topics'];
    final diffs = <String, int>{};
    if (m['difficulties'] is Map) {
      (m['difficulties'] as Map).forEach((k, v) => diffs[k.toString()] = User._toInt(v));
    }
    return ProblemStats(
      total: m['total'] == null ? null : User._toInt(m['total']),
      topicsCount: topics is List ? topics.length : null,
      difficulties: diffs,
    );
  }
}

/// Outcome of POST /problems/:slug/run or /submit.
class RunResult {
  RunResult({
    required this.allPassed,
    required this.passedTests,
    required this.totalTests,
    this.results = const [],
  });

  final bool allPassed;
  final int passedTests;
  final int totalTests;
  final List<CaseResult> results;

  factory RunResult.fromMap(Map<String, dynamic> m) {
    final rows = (m['results'] as List? ?? [])
        .whereType<Map>()
        .map((e) => CaseResult.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final passed = m['passedTests'] ?? rows.where((r) => r.passed).length;
    final total = m['totalTests'] ?? rows.length;
    return RunResult(
      allPassed: m['success'] == true || (total > 0 && passed == total),
      passedTests: User._toInt(passed),
      totalTests: User._toInt(total),
      results: rows,
    );
  }
}

class CaseResult {
  CaseResult({
    required this.passed,
    this.input,
    this.expected,
    this.actual,
    this.verdict,
    this.runtime,
  });
  final bool passed;
  final String? input;
  final String? expected;
  final String? actual;
  final String? verdict;
  final String? runtime;

  factory CaseResult.fromMap(Map<String, dynamic> m) => CaseResult(
        passed: m['passed'] == true,
        input: m['input']?.toString(),
        expected: m['expectedOutput']?.toString() ?? m['expected']?.toString(),
        actual: m['actualOutput']?.toString() ?? m['output']?.toString(),
        verdict: m['verdict']?.toString(),
        runtime: (m['runtime'] ?? m['time'])?.toString(),
      );
}
