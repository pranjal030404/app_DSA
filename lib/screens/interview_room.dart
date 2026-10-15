import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/content.dart';
import '../models/interview_mode.dart';
import '../services/feature_services.dart';
import '../services/interview_voice.dart';
import '../widgets/camera_tile.dart';
import 'interview_screens.dart';

/// Room colours: always dark, like the web room, whatever the app theme is.
class _R {
  static const bg = Color(0xFF0D0F12);
  static const surface = Color(0xFF15181D);
  static const raise = Color(0xFF1C2026);
  static const line = Color(0xFF2A2F37);
  static const text = Color(0xFFECEFF3);
  static const muted = Color(0xFFA3ACB9);
  static const accent = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
}

const _kindLabel = {
  'conceptual': 'Concept question',
  'system-design': 'System design',
  'behavioral': 'Behavioral / HR',
  'practical': 'Practical exercise',
};
const _kindTips = {
  'conceptual': 'Define it in one line, give a concrete example, then name a trade-off or limitation.',
  'system-design': 'Clarify requirements, estimate scale, sketch the main components, then discuss bottlenecks and trade-offs.',
  'behavioral': 'Use Situation, Action, Result and one lesson learned. Be specific about what you did.',
  'practical': 'Name the root cause, show the fix in a few lines, say how you would verify it, and mention an edge case. Nothing is executed.',
};

String _clock(int s) {
  final n = s < 0 ? 0 : s;
  return '${n ~/ 60}:${(n % 60).toString().padLeft(2, '0')}';
}

/// The conversational AI interview room (job and technical interviews). It never shows a problem statement,
/// a code editor or run/submit: those exist only in the DSA room. Everything shown comes from the session API.
class ConversationalRoom extends StatefulWidget {
  const ConversationalRoom({super.key, required this.sessionId, this.initial, this.voice});
  final String sessionId;
  final InterviewSession? initial;

  /// Injectable for tests.
  final InterviewVoice? voice;

  @override
  State<ConversationalRoom> createState() => _ConversationalRoomState();
}

class _ConversationalRoomState extends State<ConversationalRoom> with WidgetsBindingObserver {
  final _answer = TextEditingController();
  final _scroll = ScrollController();
  late final InterviewVoice _voice = widget.voice ?? InterviewVoice();

