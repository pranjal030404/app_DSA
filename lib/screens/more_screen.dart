import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'achievements_screen.dart';
import 'content_screens.dart';
import 'interview_screens.dart';
import 'profile_screen.dart';
import 'review_queue_screen.dart';
import 'roadmaps_screen.dart';
import 'settings_screen.dart';
import 'theme_picker_screen.dart';

/// Feature hub for everything that doesn't get a bottom tab.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _learn = <(String, String, IconData, Widget)>[
    ('Progress', 'Your analytics', Icons.insights_rounded, AnalyticsScreen()),
    ('Mock interviews', 'Timed practice', Icons.record_voice_over_rounded, InterviewDashboardScreen()),
    ('Roadmaps', 'Guided plans', Icons.route_rounded, RoadmapsScreen()),
    ('Achievements', 'Badges & goals', Icons.emoji_events_rounded, AchievementsScreen()),
    ('Resources', 'Guides & notes', Icons.menu_book_rounded, ResourcesScreen()),
    ('Collabs', 'Review queue', Icons.groups_rounded, ReviewQueueScreen()),
  ];

  static const _support = <(String, IconData, Widget)>[
    ('Help center', Icons.help_rounded, HelpScreen()),
    ('Support', Icons.support_agent_rounded, SupportScreen()),
    ('Theme', Icons.palette_rounded, ThemePickerScreen()),
    ('Settings', Icons.settings_rounded, SettingsScreen()),
  ];

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthController>().user;
    final name = (user?.username?.isNotEmpty ?? false) ? user!.username! : 'Your account';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(titleSpacing: 20, title: Text('Explore', style: theme.textTheme.titleLarge)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // Account header
          GradientCard(
            padding: const EdgeInsets.all(18),
            child: InkWell(
              onTap: () => _push(context, const ProfileScreen()),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppPalette.of(context).onGradient.withAlpha(50),
                    child: Text(initial,
                        style: theme.textTheme.titleLarge?.copyWith(color: AppPalette.of(context).onGradient)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(color: AppPalette.of(context).onGradient)),
                        Text(user?.email ?? 'View profile',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.of(context).onGradient.withAlpha(200))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppPalette.of(context).onGradient),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          const SectionHeader('Learn'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: _learn.length,
            itemBuilder: (context, i) {
              final (label, subtitle, icon, screen) = _learn[i];
              return IconTile(
                icon: icon,
                label: label,
                subtitle: subtitle,
                color: AppPalette.of(context).tint(i),
                onTap: () => _push(context, screen),
              );
            },
          ),
          const SizedBox(height: 28),

          const SectionHeader('Support'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < _support.length; i++) ...[
                  if (i > 0) const Divider(indent: 68),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: IconBadge(icon: _support[i].$2, color: theme.colorScheme.primary, size: 38),
                    title: Text(_support[i].$1, style: theme.textTheme.titleSmall),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _push(context, _support[i].$3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
