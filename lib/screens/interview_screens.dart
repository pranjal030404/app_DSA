import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/content.dart';
import '../services/feature_services.dart';
import '../widgets/code_editor.dart';
import '../widgets/widgets.dart';

/* ------------------------------------------------------------------ Dashboard */

/// Interview hub: stats, history, and the entry point for a new round.
class InterviewDashboardScreen extends StatefulWidget {
  const InterviewDashboardScreen({super.key});

  @override
  State<InterviewDashboardScreen> createState() => _InterviewDashboardScreenState();
}

class _InterviewDashboardScreenState extends State<InterviewDashboardScreen> {
  late Future<(InterviewStats, List<InterviewHistoryItem>)> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final service = context.read<InterviewService>();
    setState(() {
      _future = (() async => (await service.stats(), await service.history()))();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Mock interviews', style: theme.textTheme.titleLarge)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InterviewSetupScreen()),
          );
          if (mounted) _reload();
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New interview'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<(InterviewStats, List<InterviewHistoryItem>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return EmptyState(message: '${snap.error}', onRetry: _reload);
            }
            final (stats, history) =
                snap.data ?? (InterviewStats(), <InterviewHistoryItem>[]);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Rounds', value: '${stats.total ?? 0}')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            label: 'Avg score',
                            value: stats.avgScore != null ? '${stats.avgScore}' : '—',
                            accent: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 24),
                const Eyebrow('History'),
                const SizedBox(height: 12),
                if (history.isEmpty)
                  const EmptyState(
                      message: 'No interviews yet.\nStart a timed round to get a written review.')
                else
                  for (final item in history)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        title: Text(item.type ?? 'Interview',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [
                            if (item.difficulty != null) item.difficulty!,
                            if (item.date != null)
                              '${item.date!.day}/${item.date!.month}/${item.date!.year}',
                            if (item.status != null) item.status!,
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.score != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text('${item.score}',
                                    style: theme.textTheme.titleLarge
                                        ?.copyWith(color: theme.colorScheme.primary)),
                              ),
                            IconButton(
                              tooltip: 'Replay',
                              icon: const Icon(Icons.play_circle_outline),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => InterviewReplayScreen(interviewId: item.id),
                              )),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => InterviewResultsScreen(sessionId: item.id),
                        )),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ Setup */

class InterviewSetupScreen extends StatefulWidget {
  const InterviewSetupScreen({super.key});

  @override
  State<InterviewSetupScreen> createState() => _InterviewSetupScreenState();
}

class _InterviewSetupScreenState extends State<InterviewSetupScreen> {
  String _type = 'coding';
  String _difficulty = 'Medium';
  int _duration = 30;
  int _questionCount = 2;
  bool _busy = false;