  InterviewSession? _s;
  final _messages = <Map<String, dynamic>>[];
  int _remaining = 0;
  int? _roundRemaining;
  bool _paused = false;
  bool _sending = false;
  bool _loading = true;
  bool _finishing = false;
  bool _captions = true;
  bool _showTip = false;
  bool _boardOpen = false;
  bool _syncingRound = false;
  String? _error;
  String? _pendingText;
  String? _pendingId;
  Timer? _ticker;
  DiagramScene _scene = DiagramScene();
  String _boardState = 'saved'; // saved | dirty | saving | error

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice.addListener(_onVoice);
    _voice.initSpeaker();
    if (widget.initial != null) {
      _apply(widget.initial!);
      _loading = false;
      _startTicker();
    } else {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) _load(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _voice.removeListener(_onVoice);
    if (widget.voice == null) _voice.dispose();
    _answer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onVoice() {
    if (mounted) setState(() {});
  }

  void _apply(InterviewSession s) {
    _s = s;
    _paused = s.status == 'paused';
    _remaining = s.timeRemaining ?? (s.duration ?? 30) * 60;
    _roundRemaining = s.roundTimerEnforced ? s.roundSecondsRemaining : null;
    _messages
      ..clear()
      ..addAll(s.messages.where((m) => (m['content'] ?? '').toString().isNotEmpty && (m['kind'] ?? 'chat') != 'system'));
    _scene = DiagramScene.fromMap(s.currentDiagram);
    _boardState = 'saved';
    _boardOpen = !_scene.isEmpty;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _error = null);
    try {
      final s = await context.read<InterviewService>().session(widget.sessionId);
      if (!mounted) return;
      if (s.status == 'completed' || s.roundTimerFinished) {
        await _finish(alreadyEnded: s.status == 'completed');
        return;
      }
      setState(() {
        _apply(s);
        _loading = false;
      });
      _ticker ?? _startTicker();
      _scrollDown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _s == null) _error = e is ApiException && e.statusCode == 404 ? 'This interview session was not found.' : 'Could not load the interview. Check your connection and try again.';
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused || _s == null) return;
      if (_remaining <= 0) {
        _ticker?.cancel();
        _finish();
        return;
      }
      setState(() {
        _remaining--;
        if (_roundRemaining != null && _roundRemaining! > 0) _roundRemaining = _roundRemaining! - 1;
      });
      // Round time is up: the server closes the round; re-read the session.
      if (_roundRemaining == 0 && !_syncingRound) {
        _syncingRound = true;
        _load(silent: true).whenComplete(() => _syncingRound = false);
      }
    });
  }

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Server guards (paused, time up, round over, busy, question moved on). True when handled.
  bool _guard(Object e) {
    if (e is! ApiException) return false;
    switch (e.code) {
      case 'ROUND_TIME_UP':
        _toast(e.message);
        _load(silent: true);
        return true;
      case 'INTERVIEW_TIME_UP':
        _finish();
        return true;
      case 'QUESTION_MISMATCH':
        _toast('The question changed. Reloading.');
        _load(silent: true);
        return true;
      case 'TURN_IN_PROGRESS':
      case 'SUBMIT_IN_PROGRESS':
        _toast(e.message);
        return true;
      case 'INTERVIEW_NOT_ACTIVE':
        if (_paused || _s?.holdFor != null) {
          _toast(_s?.holdFor != null ? 'Start or skip the coding round to continue.' : 'The interview is paused. Resume to continue.');
        } else {
          _finish();
        }
        return true;
    }
    return false;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _addAi(String text, {int? qi}) {
    _messages.add({'role': 'ai', 'content': text, 'qi': qi});
    _voice.speak(text);
  }

  /// Applies a "moved to the next question" payload (from Next/Skip or the interviewer moving on by itself).
  void _applyAdvance(Map<String, dynamic> adv) {
    final s = _s!;
    if (adv['coaching'] is Map) {
      final c = Map<String, dynamic>.from(adv['coaching'] as Map);
      final miss = (c['improvements'] is List ? (c['improvements'] as List).take(3).join('; ') : '');
      _addAi('Coach note: ${c['feedback'] ?? ''}${miss.isNotEmpty ? ' To strengthen it, cover: $miss.' : ''}');
    }
    final opening = (adv['openingMessage'] ?? '').toString();
    if (adv['hasNextQuestion'] == true || adv['nextQuestionIndex'] is num) {
      final idx = (adv['nextQuestionIndex'] as num?)?.toInt() ?? s.currentIndex + 1;
      final nq = adv['nextQuestion'] is Map ? InterviewQuestion.fromMap(Map<String, dynamic>.from(adv['nextQuestion'] as Map)) : null;
      final hold = adv['hold'] is Map ? (adv['hold'] as Map)['for']?.toString() : null;
      _s = InterviewSession(
        id: s.id, timeRemaining: _remaining, duration: s.duration, currentIndex: idx, totalQuestions: s.totalQuestions,
        questions: s.questions, status: hold != null ? 'paused' : s.status, messages: s.messages, interviewMode: s.interviewMode,
        track: s.track, role: s.role, mode: s.mode, rounds: s.rounds, roundTimerEnforced: s.roundTimerEnforced,
        roundSecondsRemaining: adv['roundSecondsRemaining'] is num ? (adv['roundSecondsRemaining'] as num).toInt() : null,
        holdFor: hold, holdCodingQuestions: s.holdCodingQuestions, holdCodingMinutes: s.holdCodingMinutes, currentQuestion: nq,
      );
      if (adv.containsKey('roundSecondsRemaining')) {
        _roundRemaining = adv['roundSecondsRemaining'] is num ? (adv['roundSecondsRemaining'] as num).toInt() : null;
      }
      if (hold != null) {
        _paused = true;
        // Fetch the coding round's size for the hold card.
        _load(silent: true);
      }
      _scene = DiagramScene();
      _boardState = 'saved';
      _boardOpen = false;
      if (opening.isNotEmpty) _addAi(opening, qi: idx);
    } else {
      if (opening.isNotEmpty) _addAi(opening);
      Future.delayed(const Duration(milliseconds: 1500), _finish);
    }
  }

  Future<void> _send() async {
    final text = _answer.text.trim();
    if (text.isEmpty || _sending || _paused) return;
    if (_voice.listening) await _voice.stopListening();
    if (!mounted) return;
    final service = context.read<InterviewService>();
    if (_pendingText != text) {
      _pendingText = text;
      _pendingId = newClientMessageId(text);
    }
    _answer.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text, 'qi': _s?.currentIndex});
      _sending = true;
    });
    _scrollDown();
    try {
      final reply = await service.sendTurn(widget.sessionId, text, clientMessageId: _pendingId);
      if (!mounted) return;
      _pendingText = null;
      _pendingId = null;
      setState(() {
        _sending = false;
        final r = (reply['response'] ?? '').toString();
        if (r.isNotEmpty) _addAi(r, qi: _s?.currentIndex);
      });
      if (reply['advance'] is Map) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() => _applyAdvance(Map<String, dynamic>.from(reply['advance'] as Map)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (_messages.isNotEmpty && _messages.last['role'] == 'user') _messages.removeLast();
      });
      _answer.text = text; // the next tap retries the same message (same id)
      if (!_guard(e)) _toast(e.toString());
    }
    _scrollDown();
  }

  bool get _answeredHere => _messages.any((m) => m['role'] == 'user' && m['qi'] == _s?.currentIndex) || !_scene.isEmpty;

  Future<bool> _confirm(String title, String body, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _next({bool skip = false}) async {
    final s = _s;
    if (s == null || _sending || _paused) return;
    if (!skip && !_answeredHere) {
      _toast('Answer the question first, or choose Skip.');
      return;
    }
    // An unsaved diagram is saved first, so it is graded with the answer.
    if (_boardState == 'dirty' || _boardState == 'error') {
      if (!await _saveBoard()) return;
    }
    if (!mounted) return;
    final last = s.currentIndex + 1 >= s.totalQuestions;
    final ok = await _confirm(
      skip ? 'Skip this question?' : (last ? 'Finish the interview?' : 'Next question?'),
      skip ? 'It will score zero.' : (last ? 'Your answers are graded and you see your results.' : "You can't change this answer afterwards."),
      skip ? 'Skip' : (last ? 'Finish' : 'Next'),
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      final out = await context.read<InterviewService>().answer(widget.sessionId, s.currentIndex, skip: skip);
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (out['hasNextQuestion'] == true) {
          _applyAdvance(out);
        }
      });
      if (out['hasNextQuestion'] != true) await _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      if (e is ApiException && e.code == 'NO_ANSWER') return _toast(e.message);
      if (!_guard(e)) _toast(e.toString());
    }
    _scrollDown();
  }

  Future<void> _hint() async {
    if (_sending || _paused) return;
    setState(() {
      _messages.add({'role': 'user', 'content': 'Can you give me a hint?', 'qi': _s?.currentIndex});
      _sending = true;
    });
    try {
      final h = await context.read<InterviewService>().hint(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _addAi(h);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (_messages.isNotEmpty && _messages.last['role'] == 'user') _messages.removeLast();
      });
      if (!_guard(e)) _toast(e.toString());
    }
    _scrollDown();
  }

  Future<void> _togglePause() async {
    if (_sending || _s?.holdFor != null) return;
    setState(() => _sending = true);
    try {
      final svc = context.read<InterviewService>();
      final clock = _paused ? await svc.resume(widget.sessionId) : await svc.pause(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _paused = clock.status == 'paused';
        if (clock.timeRemaining != null) _remaining = clock.timeRemaining!;
        _sending = false;
      });
      if (!_paused) _load(silent: true); // round clock after the pause
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      if (!_guard(e)) _toast(e.toString());
    }
  }

  Future<void> _end() async {
    if (!await _confirm('End the interview?', 'Your answers so far are scored and you see your results.', 'End interview')) return;
    await _finish();
  }

  Future<void> _finish({bool alreadyEnded = false}) async {
    if (_finishing || !mounted) return;
    _finishing = true;
    _ticker?.cancel();
    await _voice.stopSpeaking();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (!alreadyEnded) {
      try {
        await context.read<InterviewService>().end(widget.sessionId);
      } catch (_) {/* results may still be available */}
    }
    nav.pushReplacement(MaterialPageRoute(builder: (_) => InterviewResultsScreen(sessionId: widget.sessionId)));
  }

  Future<void> _startCoding() async {
    setState(() => _sending = true);
    try {
      final (id, notice) = await context.read<InterviewService>().startCodingRound(widget.sessionId);
      if (!mounted) return;
      if (notice != null) _toast(notice);
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InterviewSessionScreen(sessionId: id)));
      if (mounted) {
        setState(() => _sending = false);
        _load(silent: true); // the coding round may have released the hold
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _toast(e.toString());
    }
  }

  Future<void> _skipCoding() async {
    if (!await _confirm('Skip the coding round?', 'Your full-interview score will be based on the interview rounds only.', 'Skip')) return;
    if (!mounted) return;
    try {
      await context.read<InterviewService>().skipCodingRound(widget.sessionId);
      await _load(silent: true);
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<bool> _saveBoard() async {
    final s = _s;
    if (s == null) return false;
    setState(() => _boardState = 'saving');
    try {
      final saved = await context.read<InterviewService>().saveDiagram(widget.sessionId, s.currentIndex, _scene.isEmpty ? null : _scene.toMap());
      if (!mounted) return false;
      setState(() {
        _scene = DiagramScene.fromMap(saved);
        _boardState = 'saved';
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _boardState = 'error');
      if (!_guard(e)) _toast(e.toString());
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: _R.bg, body: Center(child: CircularProgressIndicator()));
    }
    if (_s == null) {
      return Scaffold(
        backgroundColor: _R.bg,
        appBar: AppBar(backgroundColor: _R.bg, foregroundColor: _R.text, title: const Text('Interview')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error ?? 'Could not load the interview.', textAlign: TextAlign.center, style: const TextStyle(color: _R.text)),
              const SizedBox(height: 16),
              FilledButton(onPressed: () {
                setState(() => _loading = true);
                _load();
              }, child: const Text('Try again')),
            ]),
          ),
        ),
      );
    }
    final s = _s!;
    final q = s.openQuestion;
    final hold = s.holdFor == 'coding';
    final ri = s.roundIndex;
    final round = ri >= 0 ? s.rounds[ri] : null;
    final aiState = _paused
        ? (hold ? 'Waiting for the coding round' : 'Paused')
        : _voice.speaking
            ? 'Speaking'
            : _sending
                ? 'Thinking'
                : _voice.listening
                    ? 'Listening'
                    : 'Waiting for your answer';
    final lastAi = _messages.lastWhere((m) => m['role'] == 'ai', orElse: () => const {});
    final hintsAllowed = s.mode != 'simulation';
    final duration = (s.duration ?? 0) * 60;
    final elapsed = (duration - _remaining).clamp(0, duration);
    final title = InterviewModes.labels[s.interviewMode] ?? 'Technical interview';

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(primary: _R.accent, onPrimary: Color(0xFF052E22), surface: _R.surface, error: _R.danger),
        scaffoldBackgroundColor: _R.bg,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _R.bg,
          foregroundColor: _R.text,
          titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Question ${s.currentIndex + 1} of ${s.totalQuestions}${round != null ? ' · Round ${ri + 1}/${s.rounds.length}: ${round.label}' : ''}',
                key: const Key('room-progress'), style: const TextStyle(fontSize: 11, color: _R.muted)),
          ]),
          actions: [
            IconButton(
              tooltip: _captions ? 'Hide captions' : 'Show captions',
              onPressed: () => setState(() => _captions = !_captions),
              icon: Icon(_captions ? Icons.closed_caption : Icons.closed_caption_off),
            ),
            IconButton(
              tooltip: _paused ? 'Resume interview' : 'Pause interview',
              onPressed: (hold || _sending) ? null : _togglePause,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            ),
            TextButton(onPressed: _end, child: const Text('End', style: TextStyle(color: _R.danger))),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Wraps on narrow phones instead of overflowing.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    _Chip(hold ? 'Coding round next' : (_paused ? 'Paused' : 'Live'), color: _paused ? _R.warn : _R.accent),
                    Semantics(
                      label: 'Time remaining ${_clock(_remaining)}, elapsed ${_clock(elapsed)}',
                      child: Text('${_clock(_remaining)} · elapsed ${_clock(elapsed)}', key: const Key('room-timer'),
                          style: TextStyle(color: _remaining < 300 ? _R.warn : _R.text, fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                    if (_roundRemaining != null)
                      Semantics(
                        label: 'Round time remaining ${_clock(_roundRemaining!)}',
                        child: _Chip('round ${_clock(_roundRemaining!)}', key: const Key('round-timer'), color: _roundRemaining! < 60 ? _R.warn : _R.muted),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: s.totalQuestions > 0 ? (s.currentIndex + 1) / s.totalQuestions : 0,
                  color: _R.accent,
                  backgroundColor: _R.line,
                  minHeight: 3,
                  semanticsLabel: 'Interview progress',
                ),
              ]),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _InterviewerTile(state: aiState, speaking: _voice.speaking, thinking: _sending && !_paused)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CameraSelfView(
                        highlight: _voice.listening,
                        statusLine: _paused ? 'Paused' : (_voice.listening ? 'Listening to you' : 'Your turn'),
                      ),
                    ),
                  ]),
                  if (_captions && lastAi['content'] != null)
                    Container(
                      key: const Key('captions'),
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12), border: Border.all(color: _R.line)),
                      child: Semantics(liveRegion: true, child: Text(lastAi['content'].toString(), style: const TextStyle(color: _R.text, height: 1.45))),
                    ),
                  if (_voice.unavailableReason != null || _voice.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_voice.lastError ?? _voice.unavailableReason!, style: const TextStyle(color: _R.warn, fontSize: 12)),
                    ),
                  const SizedBox(height: 10),
                  _QuestionCard(
                    hold: hold,
                    question: q,
                    showTip: _showTip,
                    onTip: () => setState(() => _showTip = !_showTip),
                    canDraw: !hold && q?.kind == 'system-design',
                    boardOpen: _boardOpen,
                    onBoard: () => setState(() => _boardOpen = !_boardOpen),
                  ),
                  if (!hold && q?.kind == 'system-design' && _boardOpen)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: DiagramBoard(
                        key: ValueKey('board-${s.currentIndex}'),
                        scene: _scene,
                        saveState: _boardState,
                        onChanged: () => setState(() => _boardState = 'dirty'),
                        onSave: _saveBoard,
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text('TRANSCRIPT', style: TextStyle(color: _R.muted, fontSize: 11, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  for (final m in _messages) _Bubble(fromAi: m['role'] == 'ai', text: m['content'].toString()),
                  if (_sending) const _Bubble(fromAi: true, text: 'Thinking…', typing: true),
                ],
              ),
            ),
            if (hold)
              _HoldCard(
                questions: s.holdCodingQuestions ?? 1,
                minutes: s.holdCodingMinutes ?? 45,
                busy: _sending,
                onStart: _startCoding,
                onSkip: _skipCoding,
              )
            else
              _Composer(
                controller: _answer,
                enabled: !_paused && !_sending,
                voice: _voice,
                hintsAllowed: hintsAllowed,
                isLast: s.currentIndex + 1 >= s.totalQuestions,
                onSend: _send,
                onHint: _hint,
                onNext: () => _next(),
                onSkip: () => _next(skip: true),
                onListen: () => _voice.listening
                    ? _voice.stopListening()
                    : _voice.startListening((t) {
                        _answer.text = t;
                        _answer.selection = TextSelection.collapsed(offset: t.length);
                      }),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {super.key, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withAlpha(120))),
        child: Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 10, letterSpacing: 1)),
      );
}

