import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme system.
///
/// Every selectable look — the app's own "Aurora" design and each theme the
/// website offers — is a [ThemeSpec]. [buildAppTheme] turns a spec into
/// Material [ThemeData] plus an [AppPalette] extension that screens read for
/// the colours Material has no slot for (brand gradient, difficulty, code).

/// Raw colours of the app's own "Aurora" design.
///
/// Dark: deep slate with a violet → cyan brand gradient.
/// Light: cool off-white with white, softly shadowed surfaces.
abstract final class AppColors {
  // Dark
  static const bg = Color(0xFF0B0D14);
  static const surface = Color(0xFF151823);
  static const surfaceAlt = Color(0xFF10131C);
  static const surfaceRaised = Color(0xFF1C2030);
  static const text = Color(0xFFEDEFF7);
  static const textSecondary = Color(0xFFB7BCD0);
  static const textMuted = Color(0xFF8A90A8);
  static const primary = Color(0xFF8B7BFF);
  static const primaryBright = Color(0xFFA89CFF);
  static const primaryDeep = Color(0xFF6A56F5);
  static const onPrimary = Color(0xFFFFFFFF);
  static const accent = Color(0xFF3CD6E6);
  static const line = Color(0x1FFFFFFF); // white @ 12%
  static const lineStrong = Color(0x33FFFFFF); // white @ 20%

  // Light
  static const lightBg = Color(0xFFF4F5FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF0F1F7);
  static const lightText = Color(0xFF151827);
  static const lightTextSecondary = Color(0xFF454B63);
  static const lightTextMuted = Color(0xFF6B7189);
  static const lightPrimary = Color(0xFF5B45E8);
  static const lightPrimaryDeep = Color(0xFF4A35D1);
  static const lightAccent = Color(0xFF0B9DB0);
  static const lightLine = Color(0xFFE4E6EF);
  static const lightLineStrong = Color(0xFFD3D6E3);

  // Difficulty (dark / light)
  static const easy = Color(0xFF4ADE9B);
  static const medium = Color(0xFFFBBF4D);
  static const hard = Color(0xFFFF6B7D);
  static const easyLight = Color(0xFF0F8A56);
  static const mediumLight = Color(0xFFB26A00);
  static const hardLight = Color(0xFFD12F45);

  // Code surfaces (always dark, like an IDE)
  static const codeBg = Color(0xFF0E1120);
  static const codeText = Color(0xFFE3E6F3);
  static const codeKeyword = Color(0xFFC39BFF);
  static const codeFunction = Color(0xFF6FE0EC);

  /// Tile tints for feature icons, cycled by index.
  static const tileTints = <Color>[
    Color(0xFF8B7BFF),
    Color(0xFF22C3D9),
    Color(0xFFFF8A5B),
    Color(0xFF4ADE9B),
    Color(0xFFF472B6),
    Color(0xFFFBBF4D),
  ];
}

/// Everything needed to build one theme.
class ThemeSpec {
  const ThemeSpec({
    required this.id,
    required this.name,
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceRaised,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.button,
    required this.onButton,
    required this.secondary,
    required this.line,
    required this.lineStrong,
    required this.error,
    required this.easy,
    required this.medium,
    required this.hard,
    required this.gradient,
    required this.onGradient,
    required this.codeBg,
    required this.codeText,
    required this.codeKeyword,
    required this.codeFunction,
    required this.codeMuted,
    required this.codeBorder,
    required this.tileTints,
    this.displayFont = 'Plus Jakarta Sans',
    this.bodyFont = 'Inter',
    this.cardShadow = false,
  });

  final String id;
  final String name;
  final bool dark;
  final Color bg, surface, surfaceAlt, surfaceRaised;
  final Color text, textSecondary, textMuted;
  final Color primary, button, onButton, secondary;
  final Color line, lineStrong, error;
  final Color easy, medium, hard;
  final List<Color> gradient;
  final Color onGradient;
  final Color codeBg, codeText, codeKeyword, codeFunction, codeMuted, codeBorder;
  final List<Color> tileTints;
  final String displayFont, bodyFont;
  final bool cardShadow;

