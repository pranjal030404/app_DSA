import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'home_screen.dart';
import 'mentor_screen.dart';
import 'more_screen.dart';
import 'playground_screen.dart';
import 'problems_screen.dart';

/// Bottom navigation shell: Home · Practice · Playground · Mentor · More.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _screens = [
    HomeScreen(),
    ProblemsScreen(),
    PlaygroundScreen(),
    MentorScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(index: index, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => shellTab.value = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.code_rounded),
              selectedIcon: Icon(Icons.code_rounded),
              label: 'Practice',
            ),
            NavigationDestination(
              icon: Icon(Icons.terminal_rounded),
              selectedIcon: Icon(Icons.terminal_rounded),
              label: 'Playground',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Mentor',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Explore',
            ),
          ],
        ),
      ),
    );
  }
}