class _InterviewerTile extends StatelessWidget {
  const _InterviewerTile({required this.state, required this.speaking, required this.thinking});
  final String state;
  final bool speaking;
  final bool thinking;
  @override
  Widget build(BuildContext context) {
    final border = speaking ? _R.accent : (thinking ? _R.warn : _R.line);
    return Semantics(
      label: 'Interviewer. $state',
      liveRegion: true,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_R.raise, _R.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 2),
          ),
          child: Stack(children: [
            const Center(child: CircleAvatar(radius: 28, backgroundColor: Color(0xFF232931), child: Icon(Icons.smart_toy_outlined, color: _R.accent, size: 30))),
            Positioned(
              left: 10,
              bottom: 8,
              right: 8,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Interviewer', style: TextStyle(color: _R.text, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(state, key: const Key('ai-state'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _R.muted, fontSize: 11)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.hold,
    required this.question,
    required this.showTip,
    required this.onTip,
    required this.canDraw,
    required this.boardOpen,
    required this.onBoard,
  });
  final bool hold;
  final InterviewQuestion? question;
  final bool showTip;
  final VoidCallback onTip;
  final bool canDraw;
  final bool boardOpen;
  final VoidCallback onBoard;

  @override
  Widget build(BuildContext context) {
    final kind = question?.kind;
    return Container(
      key: const Key('question-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _R.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _R.line)),
      child: hold
          ? const Text('The next round starts after the coding round. Its first question is asked when you come back.',
              style: TextStyle(color: _R.muted, height: 1.45))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((_kindLabel[kind] ?? 'Question').toUpperCase(), style: const TextStyle(color: _R.muted, fontSize: 11, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              SelectableText(question?.description ?? '', style: const TextStyle(color: _R.text, height: 1.5)),
              Wrap(spacing: 4, children: [
                if (canDraw)
                  TextButton.icon(onPressed: onBoard, icon: const Icon(Icons.account_tree_outlined, size: 16), label: Text(boardOpen ? 'Hide diagram board' : 'Draw the architecture')),
                TextButton.icon(onPressed: onTip, icon: const Icon(Icons.lightbulb_outline, size: 16), label: const Text('How to answer')),
              ]),
              if (showTip)
                Text('${_kindTips[kind] ?? _kindTips['conceptual']} Answer by typing or by voice. The interviewer asks a few follow-ups, then moves on; use Next to move on sooner.',
                    style: const TextStyle(color: _R.muted, fontSize: 13, height: 1.45)),
            ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromAi, required this.text, this.typing = false});
  final bool fromAi;
  final String text;
  final bool typing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 12, backgroundColor: _R.raise, child: Icon(fromAi ? Icons.smart_toy_outlined : Icons.person_outline, size: 14, color: fromAi ? _R.accent : const Color(0xFF93C5FD))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fromAi ? 'INTERVIEWER' : 'YOU', style: const TextStyle(color: _R.muted, fontSize: 10, letterSpacing: 1)),
              const SizedBox(height: 2),
              Container(
                padding: fromAi ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: fromAi ? null : BoxDecoration(color: _R.raise, borderRadius: BorderRadius.circular(12)),
                child: Text(text, key: fromAi ? const Key('ai-message') : const Key('user-message'),
                    style: TextStyle(color: typing ? _R.muted : _R.text, height: 1.5)),
              ),
            ]),
          ),
        ]),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.voice,
    required this.hintsAllowed,
    required this.isLast,
    required this.onSend,
    required this.onHint,
    required this.onNext,
    required this.onSkip,
    required this.onListen,
  });
  final TextEditingController controller;
  final bool enabled;
  final InterviewVoice voice;
  final bool hintsAllowed;
  final bool isLast;
  final VoidCallback onSend;
  final VoidCallback onHint;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(color: _R.surface, border: Border(top: BorderSide(color: _R.line))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              key: const Key('answer-box'),
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              style: const TextStyle(color: _R.text),
              decoration: InputDecoration(
                hintText: enabled ? 'Type your answer…' : 'Paused',
                counterText: '',
                filled: true,
                fillColor: _R.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: voice.listening ? 'Stop microphone' : 'Answer by voice',
            onPressed: enabled ? onListen : null,
            icon: Icon(voice.listening ? Icons.mic_off : Icons.mic),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => IconButton.filled(
              key: const Key('send'),
              tooltip: 'Send',
              onPressed: enabled && v.text.trim().isNotEmpty ? onSend : null,
              icon: const Icon(Icons.send, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            if (voice.ttsAvailable)
              IconButton(
                tooltip: voice.speakReplies ? 'Mute interviewer voice' : 'Read interviewer replies aloud',
                onPressed: () => voice.setSpeakReplies(!voice.speakReplies),
                icon: Icon(voice.speakReplies ? Icons.volume_up : Icons.volume_off, color: voice.speakReplies ? _R.accent : _R.muted),
              ),
            if (voice.speakReplies)
              IconButton(
                tooltip: voice.speaking ? 'Stop speaking' : 'Replay the last reply',
                onPressed: voice.speaking ? voice.stopSpeaking : voice.replay,
                icon: Icon(voice.speaking ? Icons.stop : Icons.replay, color: _R.muted),
              ),
            if (hintsAllowed) TextButton(onPressed: enabled ? onHint : null, child: const Text('Request hint')),
            TextButton.icon(onPressed: enabled ? onSkip : null, icon: const Icon(Icons.skip_next, size: 16), label: const Text('Skip')),
            FilledButton.tonalIcon(
              onPressed: enabled ? onNext : null,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(isLast ? 'Finish interview' : 'Next question'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _HoldCard extends StatelessWidget {
  const _HoldCard({required this.questions, required this.minutes, required this.busy, required this.onStart, required this.onSkip});
  final int questions;
  final int minutes;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('hold-card'),
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _R.accent.withAlpha(18), borderRadius: BorderRadius.circular(14), border: Border.all(color: _R.accent.withAlpha(110))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Row(children: [Icon(Icons.data_object, color: _R.accent, size: 18), SizedBox(width: 6), Text('Coding round', style: TextStyle(color: _R.text, fontWeight: FontWeight.w600))]),
          const SizedBox(height: 6),
          Text('$questions problem${questions > 1 ? 's' : ''} in the code editor, judged by tests, with its own $minutes-minute clock. This interview\'s clock is stopped until you come back.',
              style: const TextStyle(color: _R.muted, height: 1.45)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            FilledButton(onPressed: busy ? null : onStart, child: const Text('Start coding round')),
            OutlinedButton(onPressed: busy ? null : onSkip, child: const Text('Skip coding round')),
          ]),
        ]),
      );
}

/// System-design board: components and connections, edited with simple controls (keyboard / screen-reader friendly)
/// and drawn as boxes and arrows. Only its text form is graded; the board shows that text too.
class DiagramBoard extends StatefulWidget {
  const DiagramBoard({super.key, required this.scene, this.readOnly = false, this.saveState = 'saved', this.onChanged, this.onSave});
  final DiagramScene scene;
  final bool readOnly;
  final String saveState;
  final VoidCallback? onChanged;
  final Future<bool> Function()? onSave;

  @override
  State<DiagramBoard> createState() => _DiagramBoardState();
}

class _DiagramBoardState extends State<DiagramBoard> {
  final _label = TextEditingController();
  final _edgeLabel = TextEditingController();
  String _kind = 'service';
  String? _from;
  String? _to;

  @override
  void dispose() {
    _label.dispose();
    _edgeLabel.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sc = widget.scene;
    final names = {for (final n in sc.nodes) n.id: n.label};
    final text = sc.toText();
    final dark = !widget.readOnly;
    final fg = dark ? _R.text : Theme.of(context).colorScheme.onSurface;
    final muted = dark ? _R.muted : Theme.of(context).colorScheme.onSurface.withAlpha(150);
    return Container(
      key: const Key('diagram-board'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? _R.surface : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? _R.line : Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          label: text.isEmpty ? 'Empty architecture diagram' : text,
          child: SizedBox(
            height: 200,
            child: CustomPaint(painter: _DiagramPainter(sc, dark: dark)),
          ),
        ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('component-name'),
                controller: _label,
                maxLength: DiagramScene.maxLabel,
                style: TextStyle(color: fg),
                decoration: const InputDecoration(labelText: 'Component', hintText: 'e.g. API gateway', counterText: '', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              key: const Key('component-type'),
              value: _kind,
              dropdownColor: _R.raise,
              style: TextStyle(color: fg),
              items: [for (final e in DiagramScene.kinds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _kind = v ?? 'service'),
            ),
            IconButton(
              key: const Key('add-component'),
              tooltip: 'Add component',
              onPressed: () {
                if (sc.addNode(_label.text, _kind)) {
                  _label.clear();
                  _changed();
                }
              },
              icon: const Icon(Icons.add_box_outlined),
            ),
          ]),
          if (sc.nodes.length >= 2)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              DropdownButton<String>(
                key: const Key('edge-from'),
                hint: const Text('From'),
                value: _from,
                dropdownColor: _R.raise,
                style: TextStyle(color: fg),
                items: [for (final n in sc.nodes) DropdownMenuItem(value: n.id, child: Text(n.label))],
                onChanged: (v) => setState(() => _from = v),
              ),
              Icon(Icons.arrow_forward, size: 16, color: muted),
              DropdownButton<String>(
                key: const Key('edge-to'),
                hint: const Text('To'),
                value: _to,
                dropdownColor: _R.raise,
                style: TextStyle(color: fg),
                items: [for (final n in sc.nodes) DropdownMenuItem(value: n.id, child: Text(n.label))],
                onChanged: (v) => setState(() => _to = v),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  key: const Key('edge-label'),
                  controller: _edgeLabel,
                  maxLength: DiagramScene.maxLabel,
                  style: TextStyle(color: fg),
                  decoration: const InputDecoration(hintText: 'label (optional)', counterText: '', isDense: true),
                ),
              ),
              TextButton(
                key: const Key('connect'),
                onPressed: () {
                  if (_from != null && _to != null && sc.addEdge(_from!, _to!, _edgeLabel.text)) {
                    _edgeLabel.clear();
                    _changed();
                  }
                },
                child: const Text('Connect'),
              ),
            ]),
          for (final n in List.of(sc.nodes))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${n.label} (${DiagramScene.kinds[n.kind]})', style: TextStyle(color: fg, fontSize: 13)),
              trailing: IconButton(tooltip: 'Remove ${n.label}', icon: Icon(Icons.delete_outline, size: 18, color: muted), onPressed: () {
                sc.removeNode(n.id);
                if (_from == n.id) _from = null;
                if (_to == n.id) _to = null;
                _changed();
              }),
            ),
          for (final e in List.of(sc.edges))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${names[e.from]} → ${names[e.to]}${e.label.isNotEmpty ? ' (${e.label})' : ''}', style: TextStyle(color: fg, fontSize: 13)),
              trailing: IconButton(tooltip: 'Remove connection', icon: Icon(Icons.delete_outline, size: 18, color: muted), onPressed: () {
                sc.edges.remove(e);
                _changed();
              }),
            ),
          Row(children: [
            FilledButton.icon(
              key: const Key('save-diagram'),
              onPressed: widget.saveState == 'saving' ? null : () => widget.onSave?.call(),
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save diagram'),
            ),
            const SizedBox(width: 10),
            Text(
              const {'saved': 'Saved', 'dirty': 'Unsaved changes', 'saving': 'Saving…', 'error': "Couldn't save. Try again."}[widget.saveState] ?? '',
              key: const Key('diagram-status'),
              style: TextStyle(color: widget.saveState == 'saved' ? muted : _R.warn, fontSize: 12),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        Text('What the interviewer reads: ${text.isEmpty ? 'nothing yet' : text}', key: const Key('diagram-text'), style: TextStyle(color: muted, fontSize: 12, height: 1.4)),
      ]),
    );
  }
}