  static const _auroraGradient = [Color(0xFF6A56F5), Color(0xFF8B5CF6), Color(0xFF22C3D9)];

  static const auroraDark = ThemeSpec(
    id: 'aurora-dark',
    name: 'Aurora Dark',
    dark: true,
    bg: AppColors.bg,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt,
    surfaceRaised: AppColors.surfaceRaised,
    text: AppColors.text,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    primary: AppColors.primary,
    button: AppColors.primary,
    onButton: AppColors.onPrimary,
    secondary: AppColors.accent,
    line: AppColors.line,
    lineStrong: AppColors.lineStrong,
    error: AppColors.hard,
    easy: AppColors.easy,
    medium: AppColors.medium,
    hard: AppColors.hard,
    gradient: _auroraGradient,
    onGradient: Colors.white,
    codeBg: AppColors.codeBg,
    codeText: AppColors.codeText,
    codeKeyword: AppColors.codeKeyword,
    codeFunction: AppColors.codeFunction,
    codeMuted: AppColors.textMuted,
    codeBorder: AppColors.lineStrong,
    tileTints: AppColors.tileTints,
  );

  static const auroraLight = ThemeSpec(
    id: 'aurora-light',
    name: 'Aurora Light',
    dark: false,
    bg: AppColors.lightBg,
    surface: AppColors.lightSurface,
    surfaceAlt: AppColors.lightSurfaceAlt,
    surfaceRaised: AppColors.lightSurface,
    text: AppColors.lightText,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    primary: AppColors.lightPrimary,
    button: AppColors.lightPrimary,
    onButton: Colors.white,
    secondary: AppColors.lightAccent,
    line: AppColors.lightLine,
    lineStrong: AppColors.lightLineStrong,
    error: AppColors.hardLight,
    easy: AppColors.easyLight,
    medium: AppColors.mediumLight,
    hard: AppColors.hardLight,
    gradient: _auroraGradient,
    onGradient: Colors.white,
    // Code stays IDE-dark in the Aurora design, light or dark.
    codeBg: AppColors.codeBg,
    codeText: AppColors.codeText,
    codeKeyword: AppColors.codeKeyword,
    codeFunction: AppColors.codeFunction,
    codeMuted: AppColors.textMuted,
    codeBorder: AppColors.lineStrong,
    tileTints: AppColors.tileTints,
    cardShadow: true,
  );

  /// Builds a spec from a website theme (`/platform-settings/public` →
  /// `themes[]`), mapping its CSS custom properties onto the app's slots.
  /// Returns null if the theme lacks the core colours.
  static ThemeSpec? fromWebTheme(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final tokens = json['tokens'];
    if (id == null || tokens is! Map) return null;
    final dark = json['mode'] != 'light';

    Color? c(String key) => parseCssColor(tokens[key]?.toString());
    final bg = c('--bg-primary');
    final text = c('--text-primary');
    final primary = c('--primary');
    if (bg == null || text == null || primary == null) return null;

    final surface = c('--bg-card') ?? c('--bg-secondary') ?? bg;
    final surfaceAlt = c('--bg-secondary') ?? surface;
    final line = c('--border-color') ?? text.withAlpha(dark ? 36 : 30);
    final button = c('--btn-primary-bg') ?? primary;
    final onButton = c('--btn-primary-text') ?? (dark ? Colors.black : Colors.white);
    final textMuted = c('--text-muted') ?? text.withAlpha(150);
    final easy = c('--difficulty-easy') ?? c('--success-color') ?? (dark ? AppColors.easy : AppColors.easyLight);
    final medium =
        c('--difficulty-medium') ?? c('--warning-color') ?? (dark ? AppColors.medium : AppColors.mediumLight);
    final hard = c('--difficulty-hard') ?? c('--danger-color') ?? (dark ? AppColors.hard : AppColors.hardLight);
    final info = c('--info-color') ?? primary;

    return ThemeSpec(
      id: id,
      name: json['name']?.toString() ?? id,
      dark: dark,
      bg: bg,
      surface: surface,
      surfaceAlt: surfaceAlt,
      surfaceRaised: c('--surface-elevated') ?? c('--bg-tertiary') ?? surface,
      text: text,
      textSecondary: c('--text-secondary') ?? text.withAlpha(200),
      textMuted: textMuted,
      primary: primary,
      button: button,
      onButton: onButton,
      secondary: c('--accent-color') ?? info,
      line: line,
      lineStrong: c('--border-strong') ?? Color.lerp(line, text, 0.15)!,
      error: c('--danger-color') ?? hard,
      easy: easy,
      medium: medium,
      hard: hard,
      gradient: [button, c('--primary-hover') ?? button],
      onGradient: onButton,
      codeBg: c('--bg-code') ?? surfaceAlt,
      codeText: text,
      codeKeyword: primary,
      codeFunction: info,
      codeMuted: textMuted,
      codeBorder: line,
      tileTints: [primary, info, medium, easy, hard, c('--primary-light') ?? primary],
      displayFont: firstFontFamily(tokens['--font-display']?.toString()) ?? 'Fraunces',
      bodyFont: firstFontFamily(tokens['--font-primary']?.toString()) ?? 'Inter',
      cardShadow: !dark,
    );
  }
}

