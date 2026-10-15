import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/content.dart';
import '../models/interview_mode.dart';
import '../services/feature_services.dart';
import '../widgets/code_editor.dart';
import '../widgets/widgets.dart';
import 'interview_room.dart';

/* ------------------------------------------------------------------ Dashboard */

/// Interview hub: start one of the three interview kinds, continue an unfinished one, stats and history.
class InterviewDashboardScreen extends StatefulWidget {
  const InterviewDashboardScreen({super.key});

  @override
  State<InterviewDashboardScreen> createState() => _InterviewDashboardScreenState();
}

class _InterviewDashboardScreenState extends State<InterviewDashboardScreen> {
  late Future<(InterviewStats, List<InterviewHistoryItem>, Map<String, dynamic>?)> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final service = context.read<InterviewService>();
    setState(() {
      _future = (() async => (await service.stats(), await service.history(), await service.active()))();
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('AI interviews', style: theme.textTheme.titleLarge)),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<(InterviewStats, List<InterviewHistoryItem>, Map<String, dynamic>?)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return EmptyState(message: '${snap.error}', onRetry: _reload);
            }
            final (stats, history, active) = snap.data ?? (InterviewStats(), <InterviewHistoryItem>[], null);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const Eyebrow('Start an interview'),
                const SizedBox(height: 10),
                for (final m in InterviewModes.all)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      key: Key('start-$m'),
                      leading: Icon(
                        m == InterviewModes.dsa ? Icons.data_object : (m == InterviewModes.job ? Icons.forum_outlined : Icons.memory),
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(InterviewModes.labels[m]!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(InterviewModes.blurbs[m]!),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(InterviewSetupScreen(initialMode: m)),
                    ),
                  ),
                if (active != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: theme.colorScheme.primary.withAlpha(24),
                    child: ListTile(
                      key: const Key('continue-active'),
                      title: Text('Continue: ${modeLabel(interviewMode: active['interviewMode']?.toString(), track: active['track']?.toString())} interview'),
                      subtitle: Text([
                        'Question ${active['question'] ?? 1} of ${active['totalQuestions'] ?? '?'}',
                        if (active['round'] != null) active['round'].toString(),
                        if (active['secondsRemaining'] is num) '${((active['secondsRemaining'] as num) / 60).ceil()} min left',
                        if (active['status'] == 'paused') 'paused',
                      ].join(' · ')),
                      trailing: const Icon(Icons.play_arrow),
                      onTap: () => _open(InterviewSessionScreen(sessionId: active['_id'].toString())),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Interviews', value: '${stats.total ?? 0}')),
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
                  const EmptyState(message: 'No interviews yet.\nStart one above to get a written review.')
                else
                  for (final item in history)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        title: Text(
                            item.interviewMode != null || item.track != null
                                ? '${modeLabel(interviewMode: item.interviewMode, track: item.track)} interview${item.role != null && item.role != 'Any' ? ' · ${item.role}' : ''}'
                                : (item.type ?? 'Interview'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [
                            if (item.difficulty != null) item.difficulty!,
                            if (item.date != null) '${item.date!.day}/${item.date!.month}/${item.date!.year}',
                            if (item.status != null) item.status!,
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.score != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text('${item.score}', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
                              ),
                            IconButton(
                              tooltip: 'Replay',
                              icon: const Icon(Icons.play_circle_outline),
                              onPressed: () => _open(InterviewReplayScreen(interviewId: item.id)),
                            ),
                          ],
                        ),
                        onTap: () => _open(InterviewResultsScreen(sessionId: item.id)),
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

const _dsaTopics = ['Arrays', 'Strings', 'Linked Lists', 'Stacks', 'Queues', 'Trees', 'Graphs', 'Dynamic Programming', 'Recursion', 'Sorting', 'Searching', 'Hash Tables', 'Greedy', 'Backtracking'];
const _roles = ['Any', 'Student / Fresher', 'Backend', 'Frontend', 'Full Stack', 'DevOps / Cloud', 'Data & ML', 'Senior / Lead'];
const _jobFormats = {'behavioral': 'Behavioral (STAR stories)', 'hr': 'HR round', 'full': 'Full mock interview'};
const _techFormats = {'full': 'Full mock interview', 'technical': 'Technical fundamentals', 'system': 'System design', 'quick': 'Quick screening'};

/// Three clearly separated kinds: General/HR and Technical (conversational room) and DSA (problem + editor).
class InterviewSetupScreen extends StatefulWidget {
  const InterviewSetupScreen({super.key, this.initialMode = InterviewModes.technical});
  final String initialMode;

  @override
  State<InterviewSetupScreen> createState() => _InterviewSetupScreenState();
}

class _InterviewSetupScreenState extends State<InterviewSetupScreen> {
  late String _mode = InterviewModes.all.contains(widget.initialMode) ? widget.initialMode : InterviewModes.technical;
  bool _busy = false;

  // DSA
  String _difficulty = 'medium';
  String _style = 'conversational';
  int _dsaCount = 2;
  int _dsaMinutes = 45;
  final Set<String> _topics = {};

  // Conversational
  InterviewCatalog? _catalog;
  CatalogPlan? _plan;
  Set<String>? _roundKeys;
  String _experience = 'fresher';
  String _coachMode = 'simulation';
  bool _strictRounds = false;
  bool _coding = false;
  int _codingCount = 1;
  int _codingMinutes = 45;
  String _codingAfter = '';
  String _role = 'Any';
  late String _format = _mode == InterviewModes.job ? 'behavioral' : 'full';
  final _company = TextEditingController();
  final _years = TextEditingController();
  final _stack = TextEditingController();
  final _jd = TextEditingController();
  ResumeProfile? _resume;
  bool _parsing = false;

  @override
  void initState() {
    super.initState();
    context.read<InterviewService>().catalog().then((c) {
      if (mounted) setState(() => _catalog = c);
    }).catchError((_) {/* the plain format picker still works */});
  }

  @override
  void dispose() {
    for (final c in [_company, _years, _stack, _jd]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switchMode(String m) {
    if (m == _mode) return;
    setState(() {
      _mode = m;
      _plan = null;
      _roundKeys = null;
      _coding = false;
      _codingAfter = '';
      _format = m == InterviewModes.job ? 'behavioral' : 'full';
    });
  }

  void _pick(CatalogPlan p) {
    setState(() {
      if (_plan?.id == p.id && _plan?.isTrack == p.isTrack) {
        _plan = null;
      } else {
        _plan = p;
        _experience = p.experience ?? _experience;
        _mode = p.interviewMode;
      }
      _roundKeys = null;
      _codingAfter = '';
    });
  }

  List<CatalogRound> get _activeRounds =>
      (_plan?.rounds ?? const <CatalogRound>[]).where((r) => _roundKeys == null || _roundKeys!.contains(r.key)).toList();

  Future<void> _pickResume() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    final f = picked?.files.single;
    if (f == null || f.bytes == null || !mounted) return;
    setState(() => _parsing = true);
    try {
      final r = await context.read<InterviewService>().parseResume(f.bytes!, f.name);
      if (mounted) setState(() => _resume = r);
      if (r.itemCount == 0) messenger.showSnackBar(const SnackBar(content: Text('Nothing usable was found in that PDF.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Map<String, dynamic> _payload() {
    if (_mode == InterviewModes.dsa) {
      return {
        'track': 'dsa',
        'interviewMode': InterviewModes.dsa,
        'interviewType': _style,
        'difficulty': _difficulty,
        'topics': _topics.toList(),
        'questionCount': _dsaCount,
        'duration': _dsaMinutes,
      };
    }
    final body = <String, dynamic>{
      'track': 'general',
      'interviewType': 'mock',
      'role': _role,
      'format': _format,
      'difficulty': _difficulty,
    };
    final p = _plan;
    if (p == null) {
      body['interviewMode'] = _mode;
      body['questionCount'] = _format == 'quick' ? 3 : (_format == 'system' ? 3 : 5);
      body['duration'] = _format == 'quick' ? 20 : 40;
      return body;
    }
    // A picked preset/track: the server derives job vs technical from its rounds.
    body[p.isTrack ? 'trackId' : 'preset'] = p.id;
    body['experience'] = _experience;
    body['mode'] = _coachMode;
    if (_roundKeys != null) body['roundKeys'] = _roundKeys!.toList();
    if (_strictRounds) body['enforceRoundTimers'] = true;
    if (_coding) {
      body['codingRound'] = {
        'questionCount': _codingCount,
        'duration': _codingMinutes,
        'difficulty': _difficulty,
        if (_codingAfter.isNotEmpty) 'afterRoundKey': _codingAfter,
      };
    }
    if (_company.text.trim().isNotEmpty) body['targetCompany'] = _company.text.trim();
    final y = int.tryParse(_years.text.trim());
    if (y != null) body['yearsOfExperience'] = y;
    final stack = _stack.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).take(15).toList();
    if (stack.isNotEmpty) body['techStack'] = stack;
    if (_jd.text.trim().isNotEmpty) body['jobDescription'] = _jd.text.trim();
    if (_resume != null && _resume!.itemCount > 0) body['resume'] = _resume!.toMap();
    return body;
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final (sessionId, notice) = await context.read<InterviewService>().createInterview(_payload());
      if (!mounted) return;
      if (notice != null) messenger.showSnackBar(SnackBar(content: Text(notice)));
      await navigator.pushReplacement(MaterialPageRoute(builder: (_) => InterviewSessionScreen(sessionId: sessionId)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips<T>(Map<T, String> options, T value, ValueChanged<T> onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries) ChoiceChip(label: Text(e.value), selected: value == e.key, onSelected: (_) => onPick(e.key)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conversational = _mode != InterviewModes.dsa;
    final groups = <String, List<CatalogPlan>>{};
    for (final t in _catalog?.tracks ?? const <CatalogPlan>[]) {
      groups.putIfAbsent(t.group ?? 'Other', () => []).add(t);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Set up an interview')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Eyebrow('Kind of interview'),
          const SizedBox(height: 10),
          for (final m in InterviewModes.all)
            Card(
              key: Key('mode-$m'),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _mode == m ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: _mode == m ? 2 : 1),
              ),
              child: Semantics(
                selected: _mode == m,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  onTap: () => _switchMode(m),
                  leading: Icon(_mode == m ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: _mode == m ? theme.colorScheme.primary : null),
                  title: Text(InterviewModes.labels[m]!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(InterviewModes.blurbs[m]!),
                ),
              ),
            ),
          const SizedBox(height: 14),
          if (!conversational) ...[
            const Eyebrow('Difficulty'),
            const SizedBox(height: 10),
            _chips({'easy': 'Easy', 'medium': 'Medium', 'hard': 'Hard', 'mixed': 'Mixed'}, _difficulty, (v) => setState(() => _difficulty = v)),
            const SizedBox(height: 18),
            const Eyebrow('Topics (optional)'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _dsaTopics)
                FilterChip(label: Text(t), selected: _topics.contains(t), onSelected: (on) => setState(() => on ? _topics.add(t) : _topics.remove(t))),
            ]),
            const SizedBox(height: 18),
            const Eyebrow('Problems'),
            const SizedBox(height: 10),
            _chips({1: '1', 2: '2', 3: '3', 4: '4'}, _dsaCount, (v) => setState(() => _dsaCount = v)),
            const SizedBox(height: 18),
            const Eyebrow('Time'),
            const SizedBox(height: 10),
            _chips({30: '30 min', 45: '45 min', 60: '60 min', 90: '90 min'}, _dsaMinutes, (v) => setState(() => _dsaMinutes = v)),
            const SizedBox(height: 18),
            const Eyebrow('Style'),
            const SizedBox(height: 10),
            _chips({'conversational': 'Conversational', 'timed': 'Timed challenge', 'mock': 'Mock interview'}, _style, (v) => setState(() => _style = v)),
          ] else ...[
            const Eyebrow('Preset or track (recommended)'),
            const SizedBox(height: 6),
            Text('A preset gives you real interview rounds. Without one, pick a format below.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            if (_catalog == null)
              const LinearProgressIndicator()
            else ...[
              for (final p in _catalog!.presets.where((p) => _mode == InterviewModes.job ? p.interviewMode == InterviewModes.job || p.rounds.every((r) => r.key == 'behavioral' || r.key == 'hr') : true))
                _PlanTile(plan: p, selected: _plan?.id == p.id && !_plan!.isTrack, onTap: () => _pick(p)),
              ExpansionTile(
                key: const Key('tracks'),
                title: const Text('Or choose a track'),
                tilePadding: EdgeInsets.zero,
                children: [
                  for (final g in groups.entries) ...[
                    Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(g.key, style: theme.textTheme.labelLarge))),
                    for (final t in g.value) _PlanTile(plan: t, selected: _plan?.id == t.id && _plan!.isTrack, onTap: () => _pick(t)),
                  ],
                ],
              ),
            ],
            if (_plan != null) ...[
              const SizedBox(height: 12),
              const Eyebrow('Your interview plan'),
              for (final r in _plan!.rounds)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _roundKeys == null || _roundKeys!.contains(r.key),
                  onChanged: (on) => setState(() {
                    final all = _plan!.rounds.map((x) => x.key).toList();
                    final cur = {...(_roundKeys ?? all.toSet())};
                    on == true ? cur.add(r.key) : cur.remove(r.key);
                    if (cur.isNotEmpty) _roundKeys = cur;
                    if (!_activeRounds.any((x) => x.key == _codingAfter)) _codingAfter = '';
                  }),
                  title: Text(r.label),
                  subtitle: Text('${r.count} question${r.count > 1 ? 's' : ''} · about ${r.minutes} min'),
                ),
              SwitchListTile(
                key: const Key('strict-rounds'),
                contentPadding: EdgeInsets.zero,
                value: _strictRounds,
                onChanged: (v) => setState(() => _strictRounds = v),
                title: const Text('Enforce round time limits'),
                subtitle: Text(_strictRounds
                    ? 'Each round ends when its minutes run out: the open question is graded on what you said, and questions you did not reach in that round score zero. The overall limit still applies.'
                    : 'Round minutes are a pacing guide; only the overall time limit is enforced.'),
              ),
              const SizedBox(height: 6),
              const Eyebrow('Experience level'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in _catalog?.experienceLevels ?? const <IdLabel>[])
                  ChoiceChip(label: Text(e.label), selected: _experience == e.id, onSelected: (_) => setState(() => _experience = e.id)),
              ]),
              const SizedBox(height: 14),
              const Eyebrow('Mode'),
              const SizedBox(height: 8),
              _chips({'simulation': 'Realistic simulation', 'coaching': 'Coaching (hints and notes)'}, _coachMode, (v) => setState(() => _coachMode = v)),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('coding-round'),
                contentPadding: EdgeInsets.zero,
                value: _coding,
                onChanged: (v) => setState(() => _coding = v),
                title: const Text('Add a coding round'),
                subtitle: const Text('Test-judged problems in the code editor, with their own clock. At the end or between two rounds; the interview waits while you code.'),
              ),
              if (_coding)
                Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  DropdownButton<int>(value: _codingCount, items: const [DropdownMenuItem(value: 1, child: Text('1 problem')), DropdownMenuItem(value: 2, child: Text('2 problems')), DropdownMenuItem(value: 3, child: Text('3 problems'))], onChanged: (v) => setState(() => _codingCount = v ?? 1)),
                  DropdownButton<int>(value: _codingMinutes, items: const [DropdownMenuItem(value: 30, child: Text('30 min')), DropdownMenuItem(value: 45, child: Text('45 min')), DropdownMenuItem(value: 60, child: Text('60 min'))], onChanged: (v) => setState(() => _codingMinutes = v ?? 45)),
                  SizedBox(width: double.infinity, child: DropdownButton<String>(
                    key: const Key('coding-when'),
                    isExpanded: true,
                    value: _codingAfter,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('After all rounds')),
                      for (final r in (_activeRounds.length > 1 ? _activeRounds.sublist(0, _activeRounds.length - 1) : const <CatalogRound>[]))
                        DropdownMenuItem(value: r.key, child: Text('After the ${r.label.toLowerCase()} round')),
                    ],
                    onChanged: (v) => setState(() => _codingAfter = v ?? ''),
                  )),
                ]),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('About the role (optional)'),
                children: [
                  TextField(controller: _company, decoration: const InputDecoration(labelText: 'Target company (recorded only)')),
                  TextField(controller: _years, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Years of experience')),
                  TextField(controller: _stack, decoration: const InputDecoration(labelText: 'Tech stack, comma separated')),
                  TextField(controller: _jd, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Job description (only technology names are used)')),
                  const SizedBox(height: 8),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(_resume == null ? 'Resume round (optional)' : 'Resume: ${_resume!.itemCount} item${_resume!.itemCount == 1 ? '' : 's'} kept'),
                children: [
                  Text('Upload a PDF resume. It is read on the server and never stored; remove anything wrong before you start.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _parsing ? null : _pickResume,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_parsing ? 'Reading…' : (_resume == null ? 'Upload PDF resume' : 'Replace resume')),
                    ),
                  ),
                  if (_resume != null) ...[
                    for (final h in _resume!.hints) Text(h, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final sk in List.of(_resume!.skills)) InputChip(label: Text(sk), onDeleted: () => setState(() => _resume!.skills.remove(sk))),
                    ]),
                    for (final e in List.of([..._resume!.projects, ..._resume!.experience]))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.title),
                        subtitle: e.details.isEmpty ? null : Text(e.details, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _resume!.projects.remove(e);
                            _resume!.experience.remove(e);
                          }),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Eyebrow('Format'),
              const SizedBox(height: 10),
              _chips(_mode == InterviewModes.job ? _jobFormats : _techFormats, _format, (v) => setState(() => _format = v)),
              const SizedBox(height: 18),
              const Eyebrow('Role'),
              const SizedBox(height: 10),
              _chips({for (final r in _roles) r: r}, _role, (v) => setState(() => _role = v)),
              const SizedBox(height: 18),
              const Eyebrow('Difficulty'),
              const SizedBox(height: 10),
              _chips({'easy': 'Easy', 'medium': 'Medium', 'hard': 'Hard'}, _difficulty, (v) => setState(() => _difficulty = v)),
            ],
          ],
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('start-interview'),
            onPressed: _busy ? null : _start,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Start ${InterviewModes.short[_mode]} interview'),
          ),
          const SizedBox(height: 10),
          Text(
            conversational
                ? 'A spoken-style interview: answer by typing or by voice. No code editor; questions match your role and plan.'
                : 'Solve problems in the code editor, run tests, and talk your approach through with the interviewer.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(140)),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.selected, required this.onTap});
  final CatalogPlan plan;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: selected ? 2 : 1),
      ),
      child: ListTile(
        key: Key('plan-${plan.isTrack ? 'track' : 'preset'}-${plan.id}'),
        selected: selected,
        title: Text(plan.label),
        subtitle: Text([
          if (plan.blurb != null) plan.blurb!,
          if (plan.rounds.isNotEmpty) plan.rounds.map((r) => r.label).join(' → '),
        ].join('\n'), maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: selected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
        onTap: onTap,
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
  bool _paused = false;
  bool _finishing = false;
  // The last chat message that has not been answered yet. Retrying the same
  // text reuses the same id, so a timed-out request is never answered twice.
  String? _pendingText;
  String? _pendingId;
  // Code drafts per question + language for this screen (kept when switching language or tabs).
  final _drafts = <String, String>{};
  bool _conversational = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _code.addListener(() {
      final q = _session?.currentIndex;
      if (q != null) _drafts['$q|$_language'] = _code.text;
    });
    _load();
  }

  /// Starter code for the open question in [lang]: the saved draft, else the problem's starter, else empty.
  String _starterFor(int qi, String lang, InterviewQuestion? q) => _drafts['$qi|$lang'] ?? q?.starterCode[lang] ?? '';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers do not run while the app is in the background, so re-read the
    // server's clock when the candidate comes back.
    if (state == AppLifecycleState.resumed && !_loading && !_conversational) _resync();
  }

  Future<void> _resync() async {
    try {
      final s = await context.read<InterviewService>().session(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _paused = s.status == 'paused';
        if (s.timeRemaining != null) _remaining = s.timeRemaining!;
      });
      if (s.status == 'completed') await _finish();
    } catch (_) {/* keep the local clock until the next successful sync */}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      // The server's interview mode picks the room: job and technical interviews never get the editor.
      if (roomKind(interviewMode: session.interviewMode, track: session.track) == 'conversational') {
        setState(() {
          _session = session;
          _conversational = true;
          _loading = false;
        });
        return;
      }
      if (session.status == 'completed') {
        _finishing = true;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => InterviewResultsScreen(sessionId: widget.sessionId)));
        return;
      }
      final q = session.questions.isNotEmpty ? session.questions[session.currentIndex.clamp(0, session.questions.length - 1)] : null;
      setState(() {
        _session = session;
        _remaining = session.timeRemaining ?? (session.duration ?? 30) * 60;
        _paused = session.status == 'paused';
        _loading = false;
        _messages.add(ChatMessage(
          fromMentor: true,
          text: q == null
              ? 'Let\'s begin. Tell me your approach.'
              : '${q.title}\n\n${q.description ?? ''}',
        ));
        final open = session.openQuestion;
        if (open != null && _code.text.isEmpty) _code.text = _starterFor(session.currentIndex, _language, open);
        // Bring back the conversation the server stored (survives a restart of the app).
        for (final m in session.messages) {
          final text = (m['content'] ?? '').toString();
          if (text.isEmpty) continue;
          _messages.add(ChatMessage(text: text, fromMentor: m['role'] == 'ai'));
        }
      });
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return _ticker?.cancel();
      if (_paused) return; // the server clock is frozen too
      if (_remaining <= 0) {
        _ticker?.cancel();
        _finish(); // time is up: the server enforces it as well
        return;
      }
      setState(() => _remaining--);
    });
  }

  String get _clock {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// True when [e] is the server saying the round is over (time up / closed)
  /// or paused, which needs a state change instead of an error message.
  bool _handleGuard(Object e) {
    if (e is! ApiException || e.statusCode != 409) return false;
    if (e.code == 'TURN_IN_PROGRESS' || e.code == 'SUBMIT_IN_PROGRESS') {
      _toast(e.message);
      return true;
    }
    final msg = e.message;
    if (msg.contains('Time is up')) {
      _finish();
      return true;
    }
    if (msg.contains('not active')) {
      if (_paused) {
        _toast('The interview is paused. Resume to continue.');
      } else {
        _finish();
      }
      return true;
    }
    return false;
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Ends the round without asking (time up, or the last question was submitted).
  Future<void> _finish() async {
    if (_finishing || !mounted) return;
    _finishing = true;
    _ticker?.cancel();
    final navigator = Navigator.of(context);
    try {
      await context.read<InterviewService>().end(widget.sessionId);
    } catch (_) {/* results may still be available */}
    if (!mounted) return;
    navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => InterviewResultsScreen(sessionId: widget.sessionId),
    ));
  }

  Future<void> _togglePause() async {
    if (_busy || _finishing) return;
    setState(() => _busy = true);
    try {
      final service = context.read<InterviewService>();
      final clock = _paused
          ? await service.resume(widget.sessionId)
          : await service.pause(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _paused = clock.status == 'paused';
        if (clock.timeRemaining != null) _remaining = clock.timeRemaining!;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (!_handleGuard(e)) _toast(e.toString());
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _busy || _paused) return;
    // The same text retried keeps its id; new text gets a new one.
    if (_pendingText != text) {
      _pendingText = text;
      _pendingId = newClientMessageId(text);
    }
    _chatController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, fromMentor: false));
      _busy = true;
    });
    _scrollChat();
    try {
      final reply = await context.read<InterviewService>().sendMessage(
            widget.sessionId,
            text,
            code: _code.text.trim().isEmpty ? null : _code.text,
            clientMessageId: _pendingId,
          );
      if (!mounted) return;
      _pendingText = null;
      _pendingId = null;
      setState(() {
        _messages.add(ChatMessage(text: reply, fromMentor: true));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Take the unanswered bubble back and restore the text, so the next
        // tap on Send retries the same message instead of adding a new one.
        if (_messages.isNotEmpty && !_messages.last.fromMentor) _messages.removeLast();
      });
      _chatController.text = text;
      if (!_handleGuard(e)) _toast(e.toString());
    }
    _scrollChat();
  }

  Future<void> _hint() async {
    if (_busy || _paused) return;
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
      if (!_handleGuard(e)) _toast(e.toString());
    }
    _scrollChat();
  }

  Future<void> _runCode() async {
    if (_busy || _paused || _code.text.trim().isEmpty) return;
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
      // Say what actually happened (e.g. the code runner is unavailable); never show it as a pass or a syntax error.
      if (!_handleGuard(e)) {
        if (mounted) setState(() => _lastFeedback = "Couldn't run your code: ${e is ApiException ? e.message : 'no connection to the server.'}");
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitCode() async {
    if (_busy || _paused || _code.text.trim().isEmpty) return;
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
          final idx = outcome.nextQuestionIndex ?? _session!.currentIndex + 1;
          // Use the question the server just chose (adaptive difficulty may
          // have replaced the one planned at the start).
          final questions = List<InterviewQuestion>.from(_session!.questions);
          final next = outcome.nextQuestion;
          if (next != null) {
            final replacement = InterviewQuestion.fromMap(next);
            if (idx < questions.length) {
              questions[idx] = replacement;
            } else {
              questions.add(replacement);
            }
          }
          _session = InterviewSession(
            id: _session!.id,
            timeRemaining: _remaining,
            duration: _session!.duration,
            currentIndex: idx,
            totalQuestions: _session!.totalQuestions,
            questions: questions,
            status: _session!.status,
            messages: _session!.messages,
            interviewMode: _session!.interviewMode,
            track: _session!.track,
            mode: _session!.mode,
            currentQuestion: idx < questions.length ? questions[idx] : null,
          );
          if (idx < questions.length) {
            final q = questions[idx];
            _messages.add(ChatMessage(text: '${q.title}\n\n${q.description ?? ''}', fromMentor: true));
            _code.text = _starterFor(idx, _language, q);
          }
        }
        _busy = false;
      });
      _scrollChat();
      // Submitting the last question ends the round, like the web app.
      if (outcome.hasNextQuestion == false) await _finish();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      if (!_handleGuard(e)) messenger.showSnackBar(SnackBar(content: Text(e.toString())));
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
    if (_conversational && _session != null) {
      return ConversationalRoom(sessionId: widget.sessionId, initial: _session);
    }
    final session = _session;
    final progress = (session != null && session.totalQuestions > 0)
        ? '${session.currentIndex + 1} / ${session.totalQuestions}'
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: Text('DSA interview · $_clock', style: theme.textTheme.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Question $progress', style: theme.textTheme.bodySmall)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_paused)
            Container(
              width: double.infinity,
              color: theme.colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Paused — the clock is stopped. Resume to continue.',
                  style: theme.textTheme.bodySmall),
            ),
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
                    onPressed: (_busy || _paused) ? null : _hint,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Hint'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _togglePause,
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 18),
                    label: Text(_paused ? 'Resume' : 'Pause'),
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
                            ? (Theme.of(context).colorScheme.outlineVariant)
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
                  enabled: !_paused,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(hintText: 'Explain your approach…'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: (_busy || _paused) ? null : _sendMessage,
                icon: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProblem(ThemeData theme) {
    final q = _session?.openQuestion;
    if (q == null) return const SizedBox.shrink();
    return ExpansionTile(
      key: const Key('problem-panel'),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: false,
      title: Text(q.title, style: theme.textTheme.titleMedium),
      subtitle: Wrap(spacing: 6, children: [
        if (q.difficulty != null) DifficultyBadge(level: q.difficulty!),
        for (final t in q.topics.take(2)) Chip(label: Text(t), visualDensity: VisualDensity.compact),
      ]),
      children: [
        Align(alignment: Alignment.centerLeft, child: SelectableText(q.description ?? '', style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))),
        for (final ex in q.examples)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: Text('Input: ${ex['input']}\nOutput: ${ex['output']}${ex['explanation'] != null ? '\n${ex['explanation']}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCode(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          _buildProblem(theme),
          Row(
            children: [
              Expanded(
                child: LanguagePicker(
                  languages: const ['python', 'javascript', 'java', 'cpp'],
                  value: _language,
                  onChanged: (v) => setState(() {
                    _language = v;
                    final s = _session;
                    if (s != null) _code.text = _starterFor(s.currentIndex, v, s.openQuestion);
                  }),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: (_busy || _paused) ? null : _runCode,
                child: const Text('Run'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (_busy || _paused) ? null : _submitCode,
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
                    color: Theme.of(context).colorScheme.outlineVariant),
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

class InterviewResultsScreen extends StatefulWidget {
  const InterviewResultsScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<InterviewResultsScreen> createState() => _InterviewResultsScreenState();
}

class _InterviewResultsScreenState extends State<InterviewResultsScreen> {
  Map<String, dynamic>? _data;
  Object? _error;
  Timer? _poll;
  int _tries = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<InterviewService>().results(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
      // The interviewer's written rubric is produced in the background; keep
      // checking (for about four minutes) until it is ready.
      _poll?.cancel();
      final report = d['report'] is Map ? d['report'] as Map : null;
      final semantic = d['semantic'] is Map ? d['semantic'] as Map : null;
      final stillWorking = d['rubricStatus'] == 'pending' ||
          (report != null && report['provisional'] == true) ||
          (semantic != null && semantic['pending'] is num && (semantic['pending'] as num) > 0);
      if (stillWorking && _tries < 40) {
        _poll = Timer(const Duration(seconds: 6), () {
          _tries++;
          _load();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  static const _rubricLabels = <String, String>{
    'problemSolving': 'Problem solving',
    'communication': 'Communication',
    'complexityReasoning': 'Complexity reasoning',
    'edgeCases': 'Edge cases',
  };

  Widget _rubricCard(ThemeData theme, Map<String, dynamic> rubric) {
    final rows = <Widget>[];
    _rubricLabels.forEach((key, label) {
      final d = rubric[key];
      if (d is! Map) return;
      final flagged = d['flagged'] == true || d['score'] is! num;
      final evidence = (d['evidence'] ?? '').toString();
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                Text(flagged ? 'Not enough evidence' : '${(d['score'] as num).round()}%',
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
            if (!flagged && evidence.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('"$evidence"',
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ));
    });
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interviewer rubric', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Test results decide correctness. These scores come from your conversation, with your own words quoted as evidence. AI scoring is approximate.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            ...rows,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;
    Widget body;
    if (_error != null && data == null) {
      body = EmptyState(message: '$_error');
    } else if (data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (data['report'] is Map) {
      body = _ReportView(data: data, sessionId: widget.sessionId, onReload: _load);
    } else {
      final rubric = data['rubric'];
      final pending = data['rubricStatus'] == 'pending';
      body = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Eyebrow('Written review'),
          const SizedBox(height: 14),
          if (pending)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your interviewer is still writing detailed feedback. Your test-based scores are final; this page updates by itself.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (pending) const SizedBox(height: 14),
          if (rubric is Map) _rubricCard(theme, Map<String, dynamic>.from(rubric)),
          if (rubric is Map) const SizedBox(height: 14),
          ..._renderSections(theme, data),
          const SizedBox(height: 30),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: body,
    );
  }

  List<Widget> _renderSections(ThemeData theme, Map<String, dynamic> data) {
    final widgets = <Widget>[];
    final reserved = {'_id', 'id', 'userId', 'sessionId', 'createdAt', 'updatedAt', '__v', 'rubric', 'rubricStatus', 'provisional'};

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

/// The evidence-based report (current servers): overall score, competencies with quotes, rounds, questions with
/// answers, diagrams and (after the interview) sample answers, plus the full-loop actions.
class _ReportView extends StatelessWidget {
  const _ReportView({required this.data, required this.sessionId, required this.onReload});
  final Map<String, dynamic> data;
  final String sessionId;
  final Future<void> Function() onReload;

  List<Map<String, dynamic>> _rows(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = Map<String, dynamic>.from(data['report'] as Map);
    final conversational = roomKind(interviewMode: data['interviewMode']?.toString(), track: data['track']?.toString()) == 'conversational';
    final overall = report['overallScore'];
    final provisional = report['provisional'] == true;
    final loop = data['loop'] is Map ? Map<String, dynamic>.from(data['loop'] as Map) : null;
    final competencies = _rows(report['competencies']);
    final rounds = _rows(report['rounds']);
    final questions = _rows(data['questions']);
    final strengths = _rows(report['strengths']);
    final improve = _rows(report['improvementAreas']);
    final plan = _rows(report['learningPlan']);

    Widget card(List<Widget> children, {Key? key}) => Card(
          key: key,
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        );

    return RefreshIndicator(
      onRefresh: onReload,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Eyebrow('${modeLabel(interviewMode: data['interviewMode']?.toString(), track: data['track']?.toString())} interview results'),
          const SizedBox(height: 12),
          if (provisional)
            card([
              Row(children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  conversational
                      ? 'Evaluation in progress. Your scores may still be refined; this page updates by itself.'
                      : 'Evaluation in progress. Your code results are final; conversation feedback is being written. This page updates by itself.',
                  style: theme.textTheme.bodySmall)),
              ]),
            ], key: const Key('evaluation-in-progress')),
          card([
            Row(children: [
              Text(overall is num ? '${overall.round()}' : '—', key: const Key('overall-score'),
                  style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                overall is num ? (provisional ? 'Provisional score' : 'Overall score') : (provisional ? 'Not available yet' : 'Not enough evidence for an overall score'),
                style: theme.textTheme.titleMedium)),
            ]),
            if (data['summary'] is String && (data['summary'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(data['summary'] as String, style: theme.textTheme.bodyMedium),
            ],
          ]),
          if (loop != null) _LoopActions(loop: loop, sessionId: sessionId, onReload: onReload),
          if (competencies.isNotEmpty)
            card([
              Text('Competency breakdown', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(conversational
                  ? 'Each score estimates how many key ideas your answers covered, plus depth and clarity, from your recorded answers.'
                  : 'Code correctness comes from graded tests. Other scores come from your own words, each with the evidence it is based on.',
                  style: theme.textTheme.bodySmall),
              for (final c in competencies) _Competency(c: c),
            ], key: const Key('competencies')),
          if (rounds.isNotEmpty)
            card([
              Text('Round by round', style: theme.textTheme.titleMedium),
              for (final r in rounds)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r['label'] ?? ''}'),
                  subtitle: Text('${r['answered'] ?? 0} of ${r['questions'] ?? 0} answered'),
                  trailing: Text(r['status'] == 'scored' ? '${r['score']}/100' : 'Not assessed', style: theme.textTheme.titleSmall),
                ),
            ]),
          if (strengths.isNotEmpty || improve.isNotEmpty)
            card([
              if (strengths.isNotEmpty) ...[
                Text('Strengths', style: theme.textTheme.titleMedium),
                for (final x in strengths) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• ${x['text']}')),
                const SizedBox(height: 10),
              ],
              if (improve.isNotEmpty) ...[
                Text('To improve', style: theme.textTheme.titleMedium),
                for (final x in improve) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• ${x['text']}')),
              ],
            ]),
          if (plan.isNotEmpty)
            card([
              Text('What to practise next', style: theme.textTheme.titleMedium),
              for (final x in plan)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text('${x['step']}. ${x['title']}: ${x['exercise'] ?? ''}')),
            ]),
          if (questions.isNotEmpty) ...[
            const Eyebrow('Questions'),
            const SizedBox(height: 8),
            for (var i = 0; i < questions.length; i++) _QuestionResult(index: i, q: questions[i], conversational: conversational),
          ],
          if (data['detailedFeedback'] is String && (data['detailedFeedback'] as String).isNotEmpty)
            card([Text('Feedback', style: theme.textTheme.titleMedium), const SizedBox(height: 6), SelectableText(data['detailedFeedback'] as String)]),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Competency extends StatelessWidget {
  const _Competency({required this.c});
  final Map<String, dynamic> c;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scored = c['status'] == 'scored' && c['score'] is num;
    final label = scored ? '${(c['score'] as num).round()}/${c['maxScore'] ?? 100}' : (c['status'] == 'pending' ? 'Pending' : 'Insufficient evidence');
    final evidence = c['evidence'] is List ? (c['evidence'] as List).whereType<Map>().toList() : const [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c['name'] ?? ''}', style: theme.textTheme.titleSmall)),
          Text(label, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ]),
        if (scored) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(value: ((c['score'] as num) / ((c['maxScore'] as num?) ?? 100)).clamp(0, 1).toDouble(), minHeight: 5, borderRadius: BorderRadius.circular(99)),
        ],
        if (c['feedback'] is String && (c['feedback'] as String).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(c['feedback'] as String, style: theme.textTheme.bodySmall)),
        for (final e in evidence)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${e['type'] == 'execution' ? 'Test result' : 'Your answer'}: "${e['excerpt'] ?? ''}"',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }
}

class _QuestionResult extends StatelessWidget {
  const _QuestionResult({required this.index, required this.q, required this.conversational});
  final int index;
  final Map<String, dynamic> q;
  final bool conversational;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = q['reached'] != false;
    List<String> list(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];
    final diagram = q['diagram'] is Map ? DiagramScene.fromMap(Map<String, dynamic>.from(q['diagram'] as Map)) : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${index + 1}. ${q['title'] ?? ''}', style: theme.textTheme.titleSmall)),
            Text(reached ? '${q['score'] ?? 0}/100' : 'Not reached', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ]),
          if (reached) ...[
            if (!conversational && q['testsTotal'] is num) Text('Tests: ${q['testsPassed'] ?? 0}/${q['testsTotal']}', style: theme.textTheme.bodySmall),
            if (q['feedback'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${q['feedback']}', style: theme.textTheme.bodySmall)),
            for (final x in list(q['strengths'])) Text('+ $x', style: theme.textTheme.bodySmall),
            for (final x in list(q['improvements'])) Text('– $x', style: theme.textTheme.bodySmall),
            if (q['answer'] is String && (q['answer'] as String).isNotEmpty)
              ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Your answer'), children: [Align(alignment: Alignment.centerLeft, child: SelectableText(q['answer'] as String))]),
            if (diagram != null && !diagram.isEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: true,
                title: const Text('Your architecture diagram'),
                children: [DiagramBoard(scene: diagram, readOnly: true)],
              ),
            if (q['sampleAnswer'] is String || list(q['keyIdeas']).isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(q['sampleAnswer'] is String ? 'A strong sample answer (for learning)' : 'Key ideas to cover'),
                children: [
                  if (q['sampleAnswer'] is String) Align(alignment: Alignment.centerLeft, child: SelectableText(q['sampleAnswer'] as String)),
                  for (final k in list(q['keyIdeas'])) Align(alignment: Alignment.centerLeft, child: Text('• $k')),
                ],
              ),
          ],
        ]),
      ),
    );
  }
}

/// Full loop: start / continue the coding round, or go back to the interview after a mid-interview coding round.
class _LoopActions extends StatelessWidget {
  const _LoopActions({required this.loop, required this.sessionId, required this.onReload});
  final Map<String, dynamic> loop;
  final String sessionId;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final general = loop['step'] == 'general';
    final codingId = loop['codingSessionId']?.toString();
    final codingOpen = loop['codingStatus'] == 'in-progress' || loop['codingStatus'] == 'paused';
    String? text;
    Widget? action;
    Future<void> open(String id) async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InterviewSessionScreen(sessionId: id)));
      await onReload();
    }

    if (general && loop['codingPlanned'] == true && codingId == null) {
      text = 'Next is a timed coding round. Your interview scores stay as they are.';
      action = FilledButton(
        key: const Key('start-coding-round'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final (id, notice) = await context.read<InterviewService>().startCodingRound(sessionId);
            if (notice != null) messenger.showSnackBar(SnackBar(content: Text(notice)));
            await open(id);
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.toString())));
          }
        },
        child: const Text('Start coding round'),
      );
    } else if (general && codingId != null && codingOpen) {
      text = 'Your coding round is still open.';
      action = FilledButton(onPressed: () => open(codingId), child: const Text('Continue coding round'));
    } else if (!general && loop['generalOpen'] == true && loop['generalSessionId'] != null) {
      text = 'Your interview is waiting: continue with the next round.';
      action = FilledButton(
        key: const Key('continue-interview'),
        onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => InterviewSessionScreen(sessionId: loop['generalSessionId'].toString()))),
        child: const Text('Continue the interview'),
      );
    } else {
      text = general ? 'Part 1 of your full interview. See the coding round in your history.' : 'Part 2 of your full interview: the coding round.';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: theme.colorScheme.primary.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Full interview', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(text, style: theme.textTheme.bodySmall),
          if (action != null) ...[const SizedBox(height: 10), action],
        ]),
      ),
    );
  }
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
