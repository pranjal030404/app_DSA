import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'achievements_screen.dart';
import 'content_screens.dart';
import 'interview_screens.dart';
import 'problems_screen.dart';
import 'roadmaps_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HomeData> _load() async {
    final problems = context.read<AuthController>().problems;
    final stats = await problems.publicStats();
    return HomeData(stats);
  }

  void _reload() => setState(() => _future = _load());

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthController>().user;
    final name = (user?.username?.isNotEmpty ?? false) ? user!.username! : 'there';

    final actions = <(IconData, String, String, Widget)>[
      (Icons.route_rounded, 'Roadmaps', 'Your plan', const RoadmapsScreen()),
      (Icons.record_voice_over_rounded, 'Interviews', 'Mock sessions', const InterviewDashboardScreen()),
      (Icons.insights_rounded, 'Progress', 'Analytics', const AnalyticsScreen()),
      (Icons.emoji_events_rounded, 'Achievements', 'Badges', const AchievementsScreen()),
      (Icons.menu_book_rounded, 'Resources', 'Guides', const ResourcesScreen()),
      (Icons.help_rounded, 'Help center', 'FAQs', const HelpScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 64,
        title: Row(
          children: [
            const BrandMark(size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting(),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150))),
                  Text(name, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _StreakPill(days: user?.streak ?? 0),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<HomeData>(
          future: _future,
          builder: (context, snap) {
            final stats = snap.data?.stats;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                // Hero: continue practicing ---------------------------------
                GradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: ShapeDecoration(
                          color: AppPalette.of(context).onGradient.withAlpha(40),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(user?.currentLevel ?? 'Beginner',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Keep the momentum going.',
                        style: theme.textTheme.headlineSmall?.copyWith(color: AppPalette.of(context).onGradient),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'One focused problem today beats five skimmed ones.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.of(context).onGradient.withAlpha(215)),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.of(context).onGradient,
                          foregroundColor: AppPalette.of(context).glow,
                        ),
                        onPressed: () => ProblemsScreen.openProblemsTab(context),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Continue practicing'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Personal stats --------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.check_circle_rounded,
                        label: 'Solved',
                        value: '${user?.problemsSolved ?? 0}',
                        accent: AppPalette.of(context).easy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        icon: Icons.track_changes_rounded,
                        label: 'Accuracy',
                        value: '${user?.accuracy ?? 0}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        icon: Icons.local_fire_department_rounded,
                        label: 'Streak',
                        value: '${user?.streak ?? 0}d',
                        accent: AppPalette.of(context).medium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Quick actions ---------------------------------------------
                const SectionHeader('Jump back in'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    for (var i = 0; i < actions.length; i++)
                      IconTile(
                        icon: actions[i].$1,
                        label: actions[i].$2,
                        subtitle: actions[i].$3,
                        color: AppPalette.of(context).tint(i),
                        onTap: () => _push(actions[i].$4),
                      ),
                  ],
                ),
                const SizedBox(height: 28),

                // Catalogue -------------------------------------------------
                SectionHeader(
                  'The catalogue',
                  actionLabel: 'Browse',
                  onAction: () => ProblemsScreen.openProblemsTab(context),
                ),
                if (stats == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                else
                  _CatalogueCard(stats: stats),
              ],
            );
          },
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.of(context).medium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: ShapeDecoration(color: color.withAlpha(35), shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 18, color: color),
          const SizedBox(width: 4),
          Text('$days', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Totals plus a stacked Easy / Medium / Hard bar.
class _CatalogueCard extends StatelessWidget {
  const _CatalogueCard({required this.stats});
  final ProblemStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withAlpha(150);
    const order = ['Easy', 'Medium', 'Hard'];
    final counts = {for (final d in order) d: stats.difficulties[d] ?? 0};
    final sum = counts.values.fold<int>(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stats.total ?? '—'}', style: theme.textTheme.headlineMedium),
                      Text('problems', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stats.topicsCount ?? '—'}', style: theme.textTheme.headlineMedium),
                      Text('topics', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                    ],
                  ),
                ),
              ],
            ),
            if (sum > 0) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      for (final d in order)
                        if (counts[d]! > 0)
                          Expanded(flex: counts[d]!, child: Container(color: difficultyColor(context, d))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final d in order)
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: difficultyColor(context, d)),
                          ),
                          const SizedBox(width: 6),
                          Text('$d ', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                          Text('${counts[d]}',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HomeData {
  HomeData(this.stats);
  final ProblemStats stats;
}
