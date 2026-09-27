import 'package:flutter/material.dart';

import 'achievements_screen.dart';
import 'content_screens.dart';
import 'interview_screens.dart';
import 'profile_screen.dart';
import 'review_queue_screen.dart';
import 'roadmaps_screen.dart';

/// Feature hub for everything that doesn't get a bottom tab.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _items = <(String, IconData, Widget)>[
    ('Progress', Icons.insights_outlined, AnalyticsScreen()),
    ('Mock interviews', Icons.record_voice_over_outlined, InterviewDashboardScreen()),
    ('Roadmaps', Icons.route_outlined, RoadmapsScreen()),
    ('Achievements', Icons.emoji_events_outlined, AchievementsScreen()),
    ('Resources', Icons.menu_book_outlined, ResourcesScreen()),
    ('Collabs', Icons.groups_outlined, ReviewQueueScreen()),
    ('Help center', Icons.help_outline, HelpScreen()),
    ('Support', Icons.support_agent_outlined, SupportScreen()),
    ('Account', Icons.person_outline, ProfileScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('More', style: theme.textTheme.titleLarge)),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
        ),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final (label, icon, screen) = _items[i];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => screen),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: theme.colorScheme.primary, size: 24),
                    const Spacer(),
                    Text(label,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
