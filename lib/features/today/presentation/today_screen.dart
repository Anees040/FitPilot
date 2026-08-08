import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';

import 'package:fitpilot/core/ui/states.dart';

import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/staggered_list.dart';
import 'package:fitpilot/core/ui/semicircle_progress.dart';
import 'package:fitpilot/core/ui/profile_avatar.dart';
import 'package:fitpilot/features/programs/presentation/widgets/training_program_card.dart';
import 'package:fitpilot/features/today/presentation/widgets/log_list_item.dart';

/// How many meals the Today summary shows before deferring to "View all".
///
/// Deliberately one: Today's job is to surface the ring and the main action
/// cards without a scroll, so the meal list stays a single-row teaser and the
/// full list lives on its own screen.
const int kTodayMealPreviewCount = 1;

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(todayProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      // Ask Coach. Today already reserves 100px of bottom padding below its
      // last card, so the button floats over empty space rather than content,
      // and this Scaffold sits inside the shell so it clears the bottom nav.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4),
        child: Tooltip(
          message: 'Ask Coach',
          child: FloatingActionButton(
            heroTag: 'today-coach-fab',
            onPressed: () => context.push('/coach'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            elevation: 4,
            child: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 24,
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: stateAsync.when(
          data: (state) {
            final profile = profileAsync.valueOrNull;
            final weightKg = profile?.weightKg ?? 70.0;
            final name = profile?.name;

            final logs = state.logs;
            final previewCount = logs.length < kTodayMealPreviewCount
                ? logs.length
                : kTodayMealPreviewCount;
            // The full list is always one tap away once anything is logged,
            // since the preview only ever shows the most recent meal.
            final showViewAll = logs.isNotEmpty;
            final hiddenMealCount = logs.length - previewCount;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _HeroSection(
                      status: state.dayStatus,
                      userName: name,
                      avatarUrl: profile?.avatarUrl,
                      profile: profile,
                    ),
                  ),
                ),

                // Meals sit directly under the ring: it is the list users
                // check most, so it earns the space above the fold.
                if (logs.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Today\'s meals',
                              style: theme.textTheme.h2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showViewAll)
                            _ViewAllButton(
                              count: logs.length,
                              onTap: () => context.push('/meals'),
                            ),
                        ],
                      ),
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
                            child: LogListItem(
                              log: logs[index],
                              weightKg: weightKg,
                            ),
                          ),
                        ),
                        childCount: previewCount,
                      ),
                    ),
                  ),
                  if (hiddenMealCount > 0)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          '+ $hiddenMealCount more logged today',
                          style: theme.textTheme.caption,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],

                // Only renders once enrolled — the Planner tile below is the
                // discovery path, so an extra promo here would be noise.
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverToBoxAdapter(
                    child: TrainingProgramCard(hidePromo: true),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Text('Tools & Features', style: theme.textTheme.h2),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ImageCard(
                                title: 'Workout\nHub',
                                imagePath:
                                    'assets/illustrations/today_workout_hub.png',
                                onTap: () => context.push('/workout-hub'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ImageCard(
                                title: 'Machine\nScanner',
                                imagePath:
                                    'assets/illustrations/today_machine_scanner.png',
                                onTap: () => context.push('/machine-scanner'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _ImageCard(
                          title: 'Training\nPrograms',
                          imagePath: 'assets/illustrations/athletic_hero.png',
                          // Programs is a tab now: switch to it rather than
                          // pushing a second copy over the shell.
                          onTap: () => context.go('/programs'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

/// Pill affordance that opens the full meal list.
class _ViewAllButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ViewAllButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Material(
      color: ext.accentSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View all ($count)',
                style: theme.textTheme.caption.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends ConsumerWidget {
  final DayStatus status;
  final String? userName;
  final String? avatarUrl;
  final Profile? profile;

  const _HeroSection({
    required this.status,
    this.userName,
    this.avatarUrl,
    this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    final bool isAllClear = status.state == DayState.cleared;
    final bool isCleanDay = status.state == DayState.noData;

    // Track the user's own daily limit (target + wiggle room) so the ring
    // means something; 2000 is only the fallback before a profile loads.
    final targetKcal = (profile?.effectiveDailyLimit ?? 2000).toDouble();
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
                      '${userName?.split(' ').first ?? 'Pilot'} 👋',
                      style: theme.textTheme.h1.copyWith(color: theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {
                      context.push('/notifications');
                    },
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: ProfileAvatar(
                      avatarUrl: avatarUrl,
                      name: userName,
                      radius: 18.0,
                    ),
                  ),
                ],
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
          const SizedBox(height: 24),
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
              errorBuilder: (context, error, stackTrace) => Container(
                color: Theme.of(context).colorScheme.primary,
              ),
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
