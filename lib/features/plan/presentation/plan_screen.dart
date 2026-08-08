import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';

import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/select_chip.dart';
import 'package:fitpilot/core/ui/fade_scroll_row.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/progress_ring.dart';
import 'package:fitpilot/features/programs/presentation/widgets/training_program_card.dart';
import 'package:fitpilot/features/plan/presentation/widgets/burn_log_sheet.dart';
import '../../../core/ui/exercise_media.dart';


/// Entry to the budget protein guide.
///
/// Sits on Plan because burning a surplus and eating enough protein are the
/// same job: someone in a deficit without protein loses muscle along with the
/// fat, which is the opposite of what the plan is for.
class EatForResultsCard extends StatelessWidget {
  const EatForResultsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/protein-guide'),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ext.energy.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.egg_alt_outlined, color: ext.energy, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Eat for results', style: theme.textTheme.h2),
                const SizedBox(height: 3),
                Text(
                  'Cheap protein, no powders needed',
                  style: theme.textTheme.caption,
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

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(burnPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Burn Plan', style: theme.textTheme.h1),
        centerTitle: false,
      ),
      body: SafeArea(
        child: stateAsync.hasValue
            ? _buildBody(context, ref, stateAsync.value!)
            : stateAsync.hasError
                ? ErrorState(
                    reason: 'Failed to load plan.\n${stateAsync.error}',
                    onRetry: () => ref.invalidate(burnPlanProvider),
                  )
                : const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SkeletonList(count: 3),
                  ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BurnPlanState state) {
    if (!state.hasExercises) {
      return ErrorState(
        reason: 'Exercise library didn\'t load.\n${ref.watch(seedStatusProvider) ?? "Please try reloading."}',
        onRetry: () async {
          ref.invalidate(databaseProvider);
        },
      );
    }

    if (state.frame == BurnPlanFrame.allClear) {
      final theme = Theme.of(context);
      final ext = theme.extension<AppColors>()!;
      return ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          AppCard(
            color: ext.success.withValues(alpha: 0.1),
            child: Column(
              children: [
                Icon(Icons.check_circle, size: 64, color: ext.success),
                const SizedBox(height: 16),
                Text('Surplus cleared!', style: theme.textTheme.h1),
                const SizedBox(height: 8),
                Text(
                  '${state.burnedToday} kcal burned today.\nYour streak is safe 🔥',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'See progress',
                  onPressed: () => context.go('/progress'),
                ),
              ],
            ),
          ),
          if (state.todayBurns.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildDoneTodaySection(context, state),
          ],
          const SizedBox(height: 24),
          const TrainingProgramCard(),
          if (state.options.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionHeader(
              icon: Icons.auto_awesome,
              label: 'EXTRA CREDIT',
            ),
            const SizedBox(height: 4),
            Text(
              'Nothing left to burn — anything from here is a bonus.',
              style: theme.textTheme.caption,
            ),
            const SizedBox(height: 12),
            ...state.options.map(
              (option) => _BurnOptionCard(option: option, isExtraCredit: true),
            ),
          ],
          const SizedBox(height: 24),
          const EatForResultsCard(),
        ],
      );
    }

    if (state.frame == BurnPlanFrame.cleanDay && state.options.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          EmptyState(
            message: 'A perfect clean day with no logged meals. Keep it up!',
            buttonLabel: 'Great job!',
            illustration: 'goal_maintain',
            isColoredImage: true,
            onAction: () => context.go('/today'),
          ),
          const SizedBox(height: 8),
          const TrainingProgramCard(),
          const SizedBox(height: 16),
          const EatForResultsCard(),
        ],
      );
    }

    // Surplus Today or Yesterday
    final isYesterday = state.frame == BurnPlanFrame.yesterdayDebt;
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _BurnGoalHero(state: state, isYesterday: isYesterday),
        const SizedBox(height: 20),
        const TrainingProgramCard(),
        const SizedBox(height: 20),
        if (!isYesterday) _buildTargetSelector(context, ref, state),
        if (isYesterday)
          AppCard(
            color: ext.warning.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: ext.warning, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You were ${state.kcalToBurnOrEat} kcal over yesterday.',
                        style: theme.textTheme.bodyStrong.copyWith(color: ext.warning),
                      ),
                      Text(
                        'Burn it now to save your streak.',
                        style: theme.textTheme.caption.copyWith(color: ext.warning),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const _SectionHeader(
          icon: Icons.fitness_center,
          label: 'AVAILABLE ACTIVITIES',
        ),
        const SizedBox(height: 12),
        _buildCategoryFilters(context, ref),
        if (state.kcalToBurnOrEat > 2000)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: AppCard(
              color: ext.surfaceRaised,
              child: Text(
                "Big day. Spread the burn over a few days — or let tomorrow's budget absorb part of it.",
                style: theme.textTheme.caption,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Pick one and log the time you actually did — partial sessions count too.',
          style: theme.textTheme.caption,
        ),
        const SizedBox(height: 8),
        ...state.options.map(
          (option) => _BurnOptionCard(option: option),
        ),
        if (state.todayBurns.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildDoneTodaySection(context, state),
        ],
        const SizedBox(height: 24),
        const EatForResultsCard(),
      ],
    );
  }

  Widget _buildDoneTodaySection(BuildContext context, BurnPlanState state) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.check_circle_outline,
          label: 'DONE TODAY',
          color: ext.success,
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ...state.todayBurns.take(5).map((burn) {
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ext.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 18, color: ext.success),
                  ),
                  title: Text(burn.activity, style: theme.textTheme.bodyStrong),
                  subtitle: Text(
                    '${burn.minutes} min',
                    style: theme.textTheme.caption,
                  ),
                  trailing: Text(
                    '${burn.kcal} kcal',
                    style: theme.textTheme.bodyMedium!.copyWith(color: ext.success),
                  ),
                );
              }),
              if (state.todayBurns.length > 5)
                ListTile(
                  title: Text('...and ${state.todayBurns.length - 5} more', style: theme.textTheme.caption),
                ),
              const Divider(height: 1),
              ListTile(
                title: Text('Total Burned', style: theme.textTheme.bodyStrong),
                trailing: Text(
                  '${state.burnedToday} kcal',
                  style: theme.textTheme.bodyStrong.copyWith(color: ext.success),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetSelector(BuildContext context, WidgetRef ref, BurnPlanState state) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final todayState = ref.watch(todayProvider).valueOrNull;
    final logs = todayState?.logs ?? [];
    
    final totalToBurn = todayState?.dayStatus.toBurn ?? 0;
    final validSelectedMealId = (state.selectedMealId != null && logs.any((l) => l.id == state.selectedMealId))
        ? state.selectedMealId
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: Icons.my_location, label: 'TARGET'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: validSelectedMealId,
            decoration: InputDecoration(
              filled: true,
              fillColor: ext.surfaceRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            dropdownColor: ext.surfaceRaised,
            style: theme.textTheme.bodyStrong,
            icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text('All of today ($totalToBurn kcal)'),
              ),
              ...logs.map((log) {
                return DropdownMenuItem(
                  value: log.id,
                  child: Text('${log.customName ?? log.foodName} (${log.kcal.midpoint} kcal)'),
                );
              }),
            ],
            onChanged: (value) {
              ref.read(burnPlanMealIdProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 8),
          Text(
            state.selectedMealId == null
                ? 'Pick an activity to clear your total debt.'
                : 'Pick an activity to clear this specific meal.',
            style: theme.textTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(BuildContext context, WidgetRef ref) {
    final currentCat = ref.watch(burnCategoryFilterProvider);
    final currentPace = ref.watch(burnPaceFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeScrollRow(
          children: [
            _buildFilterChip(
              label: 'Recommended',
              isSelected: currentCat == null || currentCat == 'recommended',
              onTap: () => ref.read(burnCategoryFilterProvider.notifier).state = 'recommended',
            ),
            _buildFilterChip(
              label: 'Gym',
              isSelected: currentCat == 'gym',
              onTap: () => ref.read(burnCategoryFilterProvider.notifier).state = 'gym',
            ),
            _buildFilterChip(
              label: 'Indoor',
              isSelected: currentCat == 'indoor',
              onTap: () => ref.read(burnCategoryFilterProvider.notifier).state = 'indoor',
            ),
            _buildFilterChip(
              label: 'Outdoor',
              isSelected: currentCat == 'outdoor',
              onTap: () => ref.read(burnCategoryFilterProvider.notifier).state = 'outdoor',
            ),
            _buildFilterChip(
              label: 'Calisthenics',
              isSelected: currentCat == 'calisthenics',
              onTap: () => ref.read(burnCategoryFilterProvider.notifier).state = 'calisthenics',
            ),
          ],
        ),
        const SizedBox(height: 8),
        FadeScrollRow(
          children: [
            _buildFilterChip(
              label: 'Any pace',
              isSelected: currentPace == null || currentPace == 'any',
              onTap: () => ref.read(burnPaceFilterProvider.notifier).state = 'any',
            ),
            _buildFilterChip(
              label: 'Quick burn',
              isSelected: currentPace == 'quick',
              onTap: () => ref.read(burnPaceFilterProvider.notifier).state = 'quick',
            ),
            _buildFilterChip(
              label: 'Moderate',
              isSelected: currentPace == 'moderate',
              onTap: () => ref.read(burnPaceFilterProvider.notifier).state = 'moderate',
            ),
            _buildFilterChip(
              label: 'Easy pace',
              isSelected: currentPace == 'easy',
              onTap: () => ref.read(burnPaceFilterProvider.notifier).state = 'easy',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: SelectChip(
        label: label,
        isSelected: isSelected,
        onSelected: onTap,
      ),
    );
  }
}

/// Headline card for the surplus frames.
///
/// The kcal figure used to live only inside the target dropdown's label, which
/// buried the one number the screen exists to communicate. This puts it up
/// front with a ring so progress is legible at a glance.
class _BurnGoalHero extends StatelessWidget {
  final BurnPlanState state;
  final bool isYesterday;

  const _BurnGoalHero({required this.state, required this.isYesterday});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    final toGo = state.kcalToBurnOrEat;
    final burned = state.burnedToday;
    final goal = burned + toGo;
    final progress = goal > 0 ? (burned / goal).clamp(0.0, 1.0) : 0.0;
    final accent = isYesterday ? ext.warning : theme.colorScheme.primary;

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: ProgressRing(
              progress: progress,
              strokeWidth: 7,
              color: accent,
              backgroundColor: ext.hairline,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 18,
                      color: accent,
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.bodyStrong.copyWith(color: accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isYesterday ? 'LEFT FROM YESTERDAY' : 'LEFT TO BURN',
                  style: theme.textTheme.overline,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$toGo',
                      style: theme.textTheme.h1.copyWith(color: accent),
                    ),
                    const SizedBox(width: 4),
                    Text('kcal', style: theme.textTheme.caption),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: ext.success),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$burned of $goal kcal done',
                        style: theme.textTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Overline section label with a leading icon, so the long scroll reads as
/// distinct blocks instead of a wall of uppercase text.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _SectionHeader({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: 14, color: tint),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.overline.copyWith(color: tint)),
      ],
    );
  }
}

/// Small icon + label chip used on the activity cards.
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BurnOptionCard extends ConsumerWidget {
  final BurnOption option;
  final bool isExtraCredit;

  const _BurnOptionCard({required this.option, this.isExtraCredit = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isWalking = option.activity.contains('Walking');
    final isBusy = ref.watch(burnPlanProvider).valueOrNull?.busyOptionIds
            .contains(option.activity) ??
        false;

    // Extra-credit options carry a nominal reference kcal, so surfacing it
    // would misrepresent what gets logged — the sheet computes the real value.
    final pills = <Widget>[
      if (isExtraCredit)
        _InfoPill(
          icon: Icons.add_circle_outline,
          label: 'Log any duration',
          color: theme.colorScheme.primary,
          background: ext.accentSoft,
        )
      else ...[
        _InfoPill(
          icon: Icons.schedule,
          label: option.sessions > 1
              ? '${option.sessions} × ${option.minutesPerSession} min'
              : '${option.minutes} min',
          color: theme.colorScheme.onSurfaceVariant,
          background: ext.surfaceRaised,
        ),
        _InfoPill(
          icon: Icons.local_fire_department,
          label: '${option.kcal} kcal',
          color: ext.energy,
          background: ext.energySoft,
        ),
        if (isWalking && option.steps != null)
          _InfoPill(
            icon: Icons.directions_walk,
            label: '~${option.steps} steps',
            color: theme.colorScheme.onSurfaceVariant,
            background: ext.surfaceRaised,
          ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        onTap: isBusy
            ? null
            : () => BurnLogSheet.show(
                  context,
                  option: option,
                  isExtraCredit: isExtraCredit,
                ),
        child: Row(
          children: [
            if (option.mediaAsset != null)
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.only(right: 16),
                child: ExerciseMedia.asset(
                  mediaAsset: option.mediaAsset!,
                  borderRadius: 12,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          option.activity,
                          style: theme.textTheme.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (option.difficulty != null) ...[
                        const SizedBox(width: 8),
                        _buildDifficultyDots(option.difficulty!, theme, ext),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: pills),
                  if (option.sessions > 1) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Spread over ${option.sessions} days',
                      style: theme.textTheme.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: ext.textDisabled),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyDots(int difficulty, ThemeData theme, AppColors ext) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final active = index < difficulty;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? theme.colorScheme.primary : ext.hairline,
          ),
        );
      }),
    );
  }
}
