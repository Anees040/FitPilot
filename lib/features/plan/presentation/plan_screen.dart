import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/select_chip.dart';
import 'package:fitpilot/core/ui/confirm_snackbar.dart';

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
        child: stateAsync.when(
          data: (state) => _buildBody(context, ref, state),
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: SkeletonList(count: 3),
          ),
          error: (e, st) => ErrorState(
            reason: 'Failed to load plan.\n$e',
            onRetry: () => ref.invalidate(burnPlanProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BurnPlanState state) {
    if (state.frame == BurnPlanFrame.noSurplus) {
      return EmptyState(
        message: 'No burn plan needed today. You have a cheat tolerance if you go a bit over.',
        buttonLabel: 'Looking good!',
        illustration: 'empty_plan',
        onAction: () => context.go('/today'),
      );
    }

    if (state.frame == BurnPlanFrame.buildDeficit) {
      return EmptyState(
        message: 'Your goal is to build, so keep eating to hit your target!',
        buttonLabel: 'Keep it up!',
        illustration: 'empty_plan',
        onAction: () => context.go('/today'),
      );
    }

    // Surplus Today or Yesterday
    final isYesterday = state.frame == BurnPlanFrame.surplusYesterday;
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
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
                      isYesterday
                          ? 'You were ${state.kcalToBurnOrEat} kcal over yesterday.'
                          : 'You are ${state.kcalToBurnOrEat} kcal over today.',
                      style: theme.textTheme.bodyStrong.copyWith(color: ext.warning),
                    ),
                    Text(
                      isYesterday
                          ? 'Burn it now to save your streak.'
                          : 'Pick an activity to clear your surplus.',
                      style: theme.textTheme.caption.copyWith(color: ext.warning),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('AVAILABLE ACTIVITIES', style: theme.textTheme.overline),
        const SizedBox(height: 12),
        _buildCategoryFilters(context, ref),
        const SizedBox(height: 16),
        ...state.options.map(
          (option) => _buildOptionCard(context, ref, option),
        ),
      ],
    );
  }

  Widget _buildCategoryFilters(BuildContext context, WidgetRef ref) {
    final currentCat = ref.watch(burnCategoryFilterProvider);
    final currentPace = ref.watch(burnPaceFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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

  Widget _buildOptionCard(
    BuildContext context,
    WidgetRef ref,
    BurnOption option,
  ) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isWalking = option.activity.contains('Walking');
    final subtitle = isWalking && option.steps != null
        ? '${option.minutes} min • ~${option.steps} steps'
        : '${option.minutes} min';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () {
          if (option.exerciseId != null) {
            context.push('/exercises/${option.exerciseId}');
          }
        },
        child: AppCard(
          child: Row(
            children: [
              if (option.mediaAsset != null)
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: ext.hairline,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/${option.mediaAsset!.replaceAll('.gif', '.webp')}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.image_not_supported, color: ext.accentSoft),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          option.activity,
                          style: theme.textTheme.bodyStrong,
                        ),
                        if (option.difficulty != null) ...[
                          const SizedBox(width: 8),
                          _buildDifficultyDots(option.difficulty!, theme, ext),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.caption,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(burnPlanProvider.notifier).markDone(option);
                  confirmSnackbar(context, 'Marked ${option.activity} as done!');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: ext.hairline),
                    color: Colors.transparent,
                  ),
                  child: Text(
                    'Done',
                    style: theme.textTheme.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyStrong.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: theme.textTheme.caption.color),
            ],
          ),
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