/// Parses `#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb()` and `rgba()`; null otherwise
/// (gradients, `var(...)`, named colours).
Color? parseCssColor(String? value) {
  if (value == null) return null;
  final v = value.trim().toLowerCase();
  if (v.startsWith('#')) {
    var hex = v.substring(1);
    if (hex.length == 3) hex = hex.split('').map((ch) => '$ch$ch').join();
    if (hex.length == 6) {
      hex = 'ff$hex';
    } else if (hex.length == 8) {
      hex = hex.substring(6) + hex.substring(0, 6); // CSS RRGGBBAA → AARRGGBB
    }
    final n = int.tryParse(hex, radix: 16);
    return hex.length == 8 && n != null ? Color(n) : null;
  }
  final m = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(v);
  if (m == null) return null;
  final parts = m.group(1)!.split(RegExp(r'[,\s/]+')).where((p) => p.isNotEmpty).toList();
  if (parts.length < 3) return null;
  final rgb = parts.take(3).map(int.tryParse).toList();
  if (rgb.any((x) => x == null)) return null;
  var alpha = 1.0;
  if (parts.length > 3) {
    alpha = parts[3].endsWith('%')
        ? (double.tryParse(parts[3].replaceAll('%', '')) ?? 100) / 100
        : double.tryParse(parts[3]) ?? 1;
  }
  return Color.fromARGB((alpha.clamp(0, 1) * 255).round(), rgb[0]!, rgb[1]!, rgb[2]!);
}

/// First family in a CSS font stack: `'Fraunces', Georgia, serif` → `Fraunces`.
String? firstFontFamily(String? stack) {
  if (stack == null || stack.trim().isEmpty) return null;
  final first = stack.split(',').first.trim().replaceAll(RegExp('[\'"]'), '');
  return first.isEmpty ? null : first;
}

/// Theme colours Material's ColorScheme has no slot for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.gradient,
    required this.onGradient,
    required this.easy,
    required this.medium,
    required this.hard,
    required this.codeBg,
    required this.codeText,
    required this.codeKeyword,
    required this.codeFunction,
    required this.codeMuted,
    required this.codeBorder,
    required this.tileTints,
  });

  final LinearGradient gradient;
  final Color onGradient;
  final Color easy, medium, hard;
  final Color codeBg, codeText, codeKeyword, codeFunction, codeMuted, codeBorder;
  final List<Color> tileTints;

  static AppPalette of(BuildContext context) => Theme.of(context).extension<AppPalette>()!;

  /// Glow colour under gradient surfaces.
  Color get glow => gradient.colors.first;

  Color tint(int i) => tileTints[i % tileTints.length];

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      gradient: LinearGradient.lerp(gradient, other.gradient, t)!,
      onGradient: l(onGradient, other.onGradient),
      easy: l(easy, other.easy),
      medium: l(medium, other.medium),
      hard: l(hard, other.hard),
      codeBg: l(codeBg, other.codeBg),
      codeText: l(codeText, other.codeText),
      codeKeyword: l(codeKeyword, other.codeKeyword),
      codeFunction: l(codeFunction, other.codeFunction),
      codeMuted: l(codeMuted, other.codeMuted),
      codeBorder: l(codeBorder, other.codeBorder),
      tileTints: t < 0.5 ? tileTints : other.tileTints,
    );
  }
}

