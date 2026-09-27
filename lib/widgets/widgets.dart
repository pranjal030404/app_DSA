import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

/// The `{}` brand mark: gold rounded square with dark ink braces.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EmberColors.gold, EmberColors.goldDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: EmberColors.goldDeep.withAlpha(70),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '{}',
        style: GoogleFonts.jetBrainsMono(
          color: EmberColors.inkOnGold,
          fontSize: size * 0.5,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Easy / Medium / Hard pill matching the web difficulty tokens.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({super.key, required this.level, this.filled = false});
  final String level;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, label) = switch (level.toLowerCase()) {
      'easy' => (isDark ? EmberColors.easy : EmberColors.easyLight, 'Easy'),
      'hard' => (isDark ? EmberColors.hard : EmberColors.hardLight, 'Hard'),
      _ => (isDark ? EmberColors.medium : EmberColors.mediumLight, 'Medium'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: ShapeDecoration(
        color: filled ? color.withAlpha(30) : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: color.withAlpha(120))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Big serif number + label, used on the home screen.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.accent});
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface.withAlpha(150),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: accent ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mono uppercase eyebrow with the pinging gold dot (static ring here).
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? EmberColors.goldDeep : EmberColors.lightBronze,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w600,
              color: isDark ? EmberColors.goldDeep : EmberColors.lightBronze,
            ),
          ),
        ),
      ],
    );
  }
}

/// Friendly empty / error state with an optional retry action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.onRetry, this.retryLabel});
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_outlined, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(190)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel ?? 'Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
