import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "Ember" brand — ported 1:1 from the web app's design tokens
/// (frontend_DSA/src/styles/theme-variables.css).
///
/// Dark: candlelit warm near-black with gold accents.
/// Light: warm parchment with a bronze-gold accent.
abstract final class EmberColors {
  // Dark — Ember
  static const bg = Color(0xFF0D0B08);
  static const surface = Color(0xFF1B1610);
  static const surfaceAlt = Color(0xFF131009);
  static const text = Color(0xFFF4ECDD);
  static const textSecondary = Color(0xFFCBC0A6);
  static const textMuted = Color(0xFFA99C85);
  static const gold = Color(0xFFE9C88C);
  static const goldBright = Color(0xFFF2DFB8);
  static const goldDeep = Color(0xFFD9A75F);
  static const inkOnGold = Color(0xFF1A1409);
  static const line = Color(0x24E9C88C); // gold @ 14%
  static const lineStrong = Color(0x47E9C88C); // gold @ 28%

  // Light — Parchment
  static const lightBg = Color(0xFFF6F1E5);
  static const lightSurface = Color(0xFFFDFBF4);
  static const lightSurfaceAlt = Color(0xFFFBF8F0);
  static const lightText = Color(0xFF231C0F);
  static const lightTextSecondary = Color(0xFF524A36);
  static const lightTextMuted = Color(0xFF6F664F);
  static const lightBronze = Color(0xFF8F6A1E);
  static const lightBronzeHover = Color(0xFF7A5917);
  static const lightLine = Color(0xFFE2DAC2);
  static const lightLineStrong = Color(0xFFD2C8AB);

  // Difficulty (dark / light pairs)
  static const easy = Color(0xFF95C489);
  static const medium = Color(0xFFE0A458);
  static const hard = Color(0xFFE07B5F);
  static const easyLight = Color(0xFF33682B);
  static const mediumLight = Color(0xFF8F5A0E);
  static const hardLight = Color(0xFFB0432F);

  // Editor surface — reads as a screenshot of the dark editor in both themes.
  static const codeBg = Color(0xFF141009);
  static const codeText = Color(0xFFF0E6D2);
  static const codeKeyword = Color(0xFFE8B576);
  static const codeFunction = Color(0xFFA3C98F);
}

/// Builds the app theme. `dark` picks Ember vs Parchment.
ThemeData buildEmberTheme({required bool dark}) {
  final scheme = dark
      ? ColorScheme.dark(
          primary: EmberColors.gold,
          onPrimary: EmberColors.inkOnGold,
          secondary: EmberColors.goldDeep,
          onSecondary: EmberColors.inkOnGold,
          surface: EmberColors.surface,
          onSurface: EmberColors.text,
          error: EmberColors.hard,
          onError: EmberColors.inkOnGold,
        )
      : ColorScheme.light(
          primary: EmberColors.lightBronze,
          onPrimary: Colors.white,
          secondary: EmberColors.lightBronzeHover,
          onSecondary: Colors.white,
          surface: EmberColors.lightSurface,
          onSurface: EmberColors.lightText,
          error: EmberColors.hardLight,
          onError: Colors.white,
        );

  final body = GoogleFonts.interTextTheme().apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final display = GoogleFonts.frauncesTextTheme().apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  TextTheme textTheme = body.copyWith(
    displayLarge: display.displayLarge,
    displayMedium: display.displayMedium,
    displaySmall: display.displaySmall,
    headlineLarge: display.headlineLarge,
    headlineMedium: display.headlineMedium,
    headlineSmall: display.headlineSmall,
    titleLarge: display.titleLarge,
    titleMedium: display.titleMedium,
  );

  final cardBorder = BorderSide(color: dark ? EmberColors.line : EmberColors.lightLine);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? EmberColors.bg : EmberColors.lightBg,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: display.titleLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      color: dark ? EmberColors.surface : EmberColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: cardBorder),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(color: dark ? EmberColors.line : EmberColors.lightLine, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? EmberColors.surfaceAlt : EmberColors.lightSurfaceAlt,
      hintStyle: body.bodyLarge?.copyWith(color: scheme.onSurface.withAlpha(110)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? EmberColors.line : EmberColors.lightLineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? EmberColors.line : EmberColors.lightLineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? EmberColors.goldBright : EmberColors.gold,
        foregroundColor: dark ? EmberColors.inkOnGold : EmberColors.lightText,
        textStyle: body.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: dark ? EmberColors.lineStrong : EmberColors.lightLineStrong),
        textStyle: body.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? EmberColors.surfaceAlt : EmberColors.lightSurfaceAlt,
      indicatorColor: scheme.primary.withAlpha(36),
      labelTextStyle: WidgetStatePropertyAll(
        body.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      side: BorderSide(color: dark ? EmberColors.line : EmberColors.lightLineStrong),
      shape: const StadiumBorder(),
      labelStyle: body.bodySmall?.copyWith(color: scheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? EmberColors.goldBright : EmberColors.lightText,
      contentTextStyle: body.bodyMedium?.copyWith(
        color: dark ? EmberColors.inkOnGold : EmberColors.lightBg,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}
