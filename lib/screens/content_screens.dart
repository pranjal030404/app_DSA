import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/content.dart';
import '../services/feature_services.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';

/* ------------------------------------------------------------------ Resources */

/// Community guides and cheat sheets from /resources.
class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  late Future<List<ResourceItem>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = context.read<ResourcesService>().list());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Resources', style: theme.textTheme.titleLarge)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ResourceCreateScreen()),
          );
          if (created == true && mounted) _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('New resource'),
      ),
      body: FutureBuilder<List<ResourceItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(message: '${snap.error}', onRetry: _reload);
          }
          final items = snap.data ?? const <ResourceItem>[];
          if (items.isEmpty) {
            return const EmptyState(message: 'No resources published yet.');
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                for (final r in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(r.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          if (r.category != null) r.category!,
                          if (r.author != null) 'by ${r.author}',
                        ].join(' · '),
                      ),
                      trailing: r.votes != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_upward,
                                    size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 3),
                                Text('${r.votes}'),
                              ],
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ResourceDetailScreen(resourceId: r.id, title: r.title),
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

class ResourceDetailScreen extends StatelessWidget {
  const ResourceDetailScreen({super.key, required this.resourceId, this.title});
  final String resourceId;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.read<ResourcesService>();
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Resource')),
      body: FutureBuilder<ResourceItem>(
        future: service.byId(resourceId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return EmptyState(message: '${snap.error ?? 'Resource not found.'}');
          }
          final r = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(r.title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              SelectableText(
                r.summary ?? '',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Submit a new community resource — mirrors the web's `resources/new` page.
/// The backend requires 50+ reputation; a fresh account sees that message
/// surfaced plainly rather than the form silently failing.
class ResourceCreateScreen extends StatefulWidget {
  const ResourceCreateScreen({super.key});

  @override
  State<ResourceCreateScreen> createState() => _ResourceCreateScreenState();
}

class _ResourceCreateScreenState extends State<ResourceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _excerpt = TextEditingController();
  final _tags = TextEditingController();
  final _externalUrl = TextEditingController();
  String _type = 'article';
  String _category = 'data-structures';
  bool _saving = false;

  static const _types = [
    'article', 'tutorial', 'cheatsheet', 'link', 'video', 'tool', 'book', 'course',
  ];
  static const _categories = [
    'data-structures', 'algorithms', 'system-design', 'interview-prep',
    'language-specific', 'problem-solving', 'career', 'tools', 'other',
  ];

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _excerpt.dispose();
    _tags.dispose();
    _externalUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<ResourcesService>().create(
            title: _title.text.trim(),
            content: _content.text.trim(),
            type: _type,
            category: _category,
            excerpt: _excerpt.text.trim(),
            tags: _tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
            externalUrl: _externalUrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource submitted.')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthController>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('New resource')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (user != null && !user.canCreateResources)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Publishing needs 50+ reputation (you have ${user.reputation}). '
                  'You can still submit — the server will tell you if it\'s blocked.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _excerpt,
              decoration: const InputDecoration(labelText: 'Excerpt (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _content,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Content', alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(labelText: 'Tags (comma-separated, optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _externalUrl,
              decoration: const InputDecoration(labelText: 'External link (optional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ Help */

/// Help center: categories → articles → article body.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late Future<List<HelpCategory>> _future;
  List<HelpArticle>? _searchResults;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = context.read<HelpService>().categories();
      _searchResults = null;
    });
  }

  Future<void> _searchNow(String q) async {
    final query = q.trim();
    if (query.length < 3) {
      _reload();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final results = await context.read<HelpService>().search(query);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Help center', style: theme.textTheme.titleLarge)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _search,
              onSubmitted: _searchNow,
              decoration: InputDecoration(
                hintText: 'Search help articles',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchResults != null
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _reload,
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _searchResults != null
                ? _buildSearchResults(theme)
                : _buildCategories(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    final results = _searchResults ?? const <HelpArticle>[];
    if (results.isEmpty) {
      return const EmptyState(message: 'Nothing found. Try different words.');
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Eyebrow('Results'),
        const SizedBox(height: 12),
        for (final a in results)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(a.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              subtitle: a.summary != null ? Text(a.summary!, maxLines: 2) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HelpArticleScreen(slug: a.slug, title: a.title),
              )),
            ),
          ),
      ],
    );
  }

  Widget _buildCategories(ThemeData theme) {
    return FutureBuilder<List<HelpCategory>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(message: '${snap.error}', onRetry: _reload);
        }
        final categories = snap.data ?? const <HelpCategory>[];
        if (categories.isEmpty) {
          return const EmptyState(message: 'No help categories yet.');
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final c in categories)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(c.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: c.description != null ? Text(c.description!) : null,
                  trailing: c.articleCount != null
                      ? Text('${c.articleCount}', style: theme.textTheme.bodySmall)
                      : const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HelpCategoryScreen(category: c),
                  )),
                ),
              ),
          ],
        );
      },
    );
  }
}

