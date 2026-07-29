import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/features/progress/presentation/weight_trend_section.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text('Progress', style: AppTheme.title),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: stateAsync.when(
          data: (state) => _buildBody(context, state),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
          error: (e, st) => Center(
            child: Text(
              'Error: $e',
              style: AppTheme.body.copyWith(color: AppTheme.error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProgressState state) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildStreakCard(state.streak),
        const SizedBox(height: 24),
        _buildHeatmap(state.last35Days),
        const SizedBox(height: 24),
        _buildWeeklySummary(state),
        const SizedBox(height: 24),
        _build7DayList(state.last35Days),
        const SizedBox(height: 24),
        WeightTrendSection(entries: state.weightEntries),
      ],
    );
  }

  Widget _buildStreakCard(StreakState streak) {
    String explanation;
    Color phaseColor;

    switch (streak.phase) {
      case StreakPhase.neutral:
        explanation = 'No logs today. Streak paused.';
        phaseColor = AppTheme.secondaryText;
        break;
      case StreakPhase.safe:
        explanation = 'You are within your limits today.';
        phaseColor = AppTheme.success;
        break;
      case StreakPhase.overPending:
        explanation =
            'You are over your limit. Burn it by ${streak.graceDeadline?.hour ?? 11}:59 to save the streak!';
        phaseColor = AppTheme.warning;
        break;
      case StreakPhase.cleared:
        explanation = 'You were over, but you burned it! Streak saved.';
        phaseColor = AppTheme.success;
        break;
      case StreakPhase.broken:
        explanation = 'Grace period expired. Streak reset.';
        phaseColor = AppTheme.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${streak.currentStreak} Day Streak', style: AppTheme.title),
              Icon(Icons.local_fire_department, color: phaseColor, size: 28),
            ],
          ),
          const SizedBox(height: 8),
          Text(explanation, style: AppTheme.body.copyWith(color: phaseColor)),
        ],
      ),
    );
  }

  Widget _buildHeatmap(Map<DateTime, DayStatus> last35Days) {
    // A calendar heatmap for 35 days (5 weeks)
    // We'll generate a grid of 5 columns (weeks) x 7 rows (days), or 7 cols x 5 rows.
    // Standard GitHub style is 7 rows (Sun-Sat), but we can just list them sequentially.
    // For simplicity, a Wrap of 35 boxes.

    final sortedDates = last35Days.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last 5 Weeks', style: AppTheme.title),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sortedDates.map((date) {
            final status = last35Days[date]!;
            Color color;
            if (status.state == DayState.over) {
              color = AppTheme.error;
            } else if (status.state == DayState.under ||
                status.state == DayState.near) {
              color = AppTheme.success;
            } else {
              // noData or anything else is neutral grey
              color = AppTheme.hairline;
            }

            return Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWeeklySummary(ProgressState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Summary', style: AppTheme.title),
          const SizedBox(height: 16),
          _summaryRow('Total Intake', state.weeklyIntake.format()),
          const SizedBox(height: 8),
          _summaryRow('Total Burned', '${state.weeklyBurned} kcal'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.body.copyWith(color: AppTheme.secondaryText),
        ),
        Text(value, style: AppTheme.body.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _build7DayList(Map<DateTime, DayStatus> last35Days) {
    final sortedDates = last35Days.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final last7 = sortedDates.take(7).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Days', style: AppTheme.title),
        const SizedBox(height: 12),
        ...last7.map((date) {
          final status = last35Days[date]!;
          return ListTile(
            title: Text('${date.month}/${date.day}', style: AppTheme.body),
            subtitle: Text(
              '${status.total.format()} logged • ${status.burnedKcal} kcal burned',
              style: AppTheme.caption.copyWith(color: AppTheme.secondaryText),
            ),
            trailing: status.state == DayState.noData
                ? null
                : Icon(
                    status.state == DayState.over
                        ? Icons.warning
                        : Icons.check_circle,
                    color: status.state == DayState.over
                        ? AppTheme.error
                        : AppTheme.success,
                  ),
          );
        }),
      ],
    );
  }
}
