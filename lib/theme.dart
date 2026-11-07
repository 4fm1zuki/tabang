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
  static const Color gold = Color(0xFFB07A16);
  static const Color goldSoft = Color(0xFFF8E9C8);
  static const Color teal = Color(0xFF23695E);
  static const Color tealSoft = Color(0xFFDCEDEA);

  // Light surfaces
  static const Color lightBg = Color(0xFFF8F5F3);
  static const Color lightSurface = Color(0xFFFFFCFB);
  static const Color lightSurfaceAlt = Color(0xFFF2ECEA);
  static const Color lightBorder = Color(0xFFE5DDDA);
  static const Color lightText = Color(0xFF1E1715);
  // Darker than the old #6E625E: on the near-white surfaces it sat just above
  // the AA line and looked washed out at 11–12 px with a light font weight.
  static const Color lightTextMuted = Color(0xFF5A4F4B);

  // Dark surfaces. Warm charcoal rather than near-black: the previous #100E0D
  // read as a black hole on OLED and made every card boundary disappear.
  // The muted tone clears WCAG AA on all three dark surface levels.
  static const Color darkBg = Color(0xFF171210);
  static const Color darkSurface = Color(0xFF211B19);
  static const Color darkSurfaceAlt = Color(0xFF2C2422);
  // #4A403C was nearly invisible on #211B19, so cards and outlined controls
  // read as disabled in dark mode. This is the lightest border that still
  // looks like a quiet divider rather than a bright wire.
  static const Color darkBorder = Color(0xFF564A45);
  static const Color darkText = Color(0xFFFBF5F2);
  static const Color darkTextMuted = Color(0xFFCBBDB7);
}

/// Reusable gradients for hero surfaces and empty states.
class TabangGradients {
  const TabangGradients._();

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB3261E), Color(0xFF7A1512)],
  );

  static const LinearGradient warm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF9DEDC), Color(0xFFFFF4EF), Color(0xFFF4E6D8)],
  );

  static const LinearGradient darkSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2B211F), Color(0xFF191514)],
  );

  /// Donor hub identity card. A deep maroon rather than a full crimson field:
  /// the page already uses crimson for actions, and a large saturated block
  /// made the whole tab feel like an alert.
  static const LinearGradient donorHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF421916), Color(0xFF251312)],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8E9C8), Color(0xFFFFF7E7)],
  );

  static LinearGradient forContext(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : warm;
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

  Color get surface =>
      isDark ? TabangColors.darkSurface : TabangColors.lightSurface;
  Color get surfaceAlt =>
      isDark ? TabangColors.darkSurfaceAlt : TabangColors.lightSurfaceAlt;
  Color get border =>
      isDark ? TabangColors.darkBorder : TabangColors.lightBorder;
  Color get textColor =>
      isDark ? TabangColors.darkText : TabangColors.lightText;
  Color get textMuted =>
      isDark ? TabangColors.darkTextMuted : TabangColors.lightTextMuted;

  Color get successBg =>
      isDark ? const Color(0xFF14301F) : TabangColors.successSoft;
  Color get warningBg =>
      isDark ? const Color(0xFF33280D) : TabangColors.warningSoft;
  Color get dangerBg =>
      isDark ? const Color(0xFF3A1917) : TabangColors.dangerSoft;
  Color get infoBg => isDark ? const Color(0xFF132A42) : TabangColors.infoSoft;
}

class TabangTheme {
  const TabangTheme._();

