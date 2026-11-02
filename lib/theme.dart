import 'package:flutter/material.dart';

/// TABANG design tokens.
///
/// Every colour, radius and spacing value used by the app comes from here.
/// Pages must not hardcode hex values — that is what produced the four
/// competing reds (D32F2F / 7A1C1E / E53935 / 4A1212) in the previous build.
class TabangColors {
  const TabangColors._();

  // Brand — a single crimson, used for primary actions and the blood motif.
  static const Color crimson = Color(0xFFB3261E);
  static const Color crimsonDark = Color(0xFF8C1D18);
  static const Color crimsonSoft = Color(0xFFF9DEDC);

  // Semantic status. Each has a light and dark surface tint.
  static const Color success = Color(0xFF1B7F4B);
  static const Color successSoft = Color(0xFFD7F0E2);
  static const Color warning = Color(0xFF9A6700);
  static const Color warningSoft = Color(0xFFFDF0D5);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerSoft = Color(0xFFF9DEDC);
  static const Color info = Color(0xFF1F5FA8);
  static const Color infoSoft = Color(0xFFDCE9F8);

  // Light surfaces
  static const Color lightBg = Color(0xFFF7F5F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF1EEED);
  static const Color lightBorder = Color(0xFFE3DEDC);
  static const Color lightText = Color(0xFF1C1917);
  static const Color lightTextMuted = Color(0xFF6B6360);

  // Dark surfaces
  static const Color darkBg = Color(0xFF121110);
  static const Color darkSurface = Color(0xFF1C1A19);
  static const Color darkSurfaceAlt = Color(0xFF262322);
  static const Color darkBorder = Color(0xFF35312F);
  static const Color darkText = Color(0xFFF2EFEE);
  static const Color darkTextMuted = Color(0xFFA39C99);
}

/// Corner radii. Pick the nearest token; do not invent values.
class TabangRadius {
  const TabangRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Spacing scale (4-based).
class TabangSpace {
  const TabangSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Convenience accessors so widgets can read semantic colours without
/// branching on brightness at every call site.
extension TabangThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get surface => isDark ? TabangColors.darkSurface : TabangColors.lightSurface;
  Color get surfaceAlt => isDark ? TabangColors.darkSurfaceAlt : TabangColors.lightSurfaceAlt;
  Color get border => isDark ? TabangColors.darkBorder : TabangColors.lightBorder;
  Color get textColor => isDark ? TabangColors.darkText : TabangColors.lightText;
  Color get textMuted => isDark ? TabangColors.darkTextMuted : TabangColors.lightTextMuted;

  Color get successBg => isDark ? const Color(0xFF14301F) : TabangColors.successSoft;
  Color get warningBg => isDark ? const Color(0xFF33280D) : TabangColors.warningSoft;
  Color get dangerBg => isDark ? const Color(0xFF3A1917) : TabangColors.dangerSoft;
  Color get infoBg => isDark ? const Color(0xFF132A42) : TabangColors.infoSoft;
}

class TabangTheme {
  const TabangTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: TabangColors.crimson,
      brightness: brightness,
    ).copyWith(
      primary: TabangColors.crimson,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF3A1917) : TabangColors.crimsonSoft,
      onPrimaryContainer: isDark ? const Color(0xFFF9DEDC) : TabangColors.crimsonDark,
      surface: isDark ? TabangColors.darkSurface : TabangColors.lightSurface,
      onSurface: isDark ? TabangColors.darkText : TabangColors.lightText,
      error: TabangColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? TabangColors.darkBg : TabangColors.lightBg,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
    );

    final text = base.textTheme;

    return base.copyWith(
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: scheme.onSurface,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        bodyMedium: text.bodyMedium?.copyWith(color: scheme.onSurface),
        bodySmall: text.bodySmall?.copyWith(
          color: isDark ? TabangColors.darkTextMuted : TabangColors.lightTextMuted,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? TabangColors.darkBorder : TabangColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? TabangColors.darkSurface : TabangColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TabangRadius.md),
          side: BorderSide(
            color: isDark ? TabangColors.darkBorder : TabangColors.lightBorder,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? TabangColors.darkSurfaceAlt : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TabangSpace.lg,
          vertical: TabangSpace.md,
        ),
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? TabangColors.darkTextMuted : TabangColors.lightTextMuted,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          color: isDark ? TabangColors.darkTextMuted : TabangColors.lightTextMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          borderSide: BorderSide(
            color: isDark ? TabangColors.darkBorder : TabangColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          borderSide: BorderSide(
            color: isDark ? TabangColors.darkBorder : TabangColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          borderSide: const BorderSide(color: TabangColors.crimson, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          borderSide: const BorderSide(color: TabangColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          borderSide: const BorderSide(color: TabangColors.danger, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: TabangColors.crimson,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: TabangSpace.xl,
            vertical: TabangSpace.md,
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TabangRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: TabangSpace.xl,
            vertical: TabangSpace.md,
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          side: BorderSide(
            color: isDark ? TabangColors.darkBorder : TabangColors.lightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TabangRadius.sm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TabangColors.crimson,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TabangRadius.xs),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: isDark ? TabangColors.darkSurfaceAlt : TabangColors.lightSurfaceAlt,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TabangRadius.pill),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? TabangColors.darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TabangRadius.lg),
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? TabangColors.darkSurfaceAlt : TabangColors.lightText,
        contentTextStyle: TextStyle(
          fontSize: 13,
          color: isDark ? TabangColors.darkText : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? TabangColors.darkSurfaceAlt : TabangColors.lightText,
          borderRadius: BorderRadius.circular(TabangRadius.xs),
        ),
        textStyle: TextStyle(
          fontSize: 11,
          color: isDark ? TabangColors.darkText : Colors.white,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          (isDark ? TabangColors.darkTextMuted : TabangColors.lightTextMuted)
              .withValues(alpha: 0.35),
        ),
        radius: const Radius.circular(TabangRadius.pill),
        thickness: const WidgetStatePropertyAll(6),
      ),
    );
  }
}
