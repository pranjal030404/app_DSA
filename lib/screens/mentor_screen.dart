import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/content.dart';
import '../services/feature_services.dart';

/// AI mentor chat backed by POST /chatbot/chat.
class MentorScreen extends StatefulWidget {
  const MentorScreen({super.key});

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[
    ChatMessage(
      fromMentor: true,
      text: 'Ask me anything — a concept, an approach, or where you are stuck. '
          'I nudge, I don\'t spoil.',
    ),
  ];
  String? _sessionId;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, fromMentor: false));
      _busy = true;
    });
    _scrollToEnd();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final reply = await context.read<MentorService>().send(text, sessionId: _sessionId);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, fromMentor: true));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: e.toString(), fromMentor: true, error: true));
        _busy = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('AI Mentor', style: theme.textTheme.titleLarge)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _messages.length + (_busy ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: _Bubble(
                        message: ChatMessage(text: '…', fromMentor: true), typing: true),
                  );
                }
                return Align(
                  alignment: _messages[i].fromMentor
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: _Bubble(message: _messages[i]),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Ask the mentor…'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _busy ? null : _send,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.typing = false});
  final ChatMessage message;
  final bool typing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mentor = message.fromMentor;
    final error = message.error;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      decoration: BoxDecoration(
        color: error
            ? AppPalette.of(context).hard.withAlpha(35)
            : mentor
                ? (Theme.of(context).colorScheme.surface)
                : theme.colorScheme.primary.withAlpha(34),
        borderRadius: BorderRadius.circular(14).copyWith(
          bottomLeft: mentor ? const Radius.circular(4) : null,
          bottomRight: !mentor ? const Radius.circular(4) : null,
        ),
        border: Border.all(
          color: error
              ? AppPalette.of(context).hard.withAlpha(90)
              : mentor
                  ? (Theme.of(context).colorScheme.outlineVariant)
                  : Colors.transparent,
        ),
      ),
      child: Text(
        message.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: error
              ? (AppPalette.of(context).hard)
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