  // Cached: building a ThemeData runs ColorScheme.fromSeed and constructs
  // dozens of sub-themes. The previous getters rebuilt both themes on every
  // app-level setState, which showed up as visible stutter while scrolling.
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: TabangColors.crimson,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFFFB4A8) : TabangColors.crimson,
          onPrimary: isDark ? const Color(0xFF56100B) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF7A1B15)
              : TabangColors.crimsonSoft,
          onPrimaryContainer: isDark
              ? const Color(0xFFFFDAD4)
              : TabangColors.crimsonDark,
          // Teal supports the crimson without competing with it. Gold is kept as a
          // tertiary accent for recognition/SDG callouts, not for primary actions:
          // gold-filled buttons on a dark surface read as disabled olive.
          secondary: isDark ? const Color(0xFF9CD5CA) : TabangColors.teal,
          onSecondary: isDark ? const Color(0xFF00201B) : Colors.white,
          secondaryContainer: isDark
              ? const Color(0xFF12463E)
              : TabangColors.tealSoft,
          onSecondaryContainer: isDark
              ? const Color(0xFFB8EAE0)
              : const Color(0xFF0C3B33),
          tertiary: isDark ? const Color(0xFFFFD27A) : TabangColors.gold,
          onTertiary: isDark ? const Color(0xFF3F2A00) : Colors.white,
          tertiaryContainer: isDark
              ? const Color(0xFF5A430D)
              : TabangColors.goldSoft,
          onTertiaryContainer: isDark
              ? const Color(0xFFFFE7B0)
              : const Color(0xFF4A3400),
          surface: isDark
              ? TabangColors.darkSurface
              : TabangColors.lightSurface,
          onSurface: isDark ? TabangColors.darkText : TabangColors.lightText,
          surfaceContainerLowest: isDark
              ? const Color(0xFF120E0D)
              : Colors.white,
          surfaceContainerLow: isDark
              ? TabangColors.darkSurface
              : const Color(0xFFFBF7F5),
          surfaceContainer: isDark
              ? const Color(0xFF261F1D)
              : const Color(0xFFF5F0EE),
          surfaceContainerHigh: isDark
              ? TabangColors.darkSurfaceAlt
              : const Color(0xFFF0EAE8),
          surfaceContainerHighest: isDark
              ? const Color(0xFF3A302D)
              : const Color(0xFFEAE3E0),
          onSurfaceVariant: isDark
              ? TabangColors.darkTextMuted
              : TabangColors.lightTextMuted,
          outline: isDark ? const Color(0xFF6F5D56) : const Color(0xFFB8ADA8),
          outlineVariant: isDark
              ? const Color(0xFF3A3330)
              : TabangColors.lightBorder,
          error: isDark ? const Color(0xFFFFB4AB) : TabangColors.danger,
          onError: isDark ? const Color(0xFF690005) : Colors.white,
          errorContainer: isDark
              ? const Color(0xFF7A1B15)
              : TabangColors.dangerSoft,
          onErrorContainer: isDark
              ? const Color(0xFFFFDAD6)
              : TabangColors.crimsonDark,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? TabangColors.darkBg
          : TabangColors.lightBg,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      // InkRipple paints a normal anti-aliased circle on every platform.
      // InkSparkle's fragment shader rendered visibly pixelated on CanvasKit
      // web (and is Android-only in intent), which is what made taps look
      // blocky.
      splashFactory: InkRipple.splashFactory,
      // One hover/highlight recipe for every InkWell, not just the sidebar.
      hoverColor: scheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
      focusColor: scheme.primary.withValues(alpha: isDark ? 0.14 : 0.09),
      highlightColor: scheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
      splashColor: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
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
        // Explicit sizes: the Material defaults are already reasonable, but
        // pinning them here stops platform/font fallback from shrinking copy
        // on web and makes 12.5 px the floor for supporting text.
        bodyLarge: text.bodyLarge?.copyWith(
          fontSize: 16,
          color: scheme.onSurface,
          height: 1.5,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          fontSize: 14,
          color: scheme.onSurface,
          height: 1.5,
        ),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 12.5,
          color: isDark
              ? TabangColors.darkTextMuted
              : TabangColors.lightTextMuted,
          height: 1.45,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: text.labelMedium?.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: text.labelSmall?.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? TabangColors.darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: isDark ? TabangColors.darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark
            ? const Color(0xFF59201B)
            : TabangColors.crimsonSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 24 : 22,
            color: selected
                ? (isDark ? const Color(0xFFFFB4A8) : TabangColors.crimson)
                : (isDark
                      ? TabangColors.darkTextMuted
                      : TabangColors.lightTextMuted),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (isDark ? const Color(0xFFFFDAD4) : TabangColors.crimsonDark)
                : (isDark
                      ? TabangColors.darkTextMuted
                      : TabangColors.lightTextMuted),
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? TabangColors.darkSurface : Colors.white,
        indicatorColor: isDark
            ? const Color(0xFF59201B)
            : TabangColors.crimsonSoft,
        selectedIconTheme: IconThemeData(
          color: isDark ? const Color(0xFFFFB4A8) : TabangColors.crimson,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFFFDAD4) : TabangColors.crimsonDark,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: TabangSpace.xl,
            vertical: TabangSpace.md,
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TabangRadius.sm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TabangRadius.sm),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: TabangSpace.lg),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? const Color(0xFFFFB4A8) : TabangColors.crimson,
        linearTrackColor: isDark
            ? const Color(0xFF332C2A)
            : TabangColors.crimsonSoft,
        circularTrackColor: isDark
            ? const Color(0xFF332C2A)
            : TabangColors.crimsonSoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFF56100B) : Colors.white)
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? const Color(0xFFFFB4A8) : TabangColors.crimson)
              : scheme.surfaceContainerHighest,
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
          color: isDark
              ? TabangColors.darkTextMuted
              : TabangColors.lightTextMuted,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          color: isDark
              ? TabangColors.darkTextMuted
              : TabangColors.lightTextMuted,
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
          // Outlined buttons need a stronger outline than a card divider; at
          // 1 px and #4A403C they read as disabled against dark surfaces.
          side: BorderSide(
            color: isDark ? const Color(0xFF7D6A63) : const Color(0xFFCFC4BE),
            width: 1.2,
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
        backgroundColor: isDark
            ? TabangColors.darkSurfaceAlt
            : TabangColors.lightSurfaceAlt,
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
        backgroundColor: isDark
            ? TabangColors.darkSurfaceAlt
            : TabangColors.lightText,
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