class HelpCategoryScreen extends StatefulWidget {
  const HelpCategoryScreen({super.key, required this.category});
  final HelpCategory category;

  @override
  State<HelpCategoryScreen> createState() => _HelpCategoryScreenState();
}

class _HelpCategoryScreenState extends State<HelpCategoryScreen> {
  late Future<List<HelpArticle>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<HelpService>().articles(widget.category.slug);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.title)),
      body: FutureBuilder<List<HelpArticle>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(message: '${snap.error}');
          }
          final articles = snap.data ?? const <HelpArticle>[];
          if (articles.isEmpty) {
            return const EmptyState(message: 'No articles in this category yet.');
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final a in articles)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(a.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: a.summary != null ? Text(a.summary!, maxLines: 2) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => HelpArticleScreen(slug: a.slug, title: a.title),
                    )),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class HelpArticleScreen extends StatelessWidget {
  const HelpArticleScreen({super.key, required this.slug, this.title});
  final String slug;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.read<HelpService>();
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Article')),
      body: FutureBuilder<HelpArticle>(
        future: service.article(slug),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return EmptyState(message: '${snap.error ?? 'Article not found.'}');
          }
          final a = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(a.title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              SelectableText(
                a.body ?? a.summary ?? '',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ------------------------------------------------------------------ Support */

/// Support: your tickets + new ticket form (backed by /support/tickets).
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late Future<List<SupportTicket>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = context.read<SupportService>().tickets());

  Future<void> _newTicket() async {
    final subject = TextEditingController();
    final description = TextEditingController();
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Eyebrow('New support ticket'),
            const SizedBox(height: 14),
            TextField(
              controller: subject,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Describe the problem',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit ticket'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    if (subject.text.trim().isEmpty || description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a subject and a description first.')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SupportService>().create(
            subject: subject.text.trim(),
            description: description.text.trim(),
          );
      messenger.showSnackBar(const SnackBar(content: Text('Ticket submitted.')));
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Support', style: theme.textTheme.titleLarge)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTicket,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('New ticket'),
      ),
      body: FutureBuilder<List<SupportTicket>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(message: '${snap.error}', onRetry: _reload);
          }
          final tickets = snap.data ?? const <SupportTicket>[];
          if (tickets.isEmpty) {
            return const EmptyState(
                message: 'No tickets yet.\nOpen one and the team will get back to you.');
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                for (final t in tickets)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(t.subject,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          '#${t.ticketNumber}',
                          if (t.status != null) t.status!,
                          if (t.createdAt != null)
                            '${t.createdAt!.day}/${t.createdAt!.month}/${t.createdAt!.year}',
                        ].join(' · '),
                      ),
                      leading: Icon(
                        t.status?.toLowerCase() == 'resolved' || t.status?.toLowerCase() == 'closed'
                            ? Icons.check_circle_outline
                            : Icons.schedule,
                        color: theme.colorScheme.primary,
                      ),
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
