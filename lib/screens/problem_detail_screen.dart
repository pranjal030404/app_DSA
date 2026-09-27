import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

const _languageLabels = {
  'javascript': 'JavaScript',
  'python': 'Python',
  'java': 'Java',
  'cpp': 'C++',
};

class ProblemDetailScreen extends StatefulWidget {
  const ProblemDetailScreen({super.key, required this.slug, this.title});
  final String slug;
  final String? title;

  @override
  State<ProblemDetailScreen> createState() => _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends State<ProblemDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final Future<ProblemDetail> _future;

  String _language = 'javascript';
  final Map<String, TextEditingController> _codeByLanguage = {};
  RunResult? _result;
  bool _running = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthController>().problems.bySlug(widget.slug);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _codeByLanguage.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _codeController(ProblemDetail problem) {
    return _codeByLanguage.putIfAbsent(
      _language,
      () => TextEditingController(text: problem.starterCode[_language] ?? ''),
    );
  }

  void _switchLanguage(String lang) {
    setState(() {
      _language = lang;
      _result = null;
    });
  }

  Future<void> _execute({required bool submit}) async {
    if (_running || _submitting) return;
    final problem = await _future;
    final code = _codeByLanguage[_language]?.text ?? problem.starterCode[_language] ?? '';
    if (code.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write some code first.')),
      );
      return;
    }
    setState(() {
      if (submit) {
        _submitting = true;
      } else {
        _running = true;
      }
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = context.read<AuthController>().problems;
      final result = submit
          ? await service.submit(problem.slug, code, _language)
          : await service.run(problem.slug, code, _language);
      if (!mounted) return;
      setState(() => _result = result);
      _tabs.animateTo(1);
      messenger.showSnackBar(SnackBar(
        content: Text(result.allPassed
            ? 'Accepted — ${result.passedTests}/${result.totalTests} passed'
            : '${result.passedTests}/${result.totalTests} tests passed'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          if (submit) {
            _submitting = false;
          } else {
            _running = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Problem')),
      body: FutureBuilder<ProblemDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return EmptyState(
              message: '${snap.error ?? 'Problem not found.'}',
              onRetry: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      ProblemDetailScreen(slug: widget.slug, title: widget.title),
                ),
              ),
            );
          }
          final problem = snap.data!;
          final languages = problem.languages;
          if (!languages.contains(_language)) {
            // The default language has no starter code here — take the first
            // language the problem actually supports.
            _language = languages.first;
          }
          final codeController = _codeController(problem);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            problem.title,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 10),
                        DifficultyBadge(level: problem.difficulty, filled: true),
                      ],
                    ),
                    if (problem.topics.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in problem.topics.take(5))
                              Chip(label: Text(t, style: theme.textTheme.bodySmall)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabs,
                tabs: const [Tab(text: 'Description'), Tab(text: 'Code')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _DescriptionTab(problem: problem),
                    _CodeTab(
                      problem: problem,
                      state: this,
                      codeController: codeController,
                      onRun: () => _execute(submit: false),
                      onSubmit: () => _execute(submit: true),
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

/* ------------------------------------------------------------------ Description */

class _DescriptionTab extends StatelessWidget {
  const _DescriptionTab({required this.problem});
  final ProblemDetail problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.6);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(problem.description, style: bodyStyle),
        if (problem.inputFormat?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          Text('Input format', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(problem.inputFormat!, style: bodyStyle),
        ],
        if (problem.outputFormat?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          Text('Output format', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(problem.outputFormat!, style: bodyStyle),
        ],
        if (problem.sampleTestCases.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Sample cases', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < problem.sampleTestCases.length; i++)
            _CaseBlock(
              label: 'Example ${i + 1}',
              input: problem.sampleTestCases[i].input,
              output: problem.sampleTestCases[i].output,
            ),
        ],
        if (problem.constraints?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          Text('Constraints', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(problem.constraints!, style: bodyStyle),
        ],
        if (problem.hints.isNotEmpty) ...[
          const SizedBox(height: 18),
          _HintsPanel(hints: problem.hints),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _CaseBlock extends StatelessWidget {
  const _CaseBlock({required this.label, required this.input, required this.output});
  final String label;
  final String input;
  final String output;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = GoogleFonts.jetBrainsMonoTextTheme().bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Input', style: code?.copyWith(color: theme.colorScheme.primary)),
              Text(input, style: code),
              const SizedBox(height: 8),
              Text('Output', style: code?.copyWith(color: theme.colorScheme.primary)),
              Text(output, style: code),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progressive hints — revealed one at a time, never all at once.
class _HintsPanel extends StatefulWidget {
  const _HintsPanel({required this.hints});
  final List<String> hints;

  @override
  State<_HintsPanel> createState() => _HintsPanelState();
}

class _HintsPanelState extends State<_HintsPanel> {
  int _revealed = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hints', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < _revealed; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${widget.hints[i]}', style: theme.textTheme.bodyLarge),
              ),
            if (_revealed < widget.hints.length)
              TextButton.icon(
                onPressed: () => setState(() => _revealed++),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(_revealed == 0 ? 'Give a hint' : 'Another hint'),
              ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ Code tab */

class _CodeTab extends StatelessWidget {
  const _CodeTab({
    required this.problem,
    required this.state,
    required this.codeController,
    required this.onRun,
    required this.onSubmit,
  });

  final ProblemDetail problem;
  final _ProblemDetailScreenState state;
  final TextEditingController codeController;
  final VoidCallback onRun;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = state._running || state._submitting;
    final result = state._result;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: state._language,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Language'),
                  items: [
                    for (final lang in problem.languages)
                      DropdownMenuItem(
                        value: lang,
                        child: Text(_languageLabels[lang] ?? lang),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) state._switchLanguage(v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: busy ? null : onRun,
                child: state._running
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Run'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onSubmit,
                child: state._submitting
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                color: EmberColors.codeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EmberColors.lineStrong),
              ),
              child: TextField(
                controller: codeController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  height: 1.6,
                  color: EmberColors.codeText,
                ),
                cursorColor: EmberColors.gold,
                decoration: const InputDecoration(
                  hintText: 'Write your solution…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
          ),
        ),
        if (result != null)
          _ResultPanel(result: result),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});
  final RunResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final verdictColor = result.allPassed
        ? (isDark ? EmberColors.easy : EmberColors.easyLight)
        : (isDark ? EmberColors.hard : EmberColors.hardLight);

    // Fixed height: a flex child here would fight the editor's Expanded.
    return SizedBox(
      height: 200,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? EmberColors.surface : EmberColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: verdictColor.withAlpha(90)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(result.allPassed ? Icons.check_circle : Icons.cancel_outlined,
                    size: 18, color: verdictColor),
                const SizedBox(width: 8),
                Text(
                  result.allPassed ? 'Accepted' : 'Not accepted',
                  style: theme.textTheme.titleSmall?.copyWith(color: verdictColor),
                ),
                const Spacer(),
                Text(
                  '${result.passedTests}/${result.totalTests} passed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: result.results.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final r = result.results[i];
                  final mono = GoogleFonts.jetBrainsMonoTextTheme().bodySmall;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              r.passed ? Icons.check : Icons.close,
                              size: 14,
                              color: verdictColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Case ${i + 1}'
                                '${r.verdict != null ? ' · ${r.verdict}' : ''}'
                                '${r.runtime != null ? ' · ${r.runtime}' : ''}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        if (!r.passed) ...[
                          if (r.expected != null)
                            Text('expected: ${_short(r.expected!)}', style: mono),
                          if (r.actual != null)
                            Text('actual: ${_short(r.actual!)}', style: mono),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _short(String s) => s.length > 120 ? '${s.substring(0, 120)}…' : s;
}
