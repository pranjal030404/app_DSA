import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/content.dart';
import '../services/feature_services.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

/// "Collabs" — the crowdsourced suggested-edits queue for Resources,
/// Discussions and HelpArticles. Reviewing (approve/reject) needs 1000+
/// reputation on the backend; browsing your own submissions never does.
/// Mirrors the web's `review-queue` page.
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late Future<List<SuggestedEdit>> _queueFuture;
  late Future<List<SuggestedEdit>> _mineFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final service = context.read<CollabService>();
    final userId = context.read<AuthController>().user?.id ?? '';
    setState(() {
      _queueFuture = service.queue();
      _mineFuture = service.mySuggestions(userId);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthController>().user;
    return Scaffold(
      appBar: AppBar(
        title: Text('Collabs', style: theme.textTheme.titleLarge),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Queue'),
          Tab(text: 'My suggestions'),
        ]),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _QueueTab(future: _queueFuture, canReview: user?.canReviewEdits ?? false, onChanged: _reload),
          _MineTab(future: _mineFuture, onRetry: _reload),
        ],
      ),
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab({required this.future, required this.canReview, required this.onChanged});
  final Future<List<SuggestedEdit>> future;
  final bool canReview;
  final VoidCallback onChanged;

  Future<void> _act(BuildContext context, String editId, Future<void> Function() action, String successMessage) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      onChanged();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collab = context.read<CollabService>();
    return FutureBuilder<List<SuggestedEdit>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error;
          final message = err is ApiException && err.statusCode == 403
              ? err.message
              : '$err';
          return EmptyState(message: message, onRetry: onChanged);
        }
        final edits = snap.data ?? const <SuggestedEdit>[];
        if (edits.isEmpty) {
          return const EmptyState(message: 'Nothing pending review right now.');
        }
        return RefreshIndicator(
          onRefresh: () async => onChanged(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              for (final e in edits)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.resourceType} edit', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        if (e.suggestedByName != null)
                          Text('by ${e.suggestedByName}', style: theme.textTheme.bodySmall),
                        if (e.reason != null && e.reason!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(e.reason!, style: theme.textTheme.bodyMedium),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.thumb_up_outlined, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text('${e.approveVotes}'),
                            const SizedBox(width: 14),
                            Icon(Icons.thumb_down_outlined, size: 14, color: theme.colorScheme.error),
                            const SizedBox(width: 4),
                            Text('${e.rejectVotes}'),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Vote to approve',
                              icon: const Icon(Icons.thumb_up_outlined),
                              onPressed: () => _act(context, e.id, () => collab.vote(e.id, 'approve'), 'Vote recorded.'),
                            ),
                            IconButton(
                              tooltip: 'Vote to reject',
                              icon: const Icon(Icons.thumb_down_outlined),
                              onPressed: () => _act(context, e.id, () => collab.vote(e.id, 'reject'), 'Vote recorded.'),
                            ),
                          ],
                        ),
                        if (canReview)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _act(context, e.id, () => collab.approve(e.id), 'Edit approved.'),
                                  child: const Text('Approve'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                                  onPressed: () => _act(context, e.id, () => collab.reject(e.id), 'Edit rejected.'),
                                  child: const Text('Reject'),
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
        );
      },
    );
  }
}

class _MineTab extends StatelessWidget {
  const _MineTab({required this.future, required this.onRetry});
  final Future<List<SuggestedEdit>> future;
  final VoidCallback onRetry;

  Color _statusColor(BuildContext context, String status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return switch (status) {
      'approved' => isDark ? theme.colorScheme.primary : theme.colorScheme.primary,
      'rejected' => theme.colorScheme.error,
      _ => theme.colorScheme.onSurface.withAlpha(160),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<SuggestedEdit>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(message: '${snap.error}', onRetry: onRetry);
        }
        final mine = snap.data ?? const <SuggestedEdit>[];
        if (mine.isEmpty) {
          return const EmptyState(message: "You haven't suggested any edits yet.");
        }
        return RefreshIndicator(
          onRefresh: () async => onRetry(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              for (final e in mine)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text('${e.resourceType} edit'),
                    subtitle: e.reason != null ? Text(e.reason!) : null,
                    trailing: Text(
                      e.status,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _statusColor(context, e.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
