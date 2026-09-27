import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/content.dart';
import '../services/feature_services.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

/// Badges and achievement progress from /achievements/user.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.read<AchievementsService>();
    return Scaffold(
      appBar: AppBar(title: Text('Achievements', style: theme.textTheme.titleLarge)),
      body: FutureBuilder<(List<Achievement>, List<String>)>(
        future: service.user(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(message: '${snap.error}');
          }
          final (achievements, badges) = snap.data ?? (const <Achievement>[], const <String>[]);

          if (achievements.isEmpty && badges.isEmpty) {
            return const EmptyState(message: 'No achievements yet — solve problems to earn them.');
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (badges.isNotEmpty) ...[
                const Eyebrow('Badges'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in badges)
                      Chip(
                        avatar: Icon(Icons.verified_outlined,
                            size: 16, color: theme.colorScheme.primary),
                        label: Text(b),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              if (achievements.isNotEmpty) ...[
                const Eyebrow('Progress'),
                const SizedBox(height: 12),
                for (final a in achievements)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            a.unlocked ? Icons.emoji_events : Icons.emoji_events_outlined,
                            color: a.unlocked
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withAlpha(90),
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600)),
                                if (a.description != null)
                                  Text(a.description!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                          color:
                                              theme.colorScheme.onSurface.withAlpha(150))),
                                if (!a.unlocked && a.progress != null && a.target != null && a.target! > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: LinearProgressIndicator(
                                      value: (a.progress! / a.target!).clamp(0.0, 1.0),
                                      minHeight: 4,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            a.unlocked
                                ? 'Earned'
                                : (a.progress != null && a.target != null ? '${a.progress}/${a.target}' : ''),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: a.unlocked
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withAlpha(130),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Progress overview: account stats, catalogue mix and interview history
/// (the same data the web dashboard surfaces, arranged for mobile).
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final problems = auth.problems;

    return Scaffold(
      appBar: AppBar(title: Text('Progress', style: theme.textTheme.titleLarge)),
      body: RefreshIndicator(
        onRefresh: () async => auth.bootstrap(),
        child: FutureBuilder<(Map<String, dynamic>, Map<String, int>)>(
          future: () async {
            final dash = await context.read<DashboardService>().client();
            final stats = await problems.publicStats();
            return (dash, stats.difficulties);
          }(),
          builder: (context, snap) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text('See what is working.',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                        child: StatCard(
                            label: 'Solved', value: '${user?.problemsSolved ?? 0}')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            label: 'Accuracy',
                            value: '${user?.accuracy ?? 0}%',
                            accent: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Expanded(
                        child: StatCard(
                            label: 'Streak',
                            value: '${user?.streak ?? 0} days',
                            accent: theme.brightness == Brightness.dark
                                ? EmberColors.medium
                                : EmberColors.mediumLight)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            label: 'Level', value: user?.currentLevel ?? 'Beginner')),
                  ],
                ),
                const SizedBox(height: 26),

                const Eyebrow('Catalogue by difficulty'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (snap.hasData)
                          for (final e in snap.data!.$2.entries)
                            _BarRow(
                              label: e.key,
                              value: e.value,
                              max: snap.data!.$2.values.fold(1, (m, v) => v > m ? v : m),
                              color: switch (e.key.toLowerCase()) {
                                'easy' => theme.brightness == Brightness.dark
                                    ? EmberColors.easy
                                    : EmberColors.easyLight,
                                'hard' => theme.brightness == Brightness.dark
                                    ? EmberColors.hard
                                    : EmberColors.hardLight,
                                _ => theme.brightness == Brightness.dark
                                    ? EmberColors.medium
                                    : EmberColors.mediumLight,
                              },
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                const Eyebrow('Interview rounds'),
                const SizedBox(height: 12),
                FutureBuilder<InterviewStats>(
                  future: context.read<InterviewService>().stats(),
                  builder: (context, s) {
                    if (s.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    final st = s.data ?? InterviewStats();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _miniRow(theme, 'Rounds', '${st.total ?? 0}'),
                            _miniRow(theme, 'Completed', '${st.completed ?? 0}'),
                            _miniRow(theme, 'Average score', '${st.avgScore ?? '—'}'),
                            _miniRow(theme, 'Best score', '${st.bestScore ?? '—'}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _miniRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.label, required this.value, required this.max, required this.color});
  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text('$value',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: max > 0 ? value / max : 0,
              minHeight: 6,
              backgroundColor: theme.colorScheme.onSurface.withAlpha(22),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
