/// Models for the mentor chat, playground, interviews, roadmaps and the
/// content areas (help, resources, support, achievements).
///
/// Parsing is deliberately defensive: the backend serves several shapes, so
/// accessors tolerate missing fields instead of throwing.

class ChatMessage {
  ChatMessage({required this.text, required this.fromMentor, this.error = false});
  final String text;
  final bool fromMentor;
  final bool error;
}

class PlaygroundRun {
  PlaygroundRun({this.stdout, this.stderr, this.verdict, this.exitCode, this.time});
  final String? stdout;
  final String? stderr;
  final String? verdict;
  final int? exitCode;
  final String? time;

  factory PlaygroundRun.fromMap(Map<String, dynamic> m) => PlaygroundRun(
        stdout: _s(m['stdout'] ?? m['output']),
        stderr: _s(m['stderr'] ?? m['error']),
        verdict: _s(m['verdict'] ?? m['status']),
        exitCode: m['exitCode'] is num ? (m['exitCode'] as num).toInt() : null,
        time: _s(m['time'] ?? m['runtime'] ?? m['executionTime']),
      );

  static String? _s(dynamic v) =>
      v == null ? null : v.toString();
}

class RoadmapPhase {
  RoadmapPhase({required this.title, this.description, this.items = const [], this.isDone = false});
  final String title;
  final String? description;
  final List<String> items;
  final bool isDone;
}

class Roadmap {
  Roadmap({
    required this.id,
    required this.title,
    this.goal,
    this.level,
    this.phases = const [],
    this.createdAt,
  });

  final String id;
  final String title;
  final String? goal;
  final String? level;
  final List<RoadmapPhase> phases;
  final DateTime? createdAt;

  int get totalTasks => phases.fold(0, (n, p) => n + p.items.length);

  factory Roadmap.fromMap(Map<String, dynamic> m) {
    final rawPhases = (m['phases'] ?? m['milestones'] ?? m['sections']) as List? ?? const [];
    return Roadmap(
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      title: (m['title'] ?? m['goal'] ?? 'Roadmap').toString(),
      goal: _s(m['goal']),
      level: _s(m['level']),
      createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}'),
      phases: rawPhases.whereType<Map>().map((p) {
        final rawItems = (p['tasks'] ?? p['topics'] ?? p['items'] ?? p['steps']) as List? ?? const [];
        return RoadmapPhase(
          title: (p['title'] ?? p['name'] ?? 'Phase').toString(),
          description: _s(p['description'] ?? p['summary']),
          items: rawItems.map((t) {
            if (t is Map) return (t['title'] ?? t['name'] ?? t['task'] ?? '').toString();
            return t.toString();
          }).where((s) => s.isNotEmpty).toList(),
          isDone: p['status'] == 'done' || p['completed'] == true,
        );
      }).toList(),
    );
  }

  static String? _s(dynamic v) => v == null ? null : v.toString();
}

class Achievement {
  Achievement({
    required this.title,
    this.description,
    this.unlocked = false,
    this.progress,
    this.target,
    this.tier,
  });

  final String title;
  final String? description;
  final bool unlocked;
  final int? progress;
  final int? target;
  final String? tier;

  factory Achievement.fromMap(Map<String, dynamic> m) => Achievement(
        title: (m['title'] ?? m['name'] ?? 'Achievement').toString(),
        description: (m['description'] ?? m['hint'])?.toString(),
        unlocked: m['unlocked'] == true || m['earned'] == true || m['achieved'] == true,
        progress: m['progress'] is num ? (m['progress'] as num).toInt() : null,
        target: m['target'] is num
            ? (m['target'] as num).toInt()
            : (m['required'] is num ? (m['required'] as num).toInt() : null),
        tier: (m['tier'] ?? m['rarity'])?.toString(),
      );
}

class InterviewStats {
  InterviewStats({this.total, this.completed, this.avgScore, this.bestScore});
  final int? total;
  final int? completed;
  final int? avgScore;
  final int? bestScore;

  factory InterviewStats.fromMap(Map<String, dynamic> m) {
    final s = m['stats'] is Map ? m['stats'] : m;
    int? pick(List<String> keys) {
      for (final k in keys) {
        final v = s[k];
        if (v is num) return v.round();
      }
      return null;
    }
    return InterviewStats(
      total: pick(['total', 'totalInterviews', 'count']),
      completed: pick(['completed', 'completedInterviews', 'finished']),
      avgScore: pick(['averageScore', 'avgScore', 'average']),
      bestScore: pick(['bestScore', 'highestScore', 'best']),
    );
  }
}

