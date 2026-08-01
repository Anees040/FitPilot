import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/exercise.dart';

/// Shared widget that displays the exercise media image, falling back
/// to a category-themed line-art icon when the asset is missing.
class ExerciseMedia extends StatelessWidget {
  final Exercise? exercise;
  final String? assetPathOverride;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  const ExerciseMedia({
    super.key,
    required this.exercise,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius = 16,
  }) : assetPathOverride = null;

  const ExerciseMedia.asset({
    super.key,
    required String mediaAsset,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius = 16,
  }) : exercise = null,
       assetPathOverride = mediaAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    final actualAsset = assetPathOverride ?? exercise?.mediaAsset;

    if (actualAsset != null && actualAsset.isNotEmpty) {
      final assetPath = actualAsset.replaceAll('.gif', '.webp');
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/$assetPath',
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(context, ext),
        ),
      );
    }

    return _fallbackIcon(context, ext);
  }

  Widget _fallbackIcon(BuildContext context, AppColors ext) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ext.accentSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          exercise != null ? _categoryIcon(exercise!.category) : Icons.fitness_center,
          size: (height ?? 80) * 0.4,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  static IconData _categoryIcon(ExerciseCategory category) {
    switch (category) {
      case ExerciseCategory.gym:
        return Icons.fitness_center;
      case ExerciseCategory.outdoor:
        return Icons.directions_run;
      case ExerciseCategory.indoor:
        return Icons.home;
      case ExerciseCategory.calisthenics:
        return Icons.accessibility_new;
    }
  }
}
