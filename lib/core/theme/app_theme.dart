import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color scaffoldBackground = Color(0xFFFAFAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF6B6862);
  static const Color hairline = Color(0xFFE8E6E1);
  static const Color accent = Color(0xFFD9531E);
  static const Color success = Color(0xFF3A7D44);
  static const Color warning = Color(0xFFB7791F);
  static const Color error = Color(0xFFA63232);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: primaryText,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 40, color: primaryText),
        titleLarge: GoogleFonts.inter(
          fontSize: 22,
          color: primaryText,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 17, color: primaryText),
        bodyMedium: GoogleFonts.inter(fontSize: 15, color: secondaryText),
        bodySmall: GoogleFonts.inter(fontSize: 13, color: secondaryText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
