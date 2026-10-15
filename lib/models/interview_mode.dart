// Interview mode contract, wizard catalog, system-design diagrams and resume profiles for the AI interview.
// Mirrors the web app (frontend_DSA/src/utils/interviewMode.js, diagramText.js) and the backend
// (src/modules/interviewer/mode.js, diagram.js), so the app renders exactly the room the server chose.

/// The three interview kinds. The server's value is authoritative.
class InterviewModes {
  static const job = 'job_interview';
  static const technical = 'technical_interview';
  static const dsa = 'dsa_interview';
  static const all = [job, technical, dsa];

  static const labels = {
    job: 'General / HR interview',
    technical: 'Technical interview',
    dsa: 'DSA interview',
  };
  static const short = {job: 'General / HR', technical: 'Technical', dsa: 'DSA'};
  static const blurbs = {
    job: 'Conversational: introduction, motivation, behavioral and HR questions. No code editor.',
    technical: 'Conversational and role-specific: concepts, debugging, SQL, API and system design. No code editor.',
    dsa: 'Algorithm problems in a code editor, judged by tests, with an interviewer for hints.',
  };

  /// The track a mode belongs to on the server ("dsa" runs the code judge).
  static String trackFor(String mode) => mode == dsa ? 'dsa' : 'general';
}

/// Which room to render: "dsa" (problem + editor) or "conversational" (interview room, never an editor).
/// Uses the stored mode; older servers send only `track`. Never looks at titles or whether a problem exists.
String roomKind({String? interviewMode, String? track}) {
  if (interviewMode != null && interviewMode.isNotEmpty) {
    if (interviewMode == InterviewModes.dsa) return 'dsa';
    return 'conversational'; // job, technical, or an unrecognised value: never guess a code workspace
  }
  if (track == 'general') return 'conversational';
  if (track == null || track == 'dsa') return 'dsa'; // historical default
  return 'conversational';
}

String modeLabel({String? interviewMode, String? track}) =>
    InterviewModes.short[interviewMode] ?? (roomKind(interviewMode: interviewMode, track: track) == 'dsa' ? 'DSA' : 'Technical');

/* ---------------------------------------------------------------- catalog (GET /interview/tracks) */

class CatalogRound {
  CatalogRound({required this.key, required this.label, this.count = 0, this.minutes = 0});
  final String key;
  final String label;
  final int count;
  final int minutes;
  factory CatalogRound.fromMap(Map<String, dynamic> m) => CatalogRound(
        key: (m['key'] ?? '').toString(),
        label: (m['label'] ?? '').toString(),
        count: m['count'] is num ? (m['count'] as num).toInt() : 0,
        minutes: m['minutes'] is num ? (m['minutes'] as num).toInt() : 0,
      );
}

/// A preset ("Campus placement") or a track ("Backend engineering"): both carry a round plan.
class CatalogPlan {
  CatalogPlan({
    required this.id,
    required this.label,
    this.blurb,
    this.group,
    this.experience,
    this.difficulty,
    this.questionCount,
    this.duration,
    this.rounds = const [],
    this.isTrack = false,
    this.track,
  });
  final String id;
  final String label;
  final String? blurb;
  final String? group;
  final String? experience;
  final String? difficulty;
  final int? questionCount;
  final int? duration;
  final List<CatalogRound> rounds;
  final bool isTrack;
  final String? track;

  factory CatalogPlan.fromMap(Map<String, dynamic> m, {required bool isTrack}) => CatalogPlan(
        id: (m['id'] ?? '').toString(),
        label: (m['label'] ?? '').toString(),
        blurb: m['blurb']?.toString(),
        group: m['group']?.toString(),
        experience: m['experience']?.toString(),
        difficulty: m['difficulty']?.toString(),
        questionCount: m['questionCount'] is num ? (m['questionCount'] as num).toInt() : null,
        duration: m['duration'] is num ? (m['duration'] as num).toInt() : null,
        rounds: (m['rounds'] is List)
            ? (m['rounds'] as List).whereType<Map>().map((e) => CatalogRound.fromMap(Map<String, dynamic>.from(e))).toList()
            : const [],
        isTrack: isTrack,
        track: m['track']?.toString(),
      );

