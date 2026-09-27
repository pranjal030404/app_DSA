import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/content.dart';
import '../services/feature_services.dart';
import '../widgets/widgets.dart';

/// Roadmaps: your generated plans, plus the AI generator.
class RoadmapsScreen extends StatefulWidget {
  const RoadmapsScreen({super.key});

  @override
  State<RoadmapsScreen> createState() => _RoadmapsScreenState();
}

class _RoadmapsScreenState extends State<RoadmapsScreen> {
  late Future<List<Roadmap>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      setState(() => _future = context.read<RoadmapService>().list());

  Future<void> _generate() async {
    final goalController = TextEditingController();
    String level = 'Intermediate';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Eyebrow('Generate a roadmap'),
              const SizedBox(height: 14),
              TextField(
                controller: goalController,
                maxLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Your goal',
                  hintText: 'e.g. Get into a product company by March',
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in const ['Beginner', 'Intermediate', 'Advanced'])
                    ChoiceChip(
                      label: Text(l),
                      selected: level == l,
                      onSelected: (_) => setSheetState(() => level = l),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Generate with AI'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // Generating can take a little while — show a progress dialog without
    // dismissing on outside taps.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('Planning your roadmap…'),
          ],
        ),
      ),
    );
    try {
      final roadmap =
          await context.read<RoadmapService>().generate(goalController.text.trim(), level);
      if (!mounted) return;
      Navigator.of(context).pop(); // close progress
      _reload();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RoadmapDetailScreen(roadmapId: roadmap.id),
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close progress
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Roadmaps', style: theme.textTheme.titleLarge)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generate,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate'),
      ),
      body: FutureBuilder<List<Roadmap>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(message: '${snap.error}', onRetry: _reload);
          }
          final roadmaps = snap.data ?? const <Roadmap>[];
          if (roadmaps.isEmpty) {
            return EmptyState(
              message: 'No roadmaps yet.\nDescribe a goal and the mentor will plan it out.',
              onRetry: _generate,
              retryLabel: 'Generate one',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                for (final r in roadmaps)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(r.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${r.phases.length} phases · ${r.totalTasks} tasks'
                        '${r.level != null ? ' · ${r.level}' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RoadmapDetailScreen(roadmapId: r.id),
                      )),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RoadmapDetailScreen extends StatefulWidget {
  const RoadmapDetailScreen({super.key, required this.roadmapId});
  final String roadmapId;

  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  late Future<Roadmap> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<RoadmapService>().byId(widget.roadmapId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roadmap'),
        actions: [
          IconButton(
            tooltip: 'Delete roadmap',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await context.read<RoadmapService>().delete(widget.roadmapId);
                messenger.showSnackBar(
                    const SnackBar(content: Text('Roadmap deleted.')));
                navigator.pop();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Roadmap>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return EmptyState(message: '${snap.error ?? 'Roadmap not found.'}');
          }
          final roadmap = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(roadmap.title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500)),
              if (roadmap.goal != null && roadmap.goal != roadmap.title) ...[
                const SizedBox(height: 6),
                Text(roadmap.goal!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160))),
              ],
              const SizedBox(height: 20),
              for (var i = 0; i < roadmap.phases.length; i++)
                _PhaseCard(index: i + 1, phase: roadmap.phases[i]),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.index, required this.phase});
  final int index;
  final RoadmapPhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withAlpha(28),
                  ),
                  child: Text('$index',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(phase.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (phase.isDone)
                  Icon(Icons.check_circle, size: 18, color: isDark ? EmberColors.easy : EmberColors.easyLight),
              ],
            ),
            if (phase.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(phase.description!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(170))),
            ],
            if (phase.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final item in phase.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.colorScheme.onSurface.withAlpha(110), width: 1.4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
