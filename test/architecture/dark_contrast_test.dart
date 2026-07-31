import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

/// WCAG AA contrast ratio requirements:
/// - Normal text (< 18sp or < 14sp bold): 4.5:1
/// - Large text (>= 18sp or >= 14sp bold): 3.0:1

double _relativeLuminance(Color color) {
  double linearize(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  // Use sRGB values normalized to 0-1
  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA contrast — Light theme', () {
    // Body text pairs (4.5:1 minimum)
    final bodyPairs = <String, List<Color>>{
      'text on bg': [AppTheme.lightText, AppTheme.lightBg],
      'text on surface': [AppTheme.lightText, AppTheme.lightSurface],
      'textSecondary on bg': [AppTheme.lightTextSecondary, AppTheme.lightBg],
      'textSecondary on surface': [
        AppTheme.lightTextSecondary,
        AppTheme.lightSurface
      ],
      'error on surface': [AppTheme.lightError, AppTheme.lightSurface],
      'success on surface': [AppTheme.lightSuccess, AppTheme.lightSurface],
      'warning on surface': [AppTheme.lightWarning, AppTheme.lightSurface],
    };

    for (final entry in bodyPairs.entries) {
      test('${entry.key} >= 4.5:1', () {
        final ratio = contrastRatio(entry.value[0], entry.value[1]);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason:
                '${entry.key}: ratio $ratio < 4.5:1 (fg=${entry.value[0]}, bg=${entry.value[1]})');
      });
    }

    // Large text / icon pairs (3.0:1 minimum)
    final largePairs = <String, List<Color>>{
      'accent on bg': [AppTheme.lightAccent, AppTheme.lightBg],
      'accent on surface': [AppTheme.lightAccent, AppTheme.lightSurface],
      'white on accent (button)': [Colors.white, AppTheme.lightAccent],
    };

    for (final entry in largePairs.entries) {
      test('${entry.key} >= 3.0:1', () {
        final ratio = contrastRatio(entry.value[0], entry.value[1]);
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason:
                '${entry.key}: ratio $ratio < 3.0:1 (fg=${entry.value[0]}, bg=${entry.value[1]})');
      });
    }
  });

  group('WCAG AA contrast — Dark theme', () {
    // Body text pairs (4.5:1 minimum)
    final bodyPairs = <String, List<Color>>{
      'text on bg': [AppTheme.darkText, AppTheme.darkBg],
      'text on surface': [AppTheme.darkText, AppTheme.darkSurface],
      'text on surfaceRaised': [AppTheme.darkText, AppTheme.darkSurfaceRaised],
      'textSecondary on bg': [AppTheme.darkTextSecondary, AppTheme.darkBg],
      'textSecondary on surface': [
        AppTheme.darkTextSecondary,
        AppTheme.darkSurface
      ],
      'textSecondary on surfaceRaised': [
        AppTheme.darkTextSecondary,
        AppTheme.darkSurfaceRaised
      ],
      'error on surface': [AppTheme.darkError, AppTheme.darkSurface],
      'success on surface': [AppTheme.darkSuccess, AppTheme.darkSurface],
      'warning on surface': [AppTheme.darkWarning, AppTheme.darkSurface],
    };

    for (final entry in bodyPairs.entries) {
      test('${entry.key} >= 4.5:1', () {
        final ratio = contrastRatio(entry.value[0], entry.value[1]);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason:
                '${entry.key}: ratio $ratio < 4.5:1 (fg=${entry.value[0]}, bg=${entry.value[1]})');
      });
    }

    // Large text / icon pairs (3.0:1 minimum)
    final largePairs = <String, List<Color>>{
      'accent on bg': [AppTheme.darkAccent, AppTheme.darkBg],
      'accent on surface': [AppTheme.darkAccent, AppTheme.darkSurface],
      'accent on surfaceRaised': [
        AppTheme.darkAccent,
        AppTheme.darkSurfaceRaised
      ],
      'white on accent (button)': [Colors.white, AppTheme.darkAccent],
      'highlight on surface': [AppTheme.darkHighlight, AppTheme.darkSurface],
    };

    for (final entry in largePairs.entries) {
      test('${entry.key} >= 3.0:1', () {
        final ratio = contrastRatio(entry.value[0], entry.value[1]);
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason:
                '${entry.key}: ratio $ratio < 3.0:1 (fg=${entry.value[0]}, bg=${entry.value[1]})');
      });
    }
  });
}