  static const _types = {
    'coding': 'Coding round',
    'screening': 'Screening',
    'system-design': 'System design',
    'behavioral': 'Behavioral',
  };

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final sessionId = await context.read<InterviewService>().create(
            interviewType: _type,
            difficulty: _difficulty,
            durationMinutes: _duration,
            questionCount: _questionCount,
          );
      if (!mounted) return;
      await navigator.pushReplacement(MaterialPageRoute(
        builder: (_) => InterviewSessionScreen(sessionId: sessionId),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Set up a round')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Eyebrow('Interview type'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _types.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _type == entry.key,
                  onSelected: (_) => setState(() => _type = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Eyebrow('Difficulty'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final d in const ['Easy', 'Medium', 'Hard'])
                ChoiceChip(
                  label: Text(d),
                  selected: _difficulty == d,
                  onSelected: (_) => setState(() => _difficulty = d),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Eyebrow('Duration'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [15, 30, 45, 60])
                ChoiceChip(
                  label: Text('$m min'),
                  selected: _duration == m,
                  onSelected: (_) => setState(() => _duration = m),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Eyebrow('Questions'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final q in const [1, 2, 3, 4])
                ChoiceChip(
                  label: Text('$q'),
                  selected: _questionCount == q,
                  onSelected: (_) => setState(() => _questionCount = q),
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _busy ? null : _start,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Start interview'),
          ),
          const SizedBox(height: 12),
          Text(
            'The interviewer asks questions against the clock. Answer in the '
            'chat, write code in the editor, and you get a written review at the end.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(140)),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ Session */

class InterviewSessionScreen extends StatefulWidget {
  const InterviewSessionScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<InterviewSessionScreen> createState() => _InterviewSessionScreenState();
}

class _InterviewSessionScreenState extends State<InterviewSessionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _chatController = TextEditingController();
  final _chatScroll = ScrollController();
  final _code = TextEditingController();

  InterviewSession? _session;
  final _messages = <ChatMessage>[];
  String _language = 'python';
  String? _lastFeedback;
  Timer? _ticker;
  int _remaining = 0;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabs.dispose();
    _chatController.dispose();
    _chatScroll.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = await context.read<InterviewService>().session(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _remaining = session.timeRemaining ?? (session.duration ?? 30) * 60;
        _loading = false;
      });
      final q = session.questions.isNotEmpty ? session.questions[session.currentIndex.clamp(0, session.questions.length - 1)] : null;
      _messages.add(ChatMessage(
        fromMentor: true,
        text: q == null
            ? 'Let\'s begin. Tell me your approach.'
            : '${q.title}\n\n${q.description ?? ''}',
      ));
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remaining <= 0) return _ticker?.cancel();
      setState(() => _remaining--);
    });
  }

  String get _clock {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _busy) return;
    _chatController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, fromMentor: false));
      _busy = true;
    });
    _scrollChat();
    try {
      final reply = await context
          .read<InterviewService>()
          .sendMessage(widget.sessionId, text, code: _code.text.trim().isEmpty ? null : _code.text);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, fromMentor: true));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    _scrollChat();
  }

  Future<void> _hint() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final hint = await context.read<InterviewService>().hint(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: hint, fromMentor: true));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    _scrollChat();
  }

  Future<void> _runCode() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await context
          .read<InterviewService>()
          .run(widget.sessionId, _code.text, _language);
      if (!mounted) return;
      setState(() => _lastFeedback =
          'Run: ${outcome.passedTests}/${outcome.totalTests} passed${outcome.feedback != null ? '\n${outcome.feedback}' : ''}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitCode() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await context
          .read<InterviewService>()
          .submit(widget.sessionId, _code.text, _language);
      if (!mounted) return;
      setState(() {
        _lastFeedback =
            'Submitted: ${outcome.passedTests}/${outcome.totalTests} passed'
            '${outcome.feedback != null ? '\n${outcome.feedback}' : ''}';
        if (outcome.hasNextQuestion == true && _session != null) {
          _session = InterviewSession(
            id: _session!.id,
            timeRemaining: _remaining,
            duration: _session!.duration,
            currentIndex: (outcome.nextQuestionIndex ?? _session!.currentIndex + 1),
            totalQuestions: _session!.totalQuestions,
            questions: _session!.questions,
          );
          final idx = _session!.currentIndex;
          if (_session!.questions.length > idx) {
            final q = _session!.questions[idx];
            _messages.add(ChatMessage(text: '${q.title}\n\n${q.description ?? ''}', fromMentor: true));
          }
        }
        _busy = false;
      });
      _scrollChat();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End the interview?'),
        content: const Text('The round ends and your written review is generated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End round')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _ticker?.cancel();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<InterviewService>().end(widget.sessionId);
    } catch (_) {/* results may still be available */}
    navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => InterviewResultsScreen(sessionId: widget.sessionId),
    ));
    messenger.showSnackBar(const SnackBar(content: Text('Generating your review…')));
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    final progress = (session != null && session.totalQuestions > 0)
        ? '${session.currentIndex + 1} / ${session.totalQuestions}'
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: Text('Interview · $_clock', style: theme.textTheme.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Question $progress', style: theme.textTheme.bodySmall)),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Conversation'), Tab(text: 'Code')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildChat(theme),
                _buildCode(theme),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _hint,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Hint'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _busy ? null : _end,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withAlpha(120)),
                    ),
                    child: const Text('End round'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _messages.length + (_busy ? 1 : 0),
            itemBuilder: (context, i) {
              final fromMentor = i == _messages.length || _messages[i].fromMentor;
              return Align(
                alignment: fromMentor ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76),
                  decoration: BoxDecoration(
                    color: fromMentor
                        ? theme.colorScheme.surface
                        : theme.colorScheme.primary.withAlpha(34),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: fromMentor
                            ? (theme.brightness == Brightness.dark
                                ? EmberColors.line
                                : EmberColors.lightLine)
                            : Colors.transparent),
                  ),
                  child: i == _messages.length
                      ? const SizedBox(
                          width: 34,
                          child: LinearProgressIndicator(minHeight: 2),
                        )
                      : Text(_messages[i].text,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(hintText: 'Explain your approach…'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _busy ? null : _sendMessage,
                icon: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCode(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LanguagePicker(
                  languages: const ['python', 'javascript', 'java', 'cpp'],
                  value: _language,
                  onChanged: (v) => setState(() => _language = v),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _busy ? null : _runCode,
                child: const Text('Run'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _submitCode,
                child: const Text('Submit'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: CodePane(controller: _code)),
          if (_lastFeedback != null)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 10),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 130),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? EmberColors.line
                        : EmberColors.lightLine),
              ),
              child: SingleChildScrollView(
                child: Text(_lastFeedback!, style: theme.textTheme.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ Results */

class InterviewResultsScreen extends StatelessWidget {
  const InterviewResultsScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.read<InterviewService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: service.results(sessionId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(message: '${snap.error}');
          }
          final data = snap.data ?? const {};
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Eyebrow('Written review'),
              const SizedBox(height: 14),
              ..._renderSections(theme, data),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _renderSections(ThemeData theme, Map<String, dynamic> data) {
    final widgets = <Widget>[];
    final reserved = {'_id', 'id', 'userId', 'sessionId', 'createdAt', 'updatedAt', '__v'};

    // Numeric scores first, as bars.
    final scores = <MapEntry<String, num>>[];
    void collectScores(Map<String, dynamic> m, {String prefix = ''}) {
      m.forEach((k, v) {
        if (reserved.contains(k)) return;
        if (v is num && (k.toLowerCase().contains('score') || k.toLowerCase().contains('rating'))) {
          scores.add(MapEntry('$prefix$k', v));
        } else if (v is Map) {
          collectScores(Map<String, dynamic>.from(v), prefix: '$prefix$k · ');
        }
      });
    }
    collectScores(data);

    if (scores.isNotEmpty) {
      widgets.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in scores)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(s.key, style: theme.textTheme.bodyMedium)),
                          Text('${s.value}',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: (s.value <= 100 ? s.value / 100 : 1.0).clamp(0.0, 1.0).toDouble(),
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ));
      widgets.add(const SizedBox(height: 14));
    }

    // Then textual feedback sections.
    void addText(String title, String body) {
      widgets.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(body, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
            ],
          ),
        ),
      ));
      widgets.add(const SizedBox(height: 14));
    }

    data.forEach((k, v) {
      if (reserved.contains(k) || scores.any((s) => s.key.endsWith(k))) return;
      if (v is String && v.trim().isNotEmpty && v.length > 12) {
        addText(_titleCase(k), v);
      } else if (v is List && v.isNotEmpty) {
        final lines = v
            .map((e) => e is Map
                ? '• ${e['title'] ?? e['name'] ?? e['feedback'] ?? e['question'] ?? ''}'
                : '• ${e.toString()}')
            .where((s) => s.trim().length > 3)
            .join('\n');
        if (lines.isNotEmpty) addText(_titleCase(k), lines);
      }
    });

    if (widgets.isEmpty) {
      widgets.add(const EmptyState(message: 'The review is still being generated — pull to retry in a moment.'));
    }
    return widgets;
  }

  String _titleCase(String key) => key
      .replaceAll(RegExp(r'[_-]'), ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/* ------------------------------------------------------------------ Replay */

/// Scrubs through a completed interview's timeline — messages, hints and
/// submissions in the order they happened, each timestamped from the start
/// of the session. Mirrors the web's `interview/replay/:id` page.
class InterviewReplayScreen extends StatelessWidget {
  const InterviewReplayScreen({super.key, required this.interviewId});
  final String interviewId;

  String _mmss(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  (IconData, String) _eventChrome(ReplayEvent e) => switch (e.type) {
        'start' => (Icons.flag_outlined, 'Started'),
        'end' => (Icons.check_circle_outline, 'Completed'),
        'submit' => (Icons.upload_outlined, e.score != null ? 'Submitted · score ${e.score}' : 'Submitted'),
        'hint_request' => (Icons.lightbulb_outline, 'Hint requested'),
        'message' => (e.role == 'user' ? Icons.person_outline : Icons.smart_toy_outlined,
            e.role == 'user' ? 'You' : 'Interviewer'),
        _ => (Icons.circle_outlined, e.type),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.read<InterviewService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Replay')),
      body: FutureBuilder<InterviewReplay>(
        future: service.replay(interviewId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return EmptyState(message: '${snap.error ?? 'This interview has no replay yet.'}');
          }
          final replay = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(child: StatCard(label: 'Type', value: replay.interviewType)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Score',
                      value: replay.overallScore != null ? '${replay.overallScore}' : '—',
                      accent: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatCard(label: 'Messages', value: '${replay.totalMessages}')),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(label: 'Hints used', value: '${replay.hintsUsed}')),
                ],
              ),
              const SizedBox(height: 24),
              const Eyebrow('Timeline'),
              const SizedBox(height: 12),
              if (replay.events.isEmpty)
                const EmptyState(message: 'No timeline events were recorded for this session.')
              else
                for (final e in replay.events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(_mmss(e.elapsedSeconds), style: theme.textTheme.bodySmall),
                        ),
                        Icon(_eventChrome(e).$1, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_eventChrome(e).$2,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              if (e.text != null && e.text!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(e.text!, style: theme.textTheme.bodySmall),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