  /// The HR track and HR-only presets are job interviews; everything else is technical.
  String get interviewMode => (id == 'hr' || track == 'hr') ? InterviewModes.job : InterviewModes.technical;
}

class IdLabel {
  IdLabel(this.id, this.label, {this.difficulty});
  final String id;
  final String label;
  final String? difficulty;
}

class InterviewCatalog {
  InterviewCatalog({this.presets = const [], this.tracks = const [], this.experienceLevels = const [], this.modes = const []});
  final List<CatalogPlan> presets;
  final List<CatalogPlan> tracks;
  final List<IdLabel> experienceLevels;
  final List<IdLabel> modes;

  factory InterviewCatalog.fromMap(Map<String, dynamic> m) {
    List<Map<String, dynamic>> rows(String k) =>
        (m[k] is List) ? (m[k] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
    return InterviewCatalog(
      presets: rows('presets').map((e) => CatalogPlan.fromMap(e, isTrack: false)).toList(),
      tracks: rows('tracks').map((e) => CatalogPlan.fromMap(e, isTrack: true)).toList(),
      experienceLevels: rows('experienceLevels')
          .map((e) => IdLabel((e['id'] ?? '').toString(), (e['label'] ?? '').toString(), difficulty: e['difficulty']?.toString()))
          .toList(),
      modes: rows('modes').map((e) => IdLabel((e['id'] ?? '').toString(), (e['label'] ?? '').toString())).toList(),
    );
  }
}

/* ---------------------------------------------------------------- system-design diagram */

class DiagramNode {
  DiagramNode({required this.id, required this.label, this.kind = 'service', this.x = 0, this.y = 0});
  final String id;
  final String label;
  final String kind;
  double x;
  double y;
  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'kind': kind, 'x': x.round(), 'y': y.round()};
}

class DiagramEdge {
  DiagramEdge({required this.from, required this.to, this.label = ''});
  final String from;
  final String to;
  final String label;
  Map<String, dynamic> toMap() => {'from': from, 'to': to, 'label': label};
}

class DiagramScene {
  DiagramScene({List<DiagramNode>? nodes, List<DiagramEdge>? edges})
      : nodes = nodes ?? [],
        edges = edges ?? [];
  final List<DiagramNode> nodes;
  final List<DiagramEdge> edges;

  static const maxNodes = 30;
  static const maxEdges = 60;
  static const maxLabel = 40;
  static const kinds = <String, String>{
    'client': 'Client',
    'load-balancer': 'Load balancer',
    'service': 'Service',
    'database': 'Database',
    'cache': 'Cache',
    'queue': 'Queue',
    'storage': 'Object storage',
    'external': 'External system',
    'other': 'Other',
  };
  // Must match backend diagram.js KIND_LABEL (what the grader reads).
  static const _kindText = <String, String>{
    'client': 'client',
    'service': 'service',
    'database': 'database',
    'cache': 'cache',
    'queue': 'queue',
    'storage': 'object storage',
    'load-balancer': 'load balancer',
    'external': 'external system',
    'other': 'component',
  };

  bool get isEmpty => nodes.isEmpty;

  factory DiagramScene.fromMap(Map<String, dynamic>? m) {
    if (m == null) return DiagramScene();
    final nodes = (m['nodes'] is List)
        ? (m['nodes'] as List).whereType<Map>().map((e) {
            final n = Map<String, dynamic>.from(e);
            return DiagramNode(
              id: (n['id'] ?? '').toString(),
              label: (n['label'] ?? '').toString(),
              kind: (n['kind'] ?? 'other').toString(),
              x: n['x'] is num ? (n['x'] as num).toDouble() : 0,
              y: n['y'] is num ? (n['y'] as num).toDouble() : 0,
            );
          }).toList()
        : <DiagramNode>[];
    final edges = (m['edges'] is List)
        ? (m['edges'] as List).whereType<Map>().map((e) {
            final x = Map<String, dynamic>.from(e);
            return DiagramEdge(from: (x['from'] ?? '').toString(), to: (x['to'] ?? '').toString(), label: (x['label'] ?? '').toString());
          }).toList()
        : <DiagramEdge>[];
    return DiagramScene(nodes: nodes, edges: edges);
  }

