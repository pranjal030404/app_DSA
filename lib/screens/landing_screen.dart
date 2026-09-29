import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';
import 'problems_screen.dart';
import 'signup_screen.dart';
import 'theme_picker_screen.dart';

/// Signed-out home: the native counterpart of the web landing page.
/// Everything here is rendered in Flutter; the catalogue numbers come from
/// the public stats endpoint and fall back to nothing when it's unreachable.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final Future<ProblemStats> _stats;

  static const _features = <(IconData, String, String, String)>[
    (
      Icons.code,
      'Problem practice',
      'An editor that runs your code for real.',
      'Solve curated problems, run them against sample tests, then submit against hidden ones.',
    ),
    (
      Icons.route_outlined,
      'Roadmaps',
      'A plan, not a pile of problems.',
      'Describe your goal and level; get ordered milestones with tasks and resources to work through.',
    ),
    (
      Icons.terminal,
      'Playground',
      'Try an idea without a problem.',
      'Compile and run JavaScript, Python, Java, C++ and more, with your own stdin.',
    ),
    (
      Icons.forum_outlined,
      'AI mentor',
      'Hints, not answers.',
      'Ask for a nudge when you are stuck. The mentor is set up to guide rather than hand over code.',
    ),
    (
      Icons.record_voice_over_outlined,
      'Mock interviews',
      'Rehearse under a clock.',
      'Timed interview sessions that end with a written review of how you did.',
    ),
    (
      Icons.menu_book_outlined,
      'Resources',
      'Notes worth keeping.',
      'Community-written guides and cheat sheets, reviewed by other learners.',
    ),
  ];

  static const _steps = <(String, String)>[
    ('Choose a goal', 'Pick a role or company. A roadmap turns it into an ordered plan.'),
    ('Practice deliberately', 'Solve one problem at a time, in an editor that runs your code for real.'),
    ('Review mistakes', 'Read the failing case, ask for a hint, understand the fix.'),
    ('Measure progress', 'Track accuracy, topic coverage and consistency over time.'),
    ('Interview', 'Rehearse with a timed mock interview and a written review.'),
  ];

  static const _principles = <(String, String)>[
    (
      'Understand before you optimise',
      'Start with a working approach. Complexity analysis and pattern names come after you have felt why the brute force is slow.',
    ),
    (
      'Hints, not answers',
      'Stuck is where learning happens. Hints unlock one at a time, and the mentor nudges rather than hands over code.',
    ),
    (
      'Review is the work',
      'Every failed run shows the exact case that broke. Revisit it, explain it, and the same mistake stops recurring.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _stats = context.read<AuthController>().problems.publicStats();
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withAlpha(165);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const BrandMark(size: 30),
            const SizedBox(width: 10),
            Text('DSA Mentor', style: theme.textTheme.titleLarge),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Theme',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => _open(const ThemePickerScreen()),
          ),
          TextButton(
            onPressed: () => _open(const LoginScreen()),
            child: const Text('Sign in'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          // Hero ---------------------------------------------------------
          const Eyebrow('Deliberate DSA practice'),
          const SizedBox(height: 16),
          Text(
            'Get better at problem solving.',
            style: theme.textTheme.displaySmall?.copyWith(height: 1.1),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: AppPalette.of(context).gradient.createShader,
            child: Text(
              'One problem at a time.',
              style: theme.textTheme.displaySmall?.copyWith(height: 1.15),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Practice curated problems, understand why solutions work, and build the '
            'consistency required for technical interviews.',
            style: theme.textTheme.bodyLarge?.copyWith(color: muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _open(const SignupScreen()),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Start practicing — it\'s free'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _open(const _PublicProblemsScreen()),
            child: const Text('Browse problems'),
          ),
          const SizedBox(height: 28),

          // Live catalogue numbers --------------------------------------
          FutureBuilder<ProblemStats>(
            future: _stats,
            builder: (context, snap) {
              final s = snap.data;
              if (s == null || (s.total ?? 0) == 0) return const SizedBox.shrink();
              return Row(
                children: [
                  Expanded(child: StatCard(icon: Icons.code_rounded, label: 'Problems', value: '${s.total}')),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(icon: Icons.category_rounded, label: 'Topics', accent: AppPalette.of(context).tint(1), value: '${s.topicsCount ?? '—'}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      icon: Icons.whatshot_rounded,
                      label: 'Hard',
                      value: '${s.difficulties['Hard'] ?? 0}',
                      accent: AppPalette.of(context).hard,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const _CodeSample(),
          const SizedBox(height: 40),

          // Features -----------------------------------------------------
          const Eyebrow('What you get'),
          const SizedBox(height: 14),
          for (final (i, (icon, kicker, title, text)) in _features.indexed) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(icon: icon, color: AppPalette.of(context).tint(i), size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kicker.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.4, color: muted)),
                          const SizedBox(height: 4),
                          Text(title,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 30),

          // How it works -------------------------------------------------
          const Eyebrow('How it works'),
          const SizedBox(height: 14),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppPalette.of(context).gradient),
                    child: Text('${i + 1}',
                        style: TextStyle(color: AppPalette.of(context).onGradient, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_steps[i].$1,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_steps[i].$2, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Methodology --------------------------------------------------
          const Eyebrow('Learning methodology'),
          const SizedBox(height: 14),
          for (final (title, text) in _principles)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.5)),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Closing CTA --------------------------------------------------
          GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ready when you are.',
                    style: theme.textTheme.headlineSmall?.copyWith(color: AppPalette.of(context).onGradient)),
                const SizedBox(height: 8),
                Text('Create a free account and solve your first problem in a couple of minutes.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.of(context).onGradient.withAlpha(215))),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.of(context).onGradient,
                    foregroundColor: AppPalette.of(context).glow,
                  ),
                  onPressed: () => _open(const SignupScreen()),
                  child: const Text('Create account'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppPalette.of(context).onGradient),
                  onPressed: () => _open(const LoginScreen()),
                  child: const Text('I already have an account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Static, syntax-coloured Two Sum snippet — the hero's product preview.
class _CodeSample extends StatelessWidget {
  const _CodeSample();

  static const _lines = <List<(String?, String)>>[
    [('k', 'function'), (null, ' '), ('f', 'twoSum'), (null, '(nums, target) {')],
    [(null, '  '), ('k', 'const'), (null, ' seen = '), ('k', 'new'), (null, ' '), ('f', 'Map'), (null, '();')],
    [(null, '  '), ('k', 'for'), (null, ' ('), ('k', 'let'), (null, ' i = 0; i < nums.length; i++) {')],
    [(null, '    '), ('k', 'const'), (null, ' need = target - nums[i];')],
    [(null, '    '), ('k', 'if'), (null, ' (seen.'), ('f', 'has'), (null, '(need)) '), ('k', 'return'), (null, ' [seen.'), ('f', 'get'), (null, '(need), i];')],
    [(null, '    seen.'), ('f', 'set'), (null, '(nums[i], i);')],
    [(null, '  }')],
    [(null, '  '), ('k', 'return'), (null, ' [];')],
    [(null, '}')],
  ];

  @override
  Widget build(BuildContext context) {
    final mono = GoogleFonts.jetBrainsMono(fontSize: 12, height: 1.6, color: AppPalette.of(context).codeText);
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.of(context).codeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.of(context).codeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Text('two-sum.js', style: mono.copyWith(color: AppPalette.of(context).codeMuted)),
                const Spacer(),
                Icon(Icons.check_circle, size: 14, color: AppPalette.of(context).easy),
                const SizedBox(width: 6),
                Text('Accepted', style: mono.copyWith(color: AppPalette.of(context).easy)),
              ],
            ),
          ),
          Divider(height: 1, color: AppPalette.of(context).codeBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Text.rich(
              TextSpan(
                children: [
                  for (final (i, line) in _lines.indexed) ...[
                    if (i > 0) const TextSpan(text: '\n'),
                    for (final (kind, text) in line)
                      TextSpan(
                        text: text,
                        style: switch (kind) {
                          'k' => mono.copyWith(color: AppPalette.of(context).codeKeyword),
                          'f' => mono.copyWith(color: AppPalette.of(context).codeFunction),
                          _ => mono,
                        },
                      ),
                  ],
                ],
              ),
              style: mono,
            ),
          ),
        ],
      ),
    );
  }
}

/// The problem catalogue for signed-out visitors, with a back button and a
/// sign-up prompt pinned to the bottom.
class _PublicProblemsScreen extends StatelessWidget {
  const _PublicProblemsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const ProblemsScreen(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            ),
            child: const Text('Sign up to run and submit code'),
          ),
        ),
      ),
    );
  }
}
