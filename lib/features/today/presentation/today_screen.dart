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
import 'package:fitpilot/core/ui/progress_ring.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/staggered_list.dart';
import 'package:intl/intl.dart';


class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
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
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    delegate: SliverChildListDelegate([
                      _FeatureTile(
                        index: 0,
                        icon: Icons.camera_alt,
                        title: 'Snap a meal',
                        subtitle: 'AI estimation',
                        color: ext.accentSoft,
                        iconColor: theme.colorScheme.primary,
                        onTap: () => context.push('/capture'),
                      ),
                      _FeatureTile(
                        index: 1,
                        icon: Icons.qr_code_scanner,
                        title: 'Scan barcode',
                        subtitle: 'Quick log',
                        color: ext.surfaceRaised,
                        iconColor: theme.colorScheme.primary,
                        onTap: () => context.push('/capture'),
                      ),
                      _FeatureTile(
                        index: 2,
                        icon: Icons.document_scanner,
                        title: 'Food label',
                        subtitle: 'OCR scan',
                        color: ext.surfaceRaised,
                        iconColor: theme.colorScheme.primary,
                        onTap: () => context.push('/capture'),
                      ),
                      _FeatureTile(
                        index: 3,
                        icon: Icons.fitness_center,
                        title: 'Exercises',
                        subtitle: 'Library',
                        color: ext.surfaceRaised,
                        iconColor: theme.colorScheme.primary,
                        onTap: () => context.push('/exercises'),
                      ),
                      _FeatureTile(
                        index: 4,
                        icon: Icons.bar_chart,
                        title: 'Progress',
                        subtitle: 'Trends',
                        color: ext.surfaceRaised,
                        iconColor: theme.colorScheme.primary,
                        onTap: () => context.push('/progress'),
                      ),
                      _FeatureTile(
                        index: 5,
                        icon: Icons.precision_manufacturing,
                        title: 'Machine scanner',
                        subtitle: 'Coming soon',
                        color: ext.surfaceRaised,
                        iconColor: ext.textDisabled,
                        isLocked: true,
                        onTap: () {
                          AppBottomSheet.show(context, child: const _ComingSoonSheet());
                        },
                      ),
                    ]),
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
    
    // Calculate progress (0.0 to 1.0). If no data, 0. If cleared, 1. Otherwise ratio of burned / (burned + toBurn).
    double progress = 0.0;
    if (isAllClear) {
      progress = 1.0;
    } else if (!isCleanDay && (status.burnedKcal + status.toBurn) > 0) {
      progress = status.burnedKcal / (status.burnedKcal + status.toBurn);
    }

    final ringColor = isAllClear ? ext.success : ext.energy;

    return AppCard(
      variant: AppCardVariant.hero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
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
                        'Good morning, ${userName ?? 'Pilot'}',
                        style: theme.textTheme.h2.copyWith(color: theme.colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: theme.textTheme.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProgressRing(
                    progress: progress,
                    strokeWidth: 12,
                    color: ringColor,
                    backgroundColor: ext.hairline.withValues(alpha: 0.5),
                    child: Container(), // Empty child
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAllClear) ...[
                          Icon(Icons.local_fire_department, size: 48, color: ext.success),
                          const SizedBox(height: 8),
                          Text('All clear', style: theme.textTheme.caption.copyWith(color: ext.success)),
                        ] else if (isCleanDay) ...[
                          Icon(Icons.check_circle_outline, size: 48, color: ext.textDisabled),
                          const SizedBox(height: 8),
                          Text('Clean day', style: theme.textTheme.caption),
                        ] else ...[
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: status.toBurn.toDouble()),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Text(
                                value.toInt().toString(),
                                style: theme.textTheme.display.copyWith(
                                  fontSize: 48, 
                                  height: 1.0,
                                  color: theme.colorScheme.onSurface,
                                ),
                              );
                            },
                          ),
                          Text('to burn', style: theme.textTheme.caption),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
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

class _FeatureTile extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final bool isLocked;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    this.isLocked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    return StaggeredEntrance(
      index: index,
      child: AnimatedScaleButton(
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ext.hairline, width: 1),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  if (isLocked)
                    Icon(Icons.lock, size: 16, color: ext.textDisabled),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonSheet extends StatelessWidget {
  const _ComingSoonSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.precision_manufacturing, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Machine Scanner', style: theme.textTheme.h1),
          const SizedBox(height: 12),
          Text(
            'Coming in Milestone D! Point your camera at any treadmill or elliptical screen to automatically capture your calories burned.',
            style: theme.textTheme.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Got it',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

