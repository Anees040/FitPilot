import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/exercise_media.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';

/// Provider that loads a single exercise by id.
final exerciseDetailProvider = FutureProvider.family<Exercise?, String>(
  (ref, id) async {
    final repo = await ref.watch(exerciseRepositoryProvider.future);
    return repo.byId(id);
  },
);

class ExerciseDetailScreen extends ConsumerWidget {
  final String exerciseId;

  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(exerciseDetailProvider(exerciseId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: exerciseAsync.whenData((e) => e?.name ?? '').valueOrNull != null
            ? Text(
                exerciseAsync.value!.name,
                style: theme.textTheme.h1,
              )
            : null,
        centerTitle: false,
      ),
      body: SafeArea(
        child: exerciseAsync.when(
          data: (exercise) {
            if (exercise == null) {
              return ErrorState(
                reason: 'Exercise not found.',
                onRetry: () => ref.invalidate(exerciseDetailProvider(exerciseId)),
              );
            }
            return _DetailBody(exercise: exercise);
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonList(count: 5),
          ),
          error: (e, st) => ErrorState(
            reason: 'Failed to load exercise.\n$e',
            onRetry: () => ref.invalidate(exerciseDetailProvider(exerciseId)),
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Exercise exercise;

  const _DetailBody({required this.exercise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final profileAsync = ref.watch(profileProvider);
    final burnStateAsync = ref.watch(burnPlanProvider);

    final weightKg = profileAsync.valueOrNull?.weightKg ?? 70.0;
    final burnPer10Min = exercise.kcalPer10Min(weightKg);

    int kcalToBurn = 0;
    int minutesToBurn = 0;
    bool hasSurplus = false;
    final burnState = burnStateAsync.valueOrNull;
    final isBurnPlan = burnState != null &&
        (burnState.frame == BurnPlanFrame.burnToday ||
         burnState.frame == BurnPlanFrame.yesterdayDebt);
    
    if (isBurnPlan) {
      hasSurplus = true;
      kcalToBurn = burnState.kcalToBurnOrEat;
      minutesToBurn = exercise.minutesToBurn(weightKg, kcalToBurn);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Media header (16:10 ratio)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ExerciseMedia(
                    exercise: exercise,
                    width: double.infinity,
                    borderRadius: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(exercise.name, style: theme.textTheme.h1),
              const SizedBox(height: 8),

              // Tags
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Tag(label: exercise.category.name[0].toUpperCase() +
                      exercise.category.name.substring(1)),
                  _Tag(label: exercise.difficultyLabel),
                  if (exercise.primaryMuscles.isNotEmpty)
                    _Tag(label: exercise.primaryMuscles.join(' & ')),
                ],
              ),
              const SizedBox(height: 16),

              // Personalized burn line
              AppCard(
                color: ext.accentSoft,
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Burns ~$burnPer10Min kcal in 10 min at your weight',
                        style: theme.textTheme.bodyStrong.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Difficulty dots + pace tier
              Row(
                children: [
                  ...List.generate(3, (i) {
                    final filled = i < exercise.difficulty;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? theme.colorScheme.primary
                              : ext.hairline,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    _paceLabel(exercise.paceTier),
                    style: theme.textTheme.caption,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // How to do it
              if (exercise.steps.isNotEmpty) ...[
                Text('How to do it', style: theme.textTheme.h2),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: exercise.steps.asMap().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key < exercise.steps.length - 1 ? 12 : 0,
                        ),
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: theme.textTheme.body,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Avoid these mistakes
              if (exercise.mistakes.isNotEmpty) ...[
                Text('Avoid these mistakes', style: theme.textTheme.h2),
                const SizedBox(height: 12),
                ...exercise.mistakes.map((mistake) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      color: ext.warning.withValues(alpha: 0.08),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: ext.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              mistake,
                              style: theme.textTheme.body.copyWith(
                                color: ext.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],

              // Watch demo button
              if (exercise.videoUrl != null &&
                  exercise.videoUrl!.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(exercise.videoUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Watch demo'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: ext.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Bottom padding for pinned button
              if (hasSurplus) const SizedBox(height: 80),
            ],
          ),
        ),

        // Bottom pinned burn action button
        if (hasSurplus)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: ext.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: Builder(
                builder: (context) {
                  int sessions = 1;
                  int minutesPerSession = minutesToBurn;
                  int totalMinutes = minutesToBurn;

                  if (totalMinutes > 90) {
                    sessions = (totalMinutes / 90.0).ceil();
                    minutesPerSession = ((totalMinutes / sessions) / 5.0).round() * 5;
                    totalMinutes = sessions * minutesPerSession;
                  }
                  
                  final label = sessions > 1
                      ? 'Burn $kcalToBurn with this — $sessions × $minutesPerSession min'
                      : 'Burn $kcalToBurn with this — $totalMinutes min';

                  return PrimaryButton(
                    label: label,
                    onPressed: () {
                      final option = BurnOption(
                        activity: exercise.name,
                        minutes: totalMinutes,
                        kcal: kcalToBurn,
                        sessions: sessions,
                        minutesPerSession: minutesPerSession,
                      );
                      ref.read(burnPlanProvider.notifier).markDone(option);
                  ref.invalidate(todayProvider);
                  AppSnackbar.success(
                    context,
                    'Marked ${exercise.name} as done! 💪',
                  );
                  context.pop();
                },
              );
            },
          ),
        ),
      ),
      ],
    );
  }

  String _paceLabel(String paceTier) {
    switch (paceTier) {
      case 'quick':
        return 'Quick burn';
      case 'moderate':
        return 'Moderate';
      case 'easy':
        return 'Easy pace';
      default:
        return 'Moderate';
    }
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ext.hairline),
        color: theme.colorScheme.surface,
      ),
      child: Text(
        label,
        style: theme.textTheme.caption.copyWith(fontSize: 12),
      ),
    );
  }
}
