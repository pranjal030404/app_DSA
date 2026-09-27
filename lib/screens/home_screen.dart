import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthController>().user;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 26),
            const SizedBox(width: 10),
            Text('DSA Mentor', style: theme.textTheme.titleLarge),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<HomeData>(
          future: _future,
          builder: (context, snap) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  _greeting(),
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
                ),
                const SizedBox(height: 20),

                // Session stats, straight from the account
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Solved',
                        value: '${user?.problemsSolved ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Accuracy',
                        value: '${user?.accuracy ?? 0}%',
                        accent: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Streak',
                        value: '${user?.streak ?? 0} days',
                        accent: theme.brightness == Brightness.dark
                            ? EmberAccent.medium
                            : EmberAccent.mediumLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Level',
                        value: user?.currentLevel ?? 'Beginner',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                const Eyebrow('The catalogue'),
                const SizedBox(height: 14),
                snap.hasData
                    ? Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Problems',
                              value: '${snap.data!.stats.total ?? '—'}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              label: 'Topics',
                              value: '${snap.data!.stats.topicsCount ?? '—'}',
                            ),
                          ),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),

                if (snap.hasData && snap.data!.stats.difficulties.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (final entry in snap.data!.stats.difficulties.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  DifficultyBadge(level: entry.key),
                                  const Spacer(),
                                  Text(
                                    '${entry.value}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                const Eyebrow('Quick actions'),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: [
                    _QuickAction(
                      icon: Icons.route_outlined,
                      label: 'Roadmaps',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RoadmapsScreen()),
                      ),
                    ),
                    _QuickAction(
                      icon: Icons.record_voice_over_outlined,
                      label: 'Interviews',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const InterviewDashboardScreen()),
                      ),
                    ),
                    _QuickAction(
                      icon: Icons.insights_outlined,
                      label: 'Progress',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                      ),
                    ),
                    _QuickAction(
                      icon: Icons.emoji_events_outlined,
                      label: 'Achievements',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                      ),
                    ),
                    _QuickAction(
                      icon: Icons.menu_book_outlined,
                      label: 'Resources',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ResourcesScreen()),
                      ),
                    ),
                    _QuickAction(
                      icon: Icons.help_outline,
                      label: 'Help center',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => ProblemsScreen.openProblemsTab(context),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue practicing'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning.';
    if (hour < 17) return 'Good afternoon.';
    return 'Good evening.';
  }
}

/// Home-screen shortcut tile.
class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Local accent aliases so home cards match difficulty tokens.
abstract final class EmberAccent {
  static const medium = Color(0xFFE0A458);
  static const mediumLight = Color(0xFF8F5A0E);
}

class HomeData {
  HomeData(this.stats);
  final ProblemStats stats;
}
