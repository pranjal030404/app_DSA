import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'problem_detail_screen.dart';

class ProblemsScreen extends StatefulWidget {
  const ProblemsScreen({super.key});

  static void openProblemsTab(BuildContext context) => shellTab.value = 1;

  @override
  State<ProblemsScreen> createState() => _ProblemsScreenState();
}

class _ProblemsScreenState extends State<ProblemsScreen> {
  late Future<List<ProblemSummary>> _future;
  String _query = '';
  String _difficulty = 'All';

  final List<String> _filters = const ['All', 'Easy', 'Medium', 'Hard'];

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthController>().problems.list();
  }

  void _reload() =>
      setState(() => _future = context.read<AuthController>().problems.list());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Problems', style: theme.textTheme.titleLarge),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search problems',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _difficulty == f,
                      onSelected: (_) => setState(() => _difficulty = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ProblemSummary>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return EmptyState(
                    message: 'Could not load the catalogue.\n${snap.error}',
                    onRetry: _reload,
                  );
                }
                final all = snap.data ?? const <ProblemSummary>[];
                final visible = all
                    .where((p) =>
                        (_difficulty == 'All' || p.difficulty == _difficulty) &&
                        (_query.isEmpty ||
                            p.title.toLowerCase().contains(_query) ||
                            p.topics.any((t) => t.toLowerCase().contains(_query))))
                    .toList();

                if (visible.isEmpty) {
                  return EmptyState(
                    message: all.isEmpty
                        ? 'No problems in the catalogue yet.'
                        : 'Nothing matches this search.',
                    onRetry: all.isEmpty ? _reload : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = visible[i];
                      return _ProblemCard(problem: p);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.problem});
  final ProblemSummary problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = difficultyColor(context, problem.difficulty);
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProblemDetailScreen(slug: problem.slug, title: problem.title),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              problem.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DifficultyBadge(level: problem.difficulty),
                        ],
                      ),
                      if (problem.topics.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in problem.topics.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  t,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withAlpha(170),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withAlpha(90)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
