import 'package:material_ui/material_ui.dart';

abstract final class EnergiaColors {
  static const Color deepNavy = Color(0xFF102A43);
  static const Color teal = Color(0xFF0F766E);
  static const Color electricLime = Color(0xFFA3E635);
  static const Color background = Color(0xFFF5F7FA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color slateNavy = Color(0xFF172B4D);

  static const Color slate = Color(0xFF627D98);
  static const Color line = Color(0xFFD9E2EC);
  static const Color surfaceElevated = Color(0xFFEAF0F5);
  static const Color tealSoft = Color(0xFFDCEFEA);
  static const Color navySoft = Color(0xFFE3ECF4);
  static const Color limeSoft = Color(0xFFF0FAD7);

  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE8F7ED);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFF4D6);
  static const Color critical = Color(0xFFDC2626);
  static const Color criticalSoft = Color(0xFFFDECEC);

  // Compatibility aliases while feature widgets migrate to semantic names.
  static const Color charcoal = deepNavy;
  static const Color sand = white;
  static const Color electricBlue = teal;
  static const Color surface = white;
  static const Color blueSoft = tealSoft;
  static const Color sandMuted = slate;
  static const Color violet = teal;
  static const Color violetDeep = teal;
  static const Color lavender = teal;
  static const Color lavenderSoft = tealSoft;
  static const Color canvas = background;
  static const Color ink = slateNavy;
  static const Color inkMuted = slate;
  static const Color mint = electricLime;
  static const Color mintSoft = limeSoft;
  static const Color amber = warning;
  static const Color amberSoft = warningSoft;
}

abstract final class EnergiaTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: EnergiaColors.teal,
          brightness: Brightness.light,
        ).copyWith(
          primary: EnergiaColors.teal,
          onPrimary: EnergiaColors.white,
          secondary: EnergiaColors.electricLime,
          onSecondary: EnergiaColors.deepNavy,
          surface: EnergiaColors.white,
          onSurface: EnergiaColors.slateNavy,
          outline: EnergiaColors.line,
          surfaceContainerHighest: EnergiaColors.surfaceElevated,
          error: EnergiaColors.critical,
          onError: EnergiaColors.white,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: EnergiaColors.background,
      fontFamily: 'Inter',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          color: EnergiaColors.slateNavy,
          fontWeight: FontWeight.w800,
          height: 1.08,
          letterSpacing: -1.1,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: EnergiaColors.slateNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: EnergiaColors.slateNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.25,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: EnergiaColors.slateNavy,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: EnergiaColors.slateNavy,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: EnergiaColors.slateNavy,
          height: 1.45,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: EnergiaColors.slate,
          height: 1.45,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          color: EnergiaColors.slateNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: EnergiaColors.deepNavy,
        foregroundColor: EnergiaColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: EnergiaColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: EnergiaColors.deepNavy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: EnergiaColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: EnergiaColors.teal,
          foregroundColor: EnergiaColors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EnergiaColors.teal,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: EnergiaColors.teal, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      dividerTheme: const DividerThemeData(color: EnergiaColors.line, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EnergiaColors.white,
        hintStyle: const TextStyle(color: EnergiaColors.slate),
        labelStyle: const TextStyle(color: EnergiaColors.slate),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EnergiaColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EnergiaColors.teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EnergiaColors.critical),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: EnergiaColors.white,
        indicatorColor: EnergiaColors.tealSoft,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: EnergiaColors.white,
        selectedColor: EnergiaColors.tealSoft,
        side: const BorderSide(color: EnergiaColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EnergiaColors.deepNavy,
        contentTextStyle: const TextStyle(color: EnergiaColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
