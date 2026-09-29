import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';

/// Monospace editor pane used by the playground and interview screens
/// (the problem page has its own variant wired to per-language drafts).
class CodePane extends StatelessWidget {
  const CodePane({
    super.key,
    required this.controller,
    this.expanded = true,
    this.height,
  });

  final TextEditingController controller;
  final bool expanded;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      maxLines: null,
      expands: expanded,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      textAlignVertical: TextAlignVertical.top,
      style: GoogleFonts.jetBrainsMono(fontSize: 13, height: 1.6, color: AppPalette.of(context).codeText),
      cursorColor: Theme.of(context).colorScheme.primary,
      decoration: const InputDecoration(
        hintText: 'Write your code…',
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.all(14),
      ),
    );

    final pane = Container(
      height: height,
      decoration: BoxDecoration(
        color: AppPalette.of(context).codeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.of(context).codeBorder),
      ),
      child: expanded ? field : SingleChildScrollView(child: field),
    );

    return expanded ? pane : pane;
  }
}

/// Language dropdown with the standard label map.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.languages,
    required this.value,
    required this.onChanged,
  });

  final List<String> languages;
  final String value;
  final ValueChanged<String> onChanged;

  static const labels = {
    'javascript': 'JavaScript',
    'python': 'Python',
    'java': 'Java',
    'cpp': 'C++',
    'c': 'C',
    'csharp': 'C#',
    'go': 'Go',
    'ruby': 'Ruby',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: languages.contains(value) ? value : languages.firstOrNull,
      isDense: true,
      decoration: const InputDecoration(labelText: 'Language'),
      items: [
        for (final lang in languages)
          DropdownMenuItem(value: lang, child: Text(labels[lang] ?? lang)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