TextTheme _fontTheme(String family, TextTheme Function() fallback) {
  try {
    return GoogleFonts.getTextTheme(family);
  } catch (_) {
    return fallback(); // not a Google Font — use the default
  }
}

/// Builds Material [ThemeData] (plus [AppPalette]) from a [ThemeSpec].
ThemeData buildAppTheme(ThemeSpec spec) {
  final dark = spec.dark;
  final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
    primary: spec.primary,
    onPrimary: spec.onButton,
    primaryContainer: spec.primary.withAlpha(dark ? 60 : 36),
    onPrimaryContainer: spec.primary,
    secondary: spec.secondary,
    onSecondary: spec.bg,
    surface: spec.surface,
    onSurface: spec.text,
    onSurfaceVariant: spec.textSecondary,
    surfaceContainerHighest: spec.surfaceRaised == spec.surface ? spec.surfaceAlt : spec.surfaceRaised,
    outline: spec.lineStrong,
    outlineVariant: spec.line,
    error: spec.error,
    onError: dark ? spec.bg : Colors.white,
  );

  final body = _fontTheme(spec.bodyFont, GoogleFonts.interTextTheme).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final display = _fontTheme(spec.displayFont, GoogleFonts.plusJakartaSansTextTheme).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  final textTheme = body.copyWith(
    displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
    displayMedium: display.displayMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
    displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
    headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
    headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
    headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    titleMedium: display.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: display.titleSmall?.copyWith(fontWeight: FontWeight.w600),
  );

  final shape20 =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: spec.line));
  const shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14)));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: spec.bg,
    canvasColor: spec.bg,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    extensions: [
      AppPalette(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: spec.gradient,
        ),
        onGradient: spec.onGradient,
        easy: spec.easy,
        medium: spec.medium,
        hard: spec.hard,
        codeBg: spec.codeBg,
        codeText: spec.codeText,
        codeKeyword: spec.codeKeyword,
        codeFunction: spec.codeFunction,
        codeMuted: spec.codeMuted,
        codeBorder: spec.codeBorder,
        tileTints: spec.tileTints,
      ),
    ],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: spec.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: spec.surface,
      surfaceTintColor: Colors.transparent,
      elevation: spec.cardShadow ? 1.5 : 0,
      shadowColor: const Color(0x14151827),
      shape: shape20,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      iconColor: scheme.primary,
    ),
    dividerTheme: DividerThemeData(color: spec.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? spec.surfaceAlt : spec.surface,
      hintStyle: body.bodyLarge?.copyWith(color: scheme.onSurface.withAlpha(110)),
      prefixIconColor: scheme.onSurface.withAlpha(150),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: spec.lineStrong)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: spec.lineStrong)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: spec.button,
        foregroundColor: spec.onButton,
        textStyle: body.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: shape14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: body.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: shape14,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: spec.lineStrong),
        textStyle: body.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: shape14,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: body.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: dark ? spec.surfaceAlt : spec.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withAlpha(dark ? 55 : 30),
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurface.withAlpha(150),
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => body.labelSmall?.copyWith(
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurface.withAlpha(150),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: spec.surface,
      selectedColor: scheme.primary.withAlpha(dark ? 60 : 30),
      side: BorderSide(color: spec.line),
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: body.bodySmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface.withAlpha(150),
      indicatorColor: scheme.primary,
      dividerColor: spec.line,
      labelStyle: body.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? spec.surfaceRaised : spec.text,
      contentTextStyle: body.bodyMedium?.copyWith(
        color: dark ? spec.text : spec.bg,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: spec.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: spec.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withAlpha(35),
    ),
  );
}
