import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const Color lightBg = Color(0xFFFAFAF8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceRaised = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF6B6862);
  static const Color lightTextDisabled = Color(0xFFA19F9A);
  static const Color lightHairline = Color(0xFFE8E6E1);
  static const Color lightAccent = Color(0xFFD9531E);
  static const Color lightAccentDeep = Color(0xFFB54114);
  static const Color lightAccentSoft = Color(0xFFFBEDE6);
  static const Color lightEnergy = Color(0xFFA5C422); // adjusted for light contrast
  static const Color lightEnergySoft = Color(0xFFE5F1B9);
  static const Color lightSuccess = Color(0xFF3A7D44);
  static const Color lightWarning = Color(0xFFA6680E);
  static const Color lightError = Color(0xFFA63232);
  static const Color lightHighlight = Color(0xFFD4A017);

  // Ember Night Dark Tokens
  static const Color darkBg = Color(0xFF0E0D0B);
  static const Color darkSurface = Color(0xFF171512);
  static const Color darkSurfaceRaised = Color(0xFF201D19);
  static const Color darkText = Color(0xFFF5F1E8);
  static const Color darkTextSecondary = Color(0xFFC9C2B4);
  static const Color darkTextDisabled = Color(0xFF8A8375);
  static const Color darkHairline = Color(0xFF37322A);
  static const Color darkAccent = Color(0xFFFF8A4C);
  static const Color darkAccentDeep = Color(0xFFE56A2B);
  static const Color darkAccentSoft = Color(0xFF3A2417);
  static const Color darkEnergy = Color(0xFFD3F158);
  static const Color darkEnergySoft = Color(0xFF2E3313);
  static const Color darkSuccess = Color(0xFF8FE3A1);
  static const Color darkWarning = Color(0xFFF2C14E);
  static const Color darkError = Color(0xFFFF8B84);
  static const Color darkHighlight = Color(0xFFE9C46A);

  static const LinearGradient emberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A4C), Color(0xFFFFB36B)],
    stops: [0.0, 1.0],
  );

  static final RadialGradient nightGlow = RadialGradient(
    colors: [
      const Color(0xFFFF8A4C).withValues(alpha: 0.12),
      const Color(0xFFFF8A4C).withValues(alpha: 0.0),
    ],
    stops: const [0.0, 1.0],
    radius: 0.8,
  );

  static Color _getSeedColor(String colorName, {bool isDark = false}) {
    switch (colorName.toLowerCase()) {
      case 'blue': return isDark ? const Color(0xFF6B8EFF) : const Color(0xFF2E5BFF);
      case 'green': return isDark ? const Color(0xFF5ECA7B) : const Color(0xFF259846);
      case 'purple': return isDark ? const Color(0xFFB878FF) : const Color(0xFF8B3DFF);
      case 'red': return isDark ? const Color(0xFFFF6B6B) : const Color(0xFFE53935);
      case 'orange':
      default:
        return isDark ? darkAccent : lightAccent;
    }
  }

  static ThemeData getLightTheme([String colorName = 'orange']) {
    final seed = _getSeedColor(colorName, isDark: false);
    return _buildTheme(
      bg: lightBg,
      surface: lightSurface,
      surfaceRaised: lightSurfaceRaised,
      text: lightText,
      textSecondary: lightTextSecondary,
      textDisabled: lightTextDisabled,
      hairline: lightHairline,
      accent: seed,
      accentDeep: seed,
      accentSoft: seed.withValues(alpha: 0.1),
      energy: lightEnergy,
      energySoft: lightEnergySoft,
      success: lightSuccess,
      warning: lightWarning,
      error: lightError,
      highlight: lightHighlight,
      isDark: false,
    );
  }

  static ThemeData getDarkTheme([String colorName = 'orange']) {
    final seed = _getSeedColor(colorName, isDark: true);
    return _buildTheme(
      bg: darkBg,
      surface: darkSurface,
      surfaceRaised: darkSurfaceRaised,
      text: darkText,
      textSecondary: darkTextSecondary,
      textDisabled: darkTextDisabled,
      hairline: darkHairline,
      accent: seed,
      accentDeep: seed,
      accentSoft: seed.withValues(alpha: 0.1),
      energy: darkEnergy,
      energySoft: darkEnergySoft,
      success: darkSuccess,
      warning: darkWarning,
      error: darkError,
      highlight: darkHighlight,
      isDark: true,
    );
  }

  static ThemeData _buildTheme({
    required Color bg,
    required Color surface,
    required Color surfaceRaised,
    required Color text,
    required Color textSecondary,
    required Color textDisabled,
    required Color hairline,
    required Color accent,
    required Color accentDeep,
    required Color accentSoft,
    required Color energy,
    required Color energySoft,
    required Color success,
    required Color warning,
    required Color error,
    required Color highlight,
    required bool isDark,
  }) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      dividerColor: hairline,
      cardColor: surface,
      extensions: [
        AppColors(
          success: success,
          warning: warning,
          error: error,
          hairline: hairline,
          accentSoft: accentSoft,
          accentDeep: accentDeep,
          surfaceRaised: surfaceRaised,
          highlight: highlight,
          textDisabled: textDisabled,
          energy: energy,
          energySoft: energySoft,
          emberGradient: isDark ? emberGradient : null,
          nightGlow: isDark ? nightGlow : null,
        ),
      ],
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: isDark ? const Color(0xFF1A1208) : Colors.white,
        secondary: energy,
        onSecondary: const Color(0xFF1A1A1A),
        surface: surface,
        onSurface: text,
        error: error,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: 'Inter', fontSize: 34, fontWeight: FontWeight.w800, color: text, fontFeatures: const [FontFeature.tabularFigures()]),
        headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700, color: text),
        titleMedium: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600, color: text),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w400, color: text),
        bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary, letterSpacing: 0.2),
        labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary, letterSpacing: 1.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
        selectionHandleColor: accent,
      ),
    );
  }
}

