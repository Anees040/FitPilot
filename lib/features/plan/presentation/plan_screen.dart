import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';

import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/select_chip.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/fade_scroll_row.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import '../../../core/ui/exercise_media.dart';


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
    if (state.frame == BurnPlanFrame.allClear) {
      return EmptyState(
        message: 'No burn plan needed today. You have a cheat tolerance if you go a bit over.',
        buttonLabel: 'Looking good!',
        illustration: 'burn_smart',
        isColoredImage: true,
        onAction: () => context.go('/today'),
      );
    }

    if (state.frame == BurnPlanFrame.cleanDay) {
      return EmptyState(
        message: 'A perfect clean day with no logged meals. Keep it up!',
        buttonLabel: 'Great job!',
        illustration: 'goal_maintain',
        isColoredImage: true,
        onAction: () => context.go('/today'),
      );
    }

    // Surplus Today or Yesterday
    final isYesterday = state.frame == BurnPlanFrame.yesterdayDebt;
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
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
        Text('AVAILABLE ACTIVITIES', style: theme.textTheme.overline),
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
        Text('Pick ONE — each option clears your surplus on its own.', style: theme.textTheme.caption),
        const SizedBox(height: 8),
        ...state.options.map(
          (option) => _ExpandableOptionCard(option: option),
        ),
      ],
    );
  }

  Widget _buildTargetSelector(BuildContext context, WidgetRef ref, BurnPlanState state) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final todayState = ref.watch(todayProvider).valueOrNull;
    final logs = todayState?.logs ?? [];
    
    // Total debt
    final totalToBurn = todayState?.dayStatus.toBurn ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TARGET', style: theme.textTheme.overline),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: state.selectedMealId,
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
              if (logs.isNotEmpty)
                const DropdownMenuItem(
                  enabled: false,
                  child: Divider(),
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

class _ExpandableOptionCard extends ConsumerStatefulWidget {
  final BurnOption option;

  const _ExpandableOptionCard({required this.option});

  @override
  ConsumerState<_ExpandableOptionCard> createState() => _ExpandableOptionCardState();
}

class _ExpandableOptionCardState extends ConsumerState<_ExpandableOptionCard> {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final option = widget.option;
    final isWalking = option.activity.contains('Walking');
    
    String subtitle;
    if (option.sessions > 1) {
      subtitle = '${option.sessions} × ${option.minutesPerSession} min over ${option.sessions} days';
    } else {
      subtitle = isWalking && option.steps != null
          ? '${option.minutes} min • ~${option.steps} steps'
          : '${option.minutes} min';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        onTap: _toggleExpand,
        child: Column(
          children: [
            Row(
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
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: ext.textDisabled,
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'See details',
                      onPressed: option.exerciseId != null
                          ? () => context.push('/exercises/${option.exerciseId}')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Mark Done',
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        ref.read(burnPlanProvider.notifier).markDone(option);
                        AppSnackbar.success(context, 'Marked ${option.activity} as done!');
                        context.go('/today'); // Return to Today to see the ring fill
                      },
                    ),
                  ),
                ],
              ),
            ],
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
