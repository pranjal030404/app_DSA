import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/content.dart';
import '../services/feature_services.dart';
import '../widgets/code_editor.dart';
import '../widgets/widgets.dart';

/// Free-form code runner: pick a language, provide stdin, run, and ask the AI
/// to explain the code. Backed by /playground/*.
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  final _code = TextEditingController();
  final _stdin = TextEditingController();
  List<String> _languages = PlaygroundService.fallbackLanguages;
  String _language = 'javascript';
  PlaygroundRun? _result;
  String? _explanation;
  bool _running = false;
  bool _explaining = false;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  @override
  void dispose() {
    _code.dispose();
    _stdin.dispose();
    super.dispose();
  }

  Future<void> _loadLanguages() async {
    final langs = await context.read<PlaygroundService>().languages();
    if (!mounted) return;
    setState(() {
      _languages = langs;
      if (!langs.contains(_language) && langs.isNotEmpty) _language = langs.first;
    });
  }

  Future<void> _run() async {
    if (_running || _code.text.trim().isEmpty) {
      if (_code.text.trim().isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Write some code first.')));
      }
      return;
    }
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await context
          .read<PlaygroundService>()
          .run(_code.text, _language, _stdin.text);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _explain() async {
    if (_explaining || _code.text.trim().isEmpty) return;
    setState(() => _explaining = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final text = await context
          .read<PlaygroundService>()
          .explain(_code.text, _language);
      if (!mounted) return;
      setState(() => _explanation = text);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _explaining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Playground', style: theme.textTheme.titleLarge)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LanguagePicker(
                  languages: _languages,
                  value: _language,
                  onChanged: (v) => setState(() => _language = v),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CodePane(controller: _code, expanded: false, height: 260),
          const SizedBox(height: 12),
          TextField(
            controller: _stdin,
            maxLines: 3,
            style: GoogleFonts.jetBrainsMono(fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'stdin (optional)',
              alignLabelWithHint: true,
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _OutputCard(result: _result!),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _explaining ? null : _explain,
            icon: _explaining
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Explain this code'),
          ),
          if (_explanation != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Mentor says'),
                    const SizedBox(height: 10),
                    SelectableText(
                      _explanation!,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({required this.result});
  final PlaygroundRun result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = result.verdict == null || result.exitCode == null || result.exitCode == 0;
    final color = ok
        ? (AppPalette.of(context).easy)
        : (AppPalette.of(context).hard);
    final mono = GoogleFonts.jetBrainsMonoTextTheme().bodySmall;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Output', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (result.verdict != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: ShapeDecoration(
                      color: color.withAlpha(30),
                      shape: StadiumBorder(side: BorderSide(color: color.withAlpha(120))),
                    ),
                    child: Text(result.verdict!,
                        style: theme.textTheme.bodySmall?.copyWith(color: color)),
                  ),
                if (result.time != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(result.time!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(140))),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (result.stdout != null && result.stdout!.isNotEmpty)
              Text(result.stdout!, style: mono)
            else
              Text('— no output —',
                  style: mono?.copyWith(color: theme.colorScheme.onSurface.withAlpha(120))),
            if (result.stderr != null && result.stderr!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(result.stderr!, style: mono?.copyWith(color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