class InterviewHistoryItem {
  InterviewHistoryItem({required this.id, this.type, this.difficulty, this.score, this.date, this.status});
  final String id;
  final String? type;
  final String? difficulty;
  final int? score;
  final DateTime? date;
  final String? status;

  factory InterviewHistoryItem.fromMap(Map<String, dynamic> m) => InterviewHistoryItem(
        id: (m['_id'] ?? m['id'] ?? m['sessionId'] ?? '').toString(),
        type: (m['interviewType'] ?? m['type'])?.toString(),
        difficulty: (m['difficulty'])?.toString(),
        score: m['score'] is num ? (m['score'] as num).round() : (m['overallScore'] is num ? (m['overallScore'] as num).round() : null),
        date: DateTime.tryParse('${m['createdAt'] ?? m['date'] ?? ''}'),
        status: (m['status'])?.toString(),
      );
}

class InterviewQuestion {
  InterviewQuestion({required this.title, this.description});
  final String title;
  final String? description;

  factory InterviewQuestion.fromMap(Map<String, dynamic> m) => InterviewQuestion(
        title: (m['title'] ?? m['name'] ?? 'Question').toString(),
        description: (m['description'] ?? m['problem'] ?? m['prompt'])?.toString(),
      );
}

class InterviewSession {
  InterviewSession({
    required this.id,
    this.timeRemaining,
    this.duration,
    this.currentIndex = 0,
    this.totalQuestions = 0,
    this.questions = const [],
  });

  final String id;
  final int? timeRemaining; // seconds
  final int? duration;
  final int currentIndex;
  final int totalQuestions;
  final List<InterviewQuestion> questions;

