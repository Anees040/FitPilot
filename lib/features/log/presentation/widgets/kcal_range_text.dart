import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

/// Reusable widget for displaying calorie ranges consistently.
/// It strictly uses KcalRange.format() and applies appropriate typography.
class KcalRangeText extends StatelessWidget {
  final KcalRange range;
  final TextStyle? style;
  final String suffix;

  const KcalRangeText({
    super.key,
    required this.range,
    this.style,
    this.suffix = ' kcal',
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '${range.format()}$suffix',
      style:
          style ??
          AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
