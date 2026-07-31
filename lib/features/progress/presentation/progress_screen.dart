import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/features/progress/presentation/weight_trend_section.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  bool _hasShownMilestone = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Progress', style: theme.textTheme.h1),
        centerTitle: false,
      ),
      body: SafeArea(
        child: stateAsync.when(
          data: (state) => _buildBody(context, state),
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: SkeletonList(count: 4),
          ),
          error: (e, st) => ErrorState(
            reason: 'Failed to load progress.\n$e',
            onRetry: () => ref.invalidate(progressProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProgressState state) {
    if (!_hasShownMilestone && state.streak.currentStreak > 0 && state.streak.currentStreak % 7 == 0) {
      _hasShownMilestone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppSnackbar.success(
          context,
          'Amazing! ${state.streak.currentStreak}-day streak!',
        );
      });
    }

    final hasHistory = state.last35Days.values.any((d) => d.state != DayState.noData);
    
    if (!hasHistory) {
      return EmptyState(
        message: 'No progress history yet. Log your meals to start building your streak and insights!',
        buttonLabel: 'Log today',
        illustration: 'empty_history',
        onAction: () => context.go('/log'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildStreakCard(context, state.streak),
        const SizedBox(height: 24),
        _buildHeatmap(context, state.last35Days),
        const SizedBox(height: 24),
        _build7DayList(context, state.last35Days),
        const SizedBox(height: 24),
        _buildWeeklySummary(context, state),
        const SizedBox(height: 24),
        WeightTrendSection(entries: state.weightEntries),
      ],
    );
  }

  Widget _buildStreakCard(BuildContext context, StreakState streak) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    // UI Spec: flame icon, "12-day streak" display, "Longest: 18 days" caption, 
    // plus the explainer chip: "Days you don't log stay neutral — they never break your streak."

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ext.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_fire_department, color: theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${streak.currentStreak}-day streak',
                      style: theme.textTheme.display.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Longest: ${streak.currentStreak} days', // Placeholder for longest streak
                      style: theme.textTheme.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ext.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Days you don\'t log stay neutral — they never break your streak.',
                    style: theme.textTheme.caption.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context, Map<DateTime, DayStatus> last35Days) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final now = DateTime.now();
    
    // Prepare dates
    final sortedDates = last35Days.keys.toList()..sort();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HEATMAP', style: theme.textTheme.overline.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heatmap Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 35,
                itemBuilder: (context, index) {
                  if (index < 7) {
                    // Weekday headers
                    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    return Center(
                      child: Text(
                        weekdays[index],
                        style: theme.textTheme.overline.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  
                  final dateIndex = index - 7;
                  if (dateIndex >= sortedDates.length) return const SizedBox();
                  
                  final date = sortedDates[dateIndex];
                  final status = last35Days[date]!;
                  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                  
                  Widget dot;
                  if (status.state == DayState.noData) {
                    dot = Container(
                      decoration: BoxDecoration(
                        color: ext.hairline.withValues(alpha: 0.5),
                        border: Border.all(color: ext.hairline, width: 2.0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  } else {
                    final color = (status.state == DayState.over) ? ext.error : ext.success;
                    dot = Container(
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }
                  
                  if (isToday) {
                    return Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary, width: 2.0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: dot,
                    );
                  }
                  
                  return dot;
                },
              ),
              const SizedBox(height: 16),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(context, 'Safe', ext.success, isOutline: false),
                  const SizedBox(width: 16),
                  _buildLegendItem(context, 'Over', ext.error, isOutline: false),
                  const SizedBox(width: 16),
                  _buildLegendItem(context, 'No logs', ext.hairline, isOutline: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color, {required bool isOutline}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOutline ? Colors.transparent : color,
            border: isOutline ? Border.all(color: color) : null,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.caption),
      ],
    );
  }

  Widget _build7DayList(BuildContext context, Map<DateTime, DayStatus> last35Days) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final sortedDates = last35Days.keys.toList()..sort((a, b) => b.compareTo(a));
    final last7 = sortedDates.take(7).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last 7 days', style: theme.textTheme.h2),
        const SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: last7.asMap().entries.map((entry) {
              final index = entry.key;
              final date = entry.value;
              final status = last35Days[date]!;
              final isLast = index == last7.length - 1;
              
              final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final dayName = days[date.weekday - 1];

              Widget pill;
              if (status.state == DayState.noData) {
                pill = Text('-', style: theme.textTheme.bodyStrong.copyWith(color: theme.textTheme.caption.color));
              } else if (status.state == DayState.over) {
                pill = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ext.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('Over', style: theme.textTheme.caption.copyWith(color: ext.error, fontWeight: FontWeight.w600)),
                );
              } else {
                pill = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ext.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('Safe', style: theme.textTheme.caption.copyWith(color: ext.success, fontWeight: FontWeight.w600)),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(dayName, style: theme.textTheme.body),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                status.state == DayState.noData ? 'No logs' : '≤${status.total.format()}',
                                style: theme.textTheme.caption.copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (status.burnedKcal > 0) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.local_fire_department, size: 14, color: theme.colorScheme.primary),
                              ],
                            ],
                          ),
                        ),
                        pill,
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, color: ext.hairline, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklySummary(BuildContext context, ProgressState state) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This week', style: theme.textTheme.h2),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Eaten', style: theme.textTheme.body),
                  Text(
                    state.weeklyIntake.format(),
                    style: theme.textTheme.bodyStrong.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: ext.hairline),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Burned', style: theme.textTheme.body),
                  Text(
                    '${state.weeklyBurned} kcal',
                    style: theme.textTheme.bodyStrong.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