class AppColors extends ThemeExtension<AppColors> {
  final Color success;
  final Color warning;
  final Color error;
  final Color hairline;
  final Color accentSoft;
  final Color accentDeep;
  final Color surfaceRaised;
  final Color highlight;
  final Color textDisabled;
  final Color energy;
  final Color energySoft;
  final LinearGradient? emberGradient;
  final RadialGradient? nightGlow;

  const AppColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.hairline,
    required this.accentSoft,
    required this.accentDeep,
    required this.surfaceRaised,
    required this.highlight,
    required this.textDisabled,
    required this.energy,
    required this.energySoft,
    this.emberGradient,
    this.nightGlow,
  });

  @override
  ThemeExtension<AppColors> copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? hairline,
    Color? accentSoft,
    Color? accentDeep,
    Color? surfaceRaised,
    Color? highlight,
    Color? textDisabled,
    Color? energy,
    Color? energySoft,
    LinearGradient? emberGradient,
    RadialGradient? nightGlow,
  }) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      hairline: hairline ?? this.hairline,
      accentSoft: accentSoft ?? this.accentSoft,
      accentDeep: accentDeep ?? this.accentDeep,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      highlight: highlight ?? this.highlight,
      textDisabled: textDisabled ?? this.textDisabled,
      energy: energy ?? this.energy,
      energySoft: energySoft ?? this.energySoft,
      emberGradient: emberGradient ?? this.emberGradient,
      nightGlow: nightGlow ?? this.nightGlow,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      hairline: Color.lerp(hairline, other.hairline, t) ?? hairline,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t) ?? accentDeep,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t) ?? surfaceRaised,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t) ?? textDisabled,
      energy: Color.lerp(energy, other.energy, t) ?? energy,
      energySoft: Color.lerp(energySoft, other.energySoft, t) ?? energySoft,
      emberGradient: t < 0.5 ? emberGradient : other.emberGradient,
      nightGlow: t < 0.5 ? nightGlow : other.nightGlow,
    );
  }
}

extension AppThemeTextExtension on TextTheme {
  TextStyle get display => displayLarge!;
  TextStyle get h1 => headlineLarge!;
  TextStyle get h2 => titleMedium!;
  TextStyle get body => bodyLarge!;
  TextStyle get caption => bodySmall!;
  TextStyle get bodyStrong => bodyLarge!;
  TextStyle get overline => labelSmall!;
}
