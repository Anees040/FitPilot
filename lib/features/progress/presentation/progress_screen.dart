import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/features/progress/presentation/weight_trend_section.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:intl/intl.dart';
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
          skipLoadingOnReload: true,
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

    return SingleChildScrollView(
      key: const PageStorageKey('progress_scroll'),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStreakCard(context, state.streak),
          const SizedBox(height: 24),
          _buildHeatmap(context, state),
          const SizedBox(height: 24),
          _buildHistoryList(context, state.last35Days),
          const SizedBox(height: 24),
          _buildWeeklySummary(context, state),
          const SizedBox(height: 24),
          WeightTrendSection(key: const ValueKey('weight_trend_section'), entries: state.weightEntries),
        ],
      ),
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
                  color: ext.energySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_fire_department, color: ext.energy, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: streak.currentStreak),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '$value-day streak',
                          style: theme.textTheme.display.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
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

  Widget _buildHeatmap(BuildContext context, ProgressState state) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final now = DateTime.now();
    final last35Days = state.last35Days;
    
    // Prepare dates
    final sortedDates = last35Days.keys.toList()..sort();
    
    // Find unique months in the range for the label
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('HEATMAP', style: theme.textTheme.overline.copyWith(fontWeight: FontWeight.bold)),
            Text(monthLabel, style: theme.textTheme.caption.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
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
                itemCount: 42, // 7 headers + 35 days
                itemBuilder: (context, index) {
                  if (index < 7) {
                    // Weekday headers aligned with the first 7 days of the data
                    final first7Days = sortedDates.take(7).toList();
                    final String headerText;
                    if (index < first7Days.length) {
                      const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      headerText = labels[first7Days[index].weekday - 1];
                    } else {
                      headerText = '';
                    }
                    return Center(
                      child: Text(
                        headerText,
                        style: theme.textTheme.overline.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  
                  final dateIndex = index - 7;
                  if (dateIndex >= sortedDates.length) return const SizedBox();
                  
                  final date = sortedDates[dateIndex];
                  final status = last35Days[date] ?? DayStatus(total: KcalRange(0, 0), burnedKcal: 0, net: KcalRange(0, 0), toBurn: 0, wiggleRoomKcal: 0, state: DayState.noData);
                  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                  
                  Widget dot;
                  if (status.state == DayState.noData) {
                    bool isActiveCleanDay = false;
                    if (state.firstActiveDate != null && !date.isBefore(state.firstActiveDate!)) {
                      isActiveCleanDay = true; // Clean day since starting the app
                    }

                    if (isActiveCleanDay) {
                      dot = Container(
                        decoration: BoxDecoration(
                          color: ext.success,
                          border: Border.all(color: ext.success.withValues(alpha: 0.5), width: 1.0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(date.day.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      );
                    } else {
                      dot = Container(
                        decoration: BoxDecoration(
                          color: ext.hairline.withValues(alpha: 0.5),
                          border: Border.all(color: ext.hairline, width: 2.0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(date.day.toString(), style: theme.textTheme.caption.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }
                  } else {
                    Color color;
                    switch (status.state) {
                      case DayState.cleared:
                        color = ext.success;
                        break;
                      case DayState.inProgress:
                        color = theme.colorScheme.primary;
                        break;
                      case DayState.unburned:
                        color = ext.error;
                        break;
                      case DayState.noData: // Handled above
                        color = ext.hairline;
                        break;
                    }
                    dot = Container(
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(date.day.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    );
                  }
                  
                  if (isToday) {
                    dot = Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary, width: 2.0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: dot,
                    );
                  }
                  
                  return GestureDetector(
                    onTap: () {
                      AppBottomSheet.show(
                        context,
                        child: _DayDetailSheet(date: date, status: status),
                      );
                    },
                    child: dot,
                  );
                },
              ),
              const SizedBox(height: 16),
              // Legend
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildLegendItem(context, 'Safe/Clean', ext.success, isOutline: false),
                  _buildLegendItem(context, 'Burning', theme.colorScheme.primary, isOutline: false),
                  _buildLegendItem(context, 'Unburned', ext.error, isOutline: false),
                  _buildLegendItem(context, 'Pre-App', ext.hairline, isOutline: true),
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

  Widget _buildHistoryList(BuildContext context, Map<DateTime, DayStatus> last35Days) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final sortedDates = last35Days.keys.toList()..sort((a, b) => b.compareTo(a));
    
    final last7 = sortedDates.take(7).toList();

    Widget buildTileList(String title, List<DateTime> dates) {
      if (dates.isEmpty) return const SizedBox();
      return _CollapsibleHistoryCard(
        title: title,
        children: [
          ...dates.asMap().entries.map((entry) {
            final index = entry.key;
            final date = entry.value;
            final status = last35Days[date] ?? DayStatus(total: KcalRange(0, 0), burnedKcal: 0, net: KcalRange(0, 0), toBurn: 0, wiggleRoomKcal: 0, state: DayState.noData);
            final isLast = index == dates.length - 1;
            
            final dayName = DateFormat('EEE, MMM d').format(date);

            Widget pill;
            if (status.state == DayState.noData) {
              pill = Text('-', style: theme.textTheme.bodyStrong.copyWith(color: theme.textTheme.caption.color));
            } else if (status.state == DayState.unburned) {
              pill = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ext.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Unburned', style: theme.textTheme.caption.copyWith(color: ext.error, fontWeight: FontWeight.w600)),
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
              key: ValueKey('day_history_${date.toIso8601String()}'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
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
          }),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildTileList('Last 7 Days', last7),
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

class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final DayStatus status;

  const _DayDetailSheet({required this.date, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    String title = DateFormat('EEEE, MMMM d').format(date);
    String statusText;
    Color statusColor;

    switch (status.state) {
      case DayState.cleared:
        statusText = 'Cleared';
        statusColor = ext.success;
        break;
      case DayState.inProgress:
        statusText = 'In Progress';
        statusColor = ext.warning;
        break;
      case DayState.unburned:
        statusText = 'Unburned';
        statusColor = ext.error;
        break;
      case DayState.noData:
        statusText = 'No Data';
        statusColor = ext.hairline;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: theme.textTheme.bodyStrong,
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CollapsibleHistoryCard extends StatefulWidget {
  final String title;
  final List<Widget> children;

  const _CollapsibleHistoryCard({
    required this.title,
    required this.children,
  });

  @override
  State<_CollapsibleHistoryCard> createState() => _CollapsibleHistoryCardState();
}

class _CollapsibleHistoryCardState extends State<_CollapsibleHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.title, style: theme.textTheme.h2.copyWith(fontSize: 18)),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: ext.hairline),
            ...widget.children,
          ],
        ],
      ),
    );
  }
}