  Map<String, dynamic> toMap() => {'nodes': nodes.map((n) => n.toMap()).toList(), 'edges': edges.map((e) => e.toMap()).toList()};

  String nextId() {
    var i = nodes.length + 1;
    while (nodes.any((n) => n.id == 'n$i')) {
      i++;
    }
    return 'n$i';
  }

  /// Adds a component; returns false when the label is empty or the board is full.
  bool addNode(String label, String kind) {
    final text = label.trim();
    if (text.isEmpty || nodes.length >= maxNodes) return false;
    final i = nodes.length;
    nodes.add(DiagramNode(
      id: nextId(),
      label: text.length > maxLabel ? text.substring(0, maxLabel) : text,
      kind: kinds.containsKey(kind) ? kind : 'other',
      x: 24.0 + (i % 3) * 150,
      y: 24.0 + (i ~/ 3) * 80,
    ));
    return true;
  }

  /// Adds a connection; returns false for self loops, duplicates, unknown ends or a full board.
  bool addEdge(String from, String to, String label) {
    if (from == to || edges.length >= maxEdges) return false;
    if (!nodes.any((n) => n.id == from) || !nodes.any((n) => n.id == to)) return false;
    if (edges.any((e) => e.from == from && e.to == to)) return false;
    final l = label.trim();
    edges.add(DiagramEdge(from: from, to: to, label: l.length > maxLabel ? l.substring(0, maxLabel) : l));
    return true;
  }

  void removeNode(String id) {
    nodes.removeWhere((n) => n.id == id);
    edges.removeWhere((e) => e.from == id || e.to == id);
  }

  /// Exactly the words the interviewer grades (backend diagram.sceneToText).
  String toText() {
    if (nodes.isEmpty) return '';
    final name = {for (final n in nodes) n.id: n.label};
    final parts = ['Diagram components: ${nodes.map((n) => '${n.label} (${_kindText[n.kind] ?? 'component'})').join(', ')}.'];
    if (edges.isNotEmpty) {
      parts.add('Diagram connections: ${edges.map((e) => '${name[e.from]} -> ${name[e.to]}${e.label.isNotEmpty ? ' (${e.label})' : ''}').join('; ')}.');
    }
    return parts.join(' ');
  }
}

/* ---------------------------------------------------------------- resume profile (POST /interview/resume/parse) */

class ResumeEntry {
  ResumeEntry(this.title, this.details);
  final String title;
  final String details;
  Map<String, dynamic> toMap() => {'title': title, 'details': details};
}

/// What the server read from a PDF resume. The candidate removes anything wrong before it is used;
/// only the kept items are sent with the interview (the file itself is never stored).
class ResumeProfile {
  ResumeProfile({List<String>? skills, List<ResumeEntry>? projects, List<ResumeEntry>? experience, List<String>? achievements, this.hints = const []})
      : skills = skills ?? [],
        projects = projects ?? [],
        experience = experience ?? [],
        achievements = achievements ?? [];
  final List<String> skills;
  final List<ResumeEntry> projects;
  final List<ResumeEntry> experience;
  final List<String> achievements;
  final List<String> hints;

  int get itemCount => skills.length + projects.length + experience.length + achievements.length;

  factory ResumeProfile.fromMap(Map<String, dynamic> body) {
    final p = body['profile'] is Map ? Map<String, dynamic>.from(body['profile'] as Map) : <String, dynamic>{};
    List<String> strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
    List<ResumeEntry> entries(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => ResumeEntry((e['title'] ?? '').toString(), (e['details'] ?? '').toString())).toList()
        : <ResumeEntry>[];
    return ResumeProfile(
      skills: strings(p['skills']),
      projects: entries(p['projects']),
      experience: entries(p['experience']),
      achievements: strings(p['achievements']),
      hints: strings(body['hints']),
    );
  }

  Map<String, dynamic> toMap() => {
        'skills': skills,
        'projects': projects.map((e) => e.toMap()).toList(),
        'experience': experience.map((e) => e.toMap()).toList(),
        'achievements': achievements,
      };
}
