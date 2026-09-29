import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_mentor/core/theme.dart';
import 'package:dsa_mentor/core/web_theme_presets.dart';

void main() {
  test('parseCssColor handles the formats the website uses', () {
    expect(parseCssColor('#0e7a4b'), const Color(0xFF0E7A4B));
    expect(parseCssColor('#fff'), const Color(0xFFFFFFFF));
    expect(parseCssColor('#11223380'), const Color(0x80112233));
    expect(parseCssColor('rgba(28,30,26,0.5)'), const Color.fromARGB(128, 28, 30, 26));
    expect(parseCssColor('rgb(1 2 3)'), const Color.fromARGB(255, 1, 2, 3));
    expect(parseCssColor('linear-gradient(0deg,#fff,#fff)'), isNull);
    expect(parseCssColor(null), isNull);
  });

  test('firstFontFamily takes the first family of a stack', () {
    expect(firstFontFamily("'Fraunces', 'Newsreader', Georgia, serif"), 'Fraunces');
    expect(firstFontFamily('Inter, sans-serif'), 'Inter');
    expect(firstFontFamily(''), isNull);
  });

  test('every bundled website theme converts to a ThemeSpec', () {
    final list = jsonDecode(kBundledWebThemesJson) as List;
    final specs = [for (final t in list) ThemeSpec.fromWebTheme(Map<String, dynamic>.from(t as Map))];
    expect(specs, everyElement(isNotNull));
    expect(specs.map((s) => s!.id), containsAll(['paper', 'paper-dark', 'sepia', 'mono-light', 'midnight']));

    final monoDark = specs.firstWhere((s) => s!.id == 'mono-dark')!;
    expect(monoDark.dark, isTrue);
    expect(monoDark.button, const Color(0xFFFFFFFF));
    expect(monoDark.onButton, const Color(0xFF0A0A0A)); // readable on the white button
  });
}
