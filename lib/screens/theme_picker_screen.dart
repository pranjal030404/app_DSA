import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

/// Pick the app's look: follow the system, the app's own Aurora design, or
/// any theme the website offers (fetched live, so admin-added themes show up).
class ThemePickerScreen extends StatelessWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themes = context.watch<ThemeController>();

    Widget grid(List<Widget> children) => GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: children,
        );

    return Scaffold(
      appBar: AppBar(title: Text('Theme', style: theme.textTheme.titleLarge)),
      body: RefreshIndicator(
        onRefresh: themes.refreshWebThemes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const SectionHeader('Automatic'),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: IconBadge(icon: Icons.brightness_auto_rounded, color: theme.colorScheme.primary),
                title: Text('Match system', style: theme.textTheme.titleSmall),
                subtitle: const Text('Aurora Light or Dark, following your phone'),
                trailing: themes.selectedId == ThemeController.systemId
                    ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                    : null,
                onTap: () => themes.select(ThemeController.systemId),
              ),
            ),
            const SizedBox(height: 28),
            const SectionHeader('App themes'),
            grid([
              for (final spec in ThemeController.appThemes)
                _ThemeSwatch(
                  spec: spec,
                  selected: themes.selectedId == spec.id,
                  onTap: () => themes.select(spec.id),
                ),
            ]),
            const SizedBox(height: 28),
            const SectionHeader('Website themes'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'The same themes as the website. Pull down to refresh the list.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
              ),
            ),
            grid([
              for (final spec in themes.webThemes)
                _ThemeSwatch(
                  spec: spec,
                  selected: themes.selectedId == spec.id,
                  onTap: () => themes.select(spec.id),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// A miniature of the theme drawn in its own colours: a screen with a
/// gradient header, a card with text lines, a button and difficulty dots.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.spec, required this.selected, required this.onTap});
  final ThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bar(double width, Color color) => Container(
          width: width,
          height: 6,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        );
    Widget dot(Color color) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 2.2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: spec.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: spec.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: spec.gradient),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.centerLeft,
                        child: bar(26, spec.onGradient.withAlpha(200)),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: spec.surface,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: spec.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bar(44, spec.text),
                              const SizedBox(height: 4),
                              bar(30, spec.textMuted),
                              const Spacer(),
                              Row(
                                children: [
                                  dot(spec.easy),
                                  dot(spec.medium),
                                  dot(spec.hard),
                                  const Spacer(),
                                  Container(
                                    width: 22,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: spec.button,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(spec.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      size: 14, color: theme.colorScheme.onSurface.withAlpha(140)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spec.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, size: 18, color: theme.colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
