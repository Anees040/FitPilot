import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';

import 'package:fitpilot/features/log/presentation/widgets/kcal_range_text.dart';
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
                
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverToBoxAdapter(
                    child: Text('Tools & Features', style: theme.textTheme.h2),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: _ImageCard(
                            title: 'Workout\nHub',
                            imagePath: 'assets/illustrations/today_workout_hub.png',
                            onTap: () => context.push('/workout-hub'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ImageCard(
                            title: 'Machine\nScanner',
                            imagePath: 'assets/illustrations/today_machine_scanner.png',
                            onTap: () {
                              AppSnackbar.success(context, 'This feature is coming soon!');
                            },
                          ),
                        ),
                      ],
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
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
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
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  context.push('/notifications');
                },
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
                  (status.total.min == 0 && status.total.max == 0)
                      ? '0'
                      : '${status.total.min} - ${status.total.max}',
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
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
            // Gradient overlay for text readability
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x44000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
            ),
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
          AppBottomSheet.show(
            context,
            child: _FoodLogDetailSheet(log: log),
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
                      Text(' \u2022 ${DateFormat.jm().format(log.loggedAt)}', style: theme.textTheme.caption),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                ref.read(burnPlanMealIdProvider.notifier).state = log.id;
                context.go('/plan');
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Burn it \u2192',
                      style: theme.textTheme.bodyStrong.copyWith(color: ext.energy),
                    ),
                    Text(
                      '~$minWalk min',
                      style: theme.textTheme.caption.copyWith(color: ext.energy),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
     );
  }
}

class _FoodLogDetailSheet extends ConsumerStatefulWidget {
  final FoodLog log;
  const _FoodLogDetailSheet({required this.log});

  @override
  ConsumerState<_FoodLogDetailSheet> createState() => _FoodLogDetailSheetState();
}

class _FoodLogDetailSheetState extends ConsumerState<_FoodLogDetailSheet> {
  late double _quantity;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _quantity = widget.log.quantity.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = widget.log;

    final unitKcal = log.kcal.times(1 / (log.quantity == 0 ? 1 : log.quantity));
    final currentKcal = unitKcal.times(_quantity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.fastfood, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.displayName ?? 'Unknown Food',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Logged at ${DateFormat.jm().format(log.loggedAt.toLocal())}',
                    style: theme.textTheme.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Calories', style: theme.textTheme.bodyMedium),
                  KcalRangeText(
                    range: currentKcal,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Portion', style: theme.textTheme.bodyMedium),
                  Text(
                    '${_quantity.toStringAsFixed(1)} x portion',
                    style: theme.textTheme.bodyStrong,
                  ),
                ],
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _quantity <= 0.5 ? null : () => setState(() => _quantity -= 0.5),
                    ),
                    Text(
                      _quantity.toStringAsFixed(1),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _quantity += 0.5),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (!_isEditing) ...[
          PrimaryButton(
            label: 'Edit Portion',
            onPressed: () => setState(() => _isEditing = true),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Delete Log',
            onPressed: () async {
              await ref.read(todayProvider.notifier).deleteLog(log.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                AppSnackbar.success(context, 'Meal deleted');
              }
            },
          ),
        ] else ...[
          PrimaryButton(
            label: 'Save Changes',
            onPressed: () async {
              await ref.read(todayProvider.notifier).updateLogQuantity(log.id, _quantity);
              if (context.mounted) {
                Navigator.of(context).pop();
                AppSnackbar.success(context, 'Portion updated');
              }
            },
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Cancel',
            onPressed: () => setState(() {
              _quantity = log.quantity.toDouble();
              _isEditing = false;
            }),
          ),
        ],
      ],
    );
  }
}