  factory InterviewSession.fromMap(Map<String, dynamic> m) {
    final s = m['session'] is Map ? m['session'] : m;
    final rawQs = (s['questions'] ?? const []) as List;
    return InterviewSession(
      id: (s['_id'] ?? s['id'] ?? '').toString(),
      timeRemaining: s['timeRemaining'] is num ? (s['timeRemaining'] as num).toInt() : null,
      duration: s['duration'] is num ? (s['duration'] as num).toInt() : null,
      currentIndex: s['currentQuestionIndex'] is num ? (s['currentQuestionIndex'] as num).toInt() : 0,
      totalQuestions: s['totalQuestions'] is num
          ? (s['totalQuestions'] as num).toInt()
          : rawQs.length,
      questions: rawQs
          .whereType<Map>()
          .map((e) => InterviewQuestion.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class HelpCategory {
  HelpCategory({required this.slug, required this.title, this.description, this.articleCount});
  final String slug;
  final String title;
  final String? description;
  final int? articleCount;

  factory HelpCategory.fromMap(Map<String, dynamic> m) => HelpCategory(
        slug: (m['slug'] ?? m['_id'] ?? '').toString(),
        title: (m['name'] ?? m['title'] ?? 'Category').toString(),
        description: (m['description'])?.toString(),
        articleCount: m['articleCount'] is num ? (m['articleCount'] as num).toInt() : null,
      );
}

class HelpArticle {
  HelpArticle({required this.slug, required this.title, this.summary, this.body});
  final String slug;
  final String title;
  final String? summary;
  final String? body;

  factory HelpArticle.fromMap(Map<String, dynamic> m) => HelpArticle(
        slug: (m['slug'] ?? m['_id'] ?? '').toString(),
        title: (m['title'] ?? 'Article').toString(),
        summary: (m['summary'] ?? m['excerpt'])?.toString(),
        body: (m['content'] ?? m['body'])?.toString(),
      );
}

class SupportTicket {
  SupportTicket({
    required this.ticketNumber,
    required this.subject,
    this.description,
    this.status,
    this.priority,
    this.createdAt,
  });

  final String ticketNumber;
  final String subject;
  final String? description;
  final String? status;
  final String? priority;
  final DateTime? createdAt;

  factory SupportTicket.fromMap(Map<String, dynamic> m) => SupportTicket(
        ticketNumber: (m['ticketNumber'] ?? m['_id'] ?? '').toString(),
        subject: (m['subject'] ?? 'Ticket').toString(),
        description: (m['description'])?.toString(),
        status: (m['status'])?.toString(),
        priority: (m['priority'])?.toString(),
        createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}'),
      );
}

/// One entry in the community review queue ("Collabs") — a proposed change
/// to a Resource, Discussion or HelpArticle awaiting approval.
class SuggestedEdit {
  SuggestedEdit({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    this.suggestedByName,
    this.reason,
    this.status = 'pending',
    this.approveVotes = 0,
    this.rejectVotes = 0,
    this.createdAt,
  });

  final String id;
  final String resourceType;
  final String resourceId;
  final String? suggestedByName;
  final String? reason;
  final String status;
  final int approveVotes;
  final int rejectVotes;
  final DateTime? createdAt;

  factory SuggestedEdit.fromMap(Map<String, dynamic> m) {
    final by = m['suggestedBy'];
    return SuggestedEdit(
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      resourceType: (m['resourceType'] ?? '').toString(),
      resourceId: (m['resourceId'] ?? '').toString(),
      suggestedByName: by is Map ? (by['username'])?.toString() : by?.toString(),
      reason: (m['reason'])?.toString(),
      status: (m['status'] ?? 'pending').toString(),
      approveVotes: (m['approveVoteCount'] is num)
          ? (m['approveVoteCount'] as num).toInt()
          : ((m['approveVotes'] as List?)?.length ?? 0),
      rejectVotes: (m['rejectVoteCount'] is num)
          ? (m['rejectVoteCount'] as num).toInt()
          : ((m['rejectVotes'] as List?)?.length ?? 0),
      createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}'),
    );
  }
}

/// One event on an interview replay timeline.
class ReplayEvent {
  ReplayEvent({required this.type, required this.elapsedSeconds, this.text, this.role, this.score});
  final String type; // start | message | submit | hint_request | end
  final int elapsedSeconds;
  final String? text;
  final String? role; // user | ai, for `message` events
  final int? score; // for `submit` events

  factory ReplayEvent.fromMap(Map<String, dynamic> m) => ReplayEvent(
        type: (m['type'] ?? 'event').toString(),
        elapsedSeconds: m['elapsed'] is num ? (m['elapsed'] as num).toInt() : 0,
        text: (m['content'] ?? m['message'] ?? m['hint'] ?? m['problem'])?.toString(),
        role: (m['role'])?.toString(),
        score: m['score'] is num ? (m['score'] as num).toInt() : null,
      );
}

/// Full replay of a completed interview: metadata + timestamped timeline.
class InterviewReplay {
  InterviewReplay({
    required this.interviewType,
    this.difficulty,
    this.overallScore,
    this.events = const [],
    this.totalMessages = 0,
    this.hintsUsed = 0,
  });

  final String interviewType;
  final String? difficulty;
  final int? overallScore;
  final List<ReplayEvent> events;
  final int totalMessages;
  final int hintsUsed;

  factory InterviewReplay.fromMap(Map<String, dynamic> m) {
    final r = m['replay'] is Map ? Map<String, dynamic>.from(m['replay']) : m;
    final timeline = (r['timeline'] as List? ?? const []);
    final insights = r['insights'] is Map ? r['insights'] as Map : const {};
    return InterviewReplay(
      interviewType: (r['interviewType'] ?? 'Interview').toString(),
      difficulty: (r['difficulty'])?.toString(),
      overallScore: r['overallScore'] is num ? (r['overallScore'] as num).toInt() : null,
      events: timeline.whereType<Map>().map((e) => ReplayEvent.fromMap(Map<String, dynamic>.from(e))).toList(),
      totalMessages: insights['totalMessages'] is num ? (insights['totalMessages'] as num).toInt() : 0,
      hintsUsed: insights['hintsUsed'] is num ? (insights['hintsUsed'] as num).toInt() : 0,
    );
  }
}

class ResourceItem {
  ResourceItem({
    required this.id,
    required this.title,
    this.summary,
    this.category,
    this.author,
    this.votes,
  });

  final String id;
  final String title;
  final String? summary;
  final String? category;
  final String? author;
  final int? votes;

  factory ResourceItem.fromMap(Map<String, dynamic> m) => ResourceItem(
        id: (m['slug'] ?? m['_id'] ?? m['id'] ?? '').toString(),
        title: (m['title'] ?? 'Resource').toString(),
        summary: (m['summary'] ?? m['excerpt'] ?? m['description'])?.toString(),
        category: (m['category'])?.toString(),
        author: m['author'] is Map
            ? ((m['author'] as Map)['username'] ?? (m['author'] as Map)['name'])?.toString()
            : (m['author'])?.toString(),
        votes: m['votes'] is num ? (m['votes'] as num).toInt() : null,
      );
}
