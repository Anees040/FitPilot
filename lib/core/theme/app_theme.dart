import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const Color lightBg = Color(0xFFFAFAF8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceRaised = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF6B6862);
  static const Color lightHairline = Color(0xFFE8E6E1);
  static const Color lightAccent = Color(0xFFD9531E);
  static const Color lightAccentSoft = Color(0xFFFBEDE6);
  static const Color lightSuccess = Color(0xFF3A7D44);
  static const Color lightWarning = Color(0xFFA6680E); // Darkened to pass WCAG 4.5:1 on white
  static const Color lightError = Color(0xFFA63232);
  static const Color lightHighlight = Color(0xFFD4A017);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF121110);
  static const Color darkSurface = Color(0xFF1C1A18);
  static const Color darkSurfaceRaised = Color(0xFF272420);
  static const Color darkText = Color(0xFFF2EFE9);
  static const Color darkTextSecondary = Color(0xFFBDB6AA);
  static const Color darkHairline = Color(0xFF3A362F);
  static const Color darkAccent = Color(0xFFDF7949); // Darkened to pass WCAG 3:1 for white text
  static const Color darkAccentSoft = Color(0xFF42291D);
  static const Color darkSuccess = Color(0xFF7CC98B);
  static const Color darkWarning = Color(0xFFE8B24A);
  static const Color darkError = Color(0xFFE5807D);
  static const Color darkHighlight = Color(0xFFE9C46A);

  static ThemeData get lightTheme {
    return _buildTheme(
      bg: lightBg,
      surface: lightSurface,
      surfaceRaised: lightSurfaceRaised,
      text: lightText,
      textSecondary: lightTextSecondary,
      hairline: lightHairline,
      accent: lightAccent,
      accentSoft: lightAccentSoft,
      success: lightSuccess,
      warning: lightWarning,
      error: lightError,
      highlight: lightHighlight,
      isDark: false,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      bg: darkBg,
      surface: darkSurface,
      surfaceRaised: darkSurfaceRaised,
      text: darkText,
      textSecondary: darkTextSecondary,
      hairline: darkHairline,
      accent: darkAccent,
      accentSoft: darkAccentSoft,
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
    required Color hairline,
    required Color accent,
    required Color accentSoft,
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
      extensions: [
        AppColors(
          success: success,
          warning: warning,
          error: error,
          hairline: hairline,
          accentSoft: accentSoft,
          surfaceRaised: surfaceRaised,
          highlight: highlight,
        ),
      ],
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: Colors.white, // Both light and dark use white text on accent
        secondary: accent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: text,
        error: error,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: 'Inter', fontSize: 32,
          fontWeight: FontWeight.w800,
          color: text,),
        headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 24,
          fontWeight: FontWeight.w700,
          color: text,),
        headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 18,
          fontWeight: FontWeight.w600,
          color: text,),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 15,
          fontWeight: FontWeight.w600,
          color: text,),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 15,
          fontWeight: FontWeight.w400,
          color: text,),
        bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,),
        labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 1.2,),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
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
  final Color surfaceRaised;
  final Color highlight;

  const AppColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.hairline,
    required this.accentSoft,
    required this.surfaceRaised,
    required this.highlight,
  });

  @override
  ThemeExtension<AppColors> copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? hairline,
    Color? accentSoft,
    Color? surfaceRaised,
    Color? highlight,
  }) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      hairline: hairline ?? this.hairline,
      accentSoft: accentSoft ?? this.accentSoft,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      highlight: highlight ?? this.highlight,
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
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t) ?? surfaceRaised,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
    );
  }
}

extension AppThemeTextExtension on TextTheme {
  TextStyle get display => displayLarge!;
  TextStyle get h1 => headlineLarge!;
  TextStyle get h2 => headlineMedium!;
  TextStyle get bodyStrong => bodyLarge!;
  TextStyle get body => bodyMedium!;
  TextStyle get caption => bodySmall!;
  TextStyle get overline => labelSmall!;
}
