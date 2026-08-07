import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/machine_scanner_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/exercise_media.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';

/// Shows what the scanner found: the machine, the muscles it trains, how to use
/// it, and which FitPilot exercises relate to it.
class MachineResultScreen extends ConsumerWidget {
  final MachineAnalysis analysis;

  /// True when opened from the Recent scans list rather than a fresh scan —
  /// "Scan another" becomes "Scan a machine" and Done pops back to the list.
  final bool fromHistory;

  const MachineResultScreen({
    super.key,
    required this.analysis,
    this.fromHistory = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (!analysis.isGymMachine) {
      return _NotAMachineScreen(analysis: analysis);
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _done(context),
        ),
        title: Text(fromHistory ? 'Saved scan' : 'Machine found'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Header(analysis: analysis),
            const SizedBox(height: 20),
            if (analysis.primaryMuscles.isNotEmpty ||
                analysis.secondaryMuscles.isNotEmpty) ...[
              _MusclesSection(analysis: analysis),
              const SizedBox(height: 20),
            ],
            if (analysis.howToUse.isNotEmpty) ...[
              _NumberedSection(
                title: 'How to use',
                icon: Icons.list_alt_rounded,
                steps: analysis.howToUse,
              ),
              const SizedBox(height: 16),
            ],
            if (analysis.commonMistakes.isNotEmpty) ...[
              _BulletSection(
                title: 'Common mistakes',
                icon: Icons.report_problem_outlined,
                accent: theme.extension<AppColors>()!.warning,
                items: analysis.commonMistakes,
              ),
              const SizedBox(height: 16),
            ],
            if (analysis.safetyTips.isNotEmpty) ...[
              _BulletSection(
                title: 'Safety tips',
                icon: Icons.health_and_safety_outlined,
                accent: theme.extension<AppColors>()!.success,
                items: analysis.safetyTips,
              ),
              const SizedBox(height: 16),
            ],
            _RelatedExercises(analysis: analysis),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: fromHistory ? 'Scan a machine' : 'Scan another',
                    onPressed: () => context.pushReplacement('/machine-scanner/camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Done',
                    onPressed: () => _done(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns to the scanner hub. A fresh scan replaced the camera route, so
  /// popping would land back on the camera — go to the hub explicitly instead.
  void _done(BuildContext context) {
    if (context.canPop() && fromHistory) {
      context.pop();
      return;
    }
    context.go('/machine-scanner');
  }
}

class _Header extends StatelessWidget {
  final MachineAnalysis analysis;

  const _Header({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isHigh = analysis.isHighConfidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          analysis.machineName.isEmpty ? 'Gym machine' : analysis.machineName,
          style: theme.textTheme.h1,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (isHigh ? ext.success : ext.warning).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHigh ? Icons.verified_rounded : Icons.help_outline_rounded,
                size: 13,
                color: isHigh ? ext.success : ext.warning,
              ),
              const SizedBox(width: 5),
              Text(
                '${analysis.confidenceLabel} confidence',
                style: theme.textTheme.caption.copyWith(
                  color: isHigh ? ext.success : ext.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (!isHigh) ...[
          const SizedBox(height: 8),
          Text(
            "Not fully sure about this one — double-check the machine's own label before you start.",
            style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
          ),
        ],
      ],
    );
  }
}

class _MusclesSection extends StatelessWidget {
  final MachineAnalysis analysis;

  const _MusclesSection({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Muscles worked', style: theme.textTheme.h2),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final muscle in analysis.primaryMuscles)
              _MuscleChip(label: muscle, isPrimary: true),
            for (final muscle in analysis.secondaryMuscles)
              _MuscleChip(label: muscle, isPrimary: false),
          ],
        ),
        if (analysis.secondaryMuscles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Filled chips are the main targets; outlined ones assist.',
            style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
          ),
        ],
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _MuscleChip({required this.label, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary ? Colors.transparent : ext.hairline,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.caption.copyWith(
          color: isPrimary ? theme.colorScheme.primary : ext.textDisabled,
          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _NumberedSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> steps;

  const _NumberedSection({
    required this.title,
    required this.icon,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.h2),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.caption.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(steps[i], style: theme.textTheme.body),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<String> items;

  const _BulletSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.h2),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(items[i], style: theme.textTheme.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RelatedExercises extends ConsumerWidget {
  final MachineAnalysis analysis;

  const _RelatedExercises({required this.analysis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final related = ref.watch(relatedExercisesProvider(analysis));

    return related.maybeWhen(
      data: (exercises) {
        if (exercises.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Related exercises in FitPilot', style: theme.textTheme.h2),
            const SizedBox(height: 4),
            Text(
              'Add these to your burn plan to work the same muscles.',
              style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
            ),
            const SizedBox(height: 12),
            for (final exercise in exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExerciseRow(exercise: exercise),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/exercises/${exercise.id}'),
      child: Row(
        children: [
          ExerciseMedia(
            exercise: exercise,
            width: 56,
            height: 56,
            borderRadius: 12,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: theme.textTheme.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    exercise.equipmentLabel,
                    if (exercise.primaryMuscles.isNotEmpty) exercise.primaryMuscles.first,
                  ].join(' • '),
                  style: theme.textTheme.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
        ],
      ),
    );
  }
}

/// Shown when the photo wasn't gym equipment.
class _NotAMachineScreen extends StatelessWidget {
  final MachineAnalysis analysis;

  const _NotAMachineScreen({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final saw = analysis.machineName.trim();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/machine-scanner'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported_outlined, size: 56, color: ext.textDisabled),
              const SizedBox(height: 20),
              Text(
                "That doesn't look like a gym machine",
                style: theme.textTheme.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                saw.isEmpty
                    ? 'Point the camera at a weight machine or piece of cardio equipment and try again.'
                    : 'It looked more like $saw. Point the camera at a weight machine or piece of cardio equipment and try again.',
                style: theme.textTheme.body.copyWith(color: ext.textDisabled),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Retake',
                  onPressed: () => context.pushReplacement('/machine-scanner/camera'),
                ),
              ),
              const SizedBox(height: 12),
              TertiaryButton(
                label: 'Back to scanner',
                onPressed: () => context.go('/machine-scanner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