class _DiagramPainter extends CustomPainter {
  _DiagramPainter(this.scene, {required this.dark});
  final DiagramScene scene;
  final bool dark;

  static const bw = 120.0;
  static const bh = 44.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (scene.nodes.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: 'Add components below, then connect them.', style: TextStyle(color: dark ? _R.muted : Colors.grey, fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2 - 8));
      return;
    }
    // Scale the stored 800x440-ish layout into the available box.
    double maxX = 0, maxY = 0;
    for (final n in scene.nodes) {
      if (n.x + bw > maxX) maxX = n.x + bw;
      if (n.y + bh > maxY) maxY = n.y + bh;
    }
    final scale = [size.width / (maxX + 10), size.height / (maxY + 10), 1.0].reduce((a, b) => a < b ? a : b);
    canvas.save();
    canvas.scale(scale);
    final byId = {for (final n in scene.nodes) n.id: n};
    final edgePaint = Paint()
      ..color = const Color(0xFF8B95A3)
      ..strokeWidth = 1.8;
    for (final e in scene.edges) {
      final a = byId[e.from];
      final b = byId[e.to];
      if (a == null || b == null) continue;
      final p = Offset(a.x + bw / 2, a.y + bh / 2);
      final q = Offset(b.x + bw / 2, b.y + bh / 2);
      final d = q - p;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final tx = (bw / 2) / (d.dx.abs() < 1e-6 ? 1e-6 : d.dx.abs());
      final ty = (bh / 2) / (d.dy.abs() < 1e-6 ? 1e-6 : d.dy.abs());
      final t = (tx < ty ? tx : ty).clamp(0.0, 1.0);
      final end = q - d * t;
      canvas.drawLine(p, end, edgePaint);
      final dir = d / len;
      final left = end - dir * 9 + Offset(-dir.dy, dir.dx) * 5;
      final right = end - dir * 9 - Offset(-dir.dy, dir.dx) * 5;
      canvas.drawPath(Path()..moveTo(end.dx, end.dy)..lineTo(left.dx, left.dy)..lineTo(right.dx, right.dy)..close(), Paint()..color = const Color(0xFF8B95A3));
      if (e.label.isNotEmpty) {
        final tp = TextPainter(text: TextSpan(text: e.label, style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 10)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, (p + end) / 2 - Offset(tp.width / 2, 14));
      }
    }
    for (final n in scene.nodes) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(n.x, n.y, bw, bh), const Radius.circular(10));
      canvas.drawRRect(r, Paint()..color = dark ? const Color(0xEB1E242C) : const Color(0xFFF7F6F2));
      final stroke = switch (n.kind) {
        'database' || 'storage' => const Color(0xFF60A5FA),
        'cache' => const Color(0xFFF59E0B),
        'queue' => const Color(0xFFC084FC),
        _ => const Color(0xFF6B7280),
      };
      canvas.drawRRect(r, Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
      final label = n.label.length > 16 ? '${n.label.substring(0, 15)}…' : n.label;
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: dark ? _R.text : const Color(0xFF1F2328), fontSize: 12, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: bw - 8);
      tp.paint(canvas, Offset(n.x + (bw - tp.width) / 2, n.y + 7));
      final kp = TextPainter(
        text: TextSpan(text: DiagramScene.kinds[n.kind] ?? 'Other', style: const TextStyle(color: Color(0xFF9AA4B2), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: bw - 8);
      kp.paint(canvas, Offset(n.x + (bw - kp.width) / 2, n.y + 25));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagramPainter old) => true;
}
