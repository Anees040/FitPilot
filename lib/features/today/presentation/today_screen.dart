import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';

import 'package:fitpilot/features/log/presentation/widgets/kcal_range_text.dart';
import 'package:fitpilot/features/log/presentation/quantity_sheet.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';

import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/staggered_list.dart';
import 'package:intl/intl.dart';
import 'package:fitpilot/core/ui/semicircle_progress.dart';
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(todayProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: stateAsync.when(
          data: (state) {
            final profile = profileAsync.valueOrNull;
            final weightKg = profile?.weightKg ?? 70.0;
            final name = profile?.name;
            
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _HeroSection(
                      status: state.dayStatus,
                      userName: name,
                    ),
                  ),
                ),
                
                if (state.logs.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    sliver: SliverToBoxAdapter(
                      child: Text('Today\'s meals', style: theme.textTheme.h2),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: StaggeredEntrance(
                            index: index,
                            child: _LogListItem(
                              log: state.logs[index],
                              weightKg: weightKg,
                            ),
                          ),
                        ),
                        childCount: state.logs.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverToBoxAdapter(
                    child: Text('Tools & Features', style: theme.textTheme.h2),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _ImageCard(
                          title: 'Workout Hub',
                          imagePath: 'assets/illustrations/workout_hub_bg.png',
                          onTap: () => context.push('/workout-hub'),
                        ),
                        const SizedBox(height: 16),
                        _ImageCard(
                          title: 'Machine Scanner',
                          imagePath: 'assets/illustrations/machine_scanner_bg.png',
                          onTap: () => context.push('/capture'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: SkeletonList(count: 3),
          ),
          error: (error, stack) => ErrorState(
            reason: 'Failed to load today\'s data.\n$error',
            onRetry: () => ref.invalidate(todayProvider),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends ConsumerWidget {
  final DayStatus status;
  final String? userName;

  const _HeroSection({required this.status, this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    final bool isAllClear = status.state == DayState.cleared;
    final bool isCleanDay = status.state == DayState.noData;
    
    // Using a target of 2000 for visual progress if we don't have a specific target
    // We can also just use the upper bound of the wiggle room or target.
    final targetKcal = 2000.0;
    double progress = (status.total.min / targetKcal).clamp(0.0, 1.0);
    final ringColor = ext.energy;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning',
                      style: theme.textTheme.caption,
                    ),
                    Text(
                      '${userName ?? 'Pilot'} 👋',
                      style: theme.textTheme.h1.copyWith(color: theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 28),
                onPressed: () {
                  AppSnackbar.success(context, 'No new notifications');
                },
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, size: 28),
                onPressed: () => context.push('/capture'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SemicircleProgress(
            progress: progress,
            activeColor: ringColor,
            backgroundColor: ext.hairline.withValues(alpha: 0.5),
            strokeWidth: 20,
            radius: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Today\'s Intake', style: theme.textTheme.caption),
                const SizedBox(height: 8),
                Text(
                  '${status.total.min} - ${status.total.max}',
                  style: theme.textTheme.display.copyWith(
                    fontSize: 40, 
                    height: 1.0,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text('kcal', style: theme.textTheme.caption),
              ],
            ),
          ),
          const SizedBox(height: 16),
            const SizedBox(height: 32),
            if (isCleanDay)
              Text(
                'Ate something heavy? Log it to start a burn plan.',
                style: theme.textTheme.caption,
                textAlign: TextAlign.center,
              ),
            if (!isCleanDay)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _StatPill(
                      label: 'Eaten',
                      value: status.total.midpoint.toString(),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      label: 'Burned',
                      value: status.burnedKcal.toString(),
                      color: ext.energy,
                    ),
                  ),
                ],
              ),
          if (!isCleanDay && !isAllClear) ...[
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'See burn plan',
              onPressed: () {
                ref.read(burnPlanMealIdProvider.notifier).state = null;
                context.go('/plan');
              },
            ),
          ]
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final VoidCallback onTap;

  const _ImageCard({
    required this.title,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.3),
              BlendMode.darken,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.all(24),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '$label ', 
              style: theme.textTheme.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: theme.textTheme.bodyStrong.copyWith(color: color)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogListItem extends ConsumerWidget {
  final FoodLog log;
  final double weightKg;

  const _LogListItem({required this.log, required this.weightKg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    // Estimate min brisk walk (MET 4.3): min = Kcal * 60 / (4.3 * weight)
    final double met = 4.3;
    final int minWalk = (log.kcal.midpoint * 60 / (met * weightKg)).clamp(1, 999).round();

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: ext.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        child: Icon(Icons.delete, color: theme.colorScheme.onPrimary),
      ),
      onDismissed: (_) {
        ref.read(todayProvider.notifier).deleteLog(log.id);
        AppSnackbar.success(
          context,
          'Meal deleted',
          actionLabel: 'UNDO',
          onAction: () {
            ref.read(todayProvider.notifier).addLog(log.copyWith(deletedAt: null));
          },
        );
      },
      child: AppCard(
        variant: AppCardVariant.raised,
        padding: const EdgeInsets.all(12),
        onTap: () {
          if (log.source == LogSource.manual) {
            AppSnackbar.success(context, 'Cannot edit manual entry quantity.');
            return;
          }

          final dummyFood = FoodItem(
            id: log.foodId ?? '',
            name: log.displayName ?? 'Unknown',
            portionLabel: 'Portion',
            kcalPerPortion: log.kcal.times(1 / log.quantity.toDouble()),
            isVerified: false,
          );

          AppBottomSheet.show(
            context,
            child: QuantitySheet(food: dummyFood),
          );
        },
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary.withValues(alpha: 0.2), theme.colorScheme.primary.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(Icons.fastfood, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.displayName ?? 'Unknown',
                    style: theme.textTheme.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      KcalRangeText(
                        range: log.kcal,
                        style: theme.textTheme.caption.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                      ),
                      Text(' â€¢ ${DateFormat.jm().format(log.loggedAt)}', style: theme.textTheme.caption),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TertiaryButton(
              label: 'Burn it â†’\n~$minWalk min',
              color: ext.energy,
              onPressed: () {
                ref.read(burnPlanMealIdProvider.notifier).state = log.id;
                context.go('/plan');
              },
            ),
          ],
        ),
      ),
     );
  }
}

