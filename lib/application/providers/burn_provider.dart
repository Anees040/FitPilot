import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/domain/engines/burn_planner.dart';
import 'package:fitpilot/domain/engines/range_calculator.dart';
import 'package:fitpilot/domain/engines/streak_engine.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/profile.dart';

enum BurnPlanFrame { surplusToday, surplusYesterday, noSurplus, buildDeficit }

class BurnPlanState {
  final BurnPlanFrame frame;
  final int kcalToBurnOrEat;
  final List<BurnOption> options;
  final DateTime targetDate;

  const BurnPlanState({
    required this.frame,
    required this.kcalToBurnOrEat,
    this.options = const [],
    required this.targetDate,
  });
}

final burnPlanProvider = AsyncNotifierProvider<BurnPlanNotifier, BurnPlanState>(
  BurnPlanNotifier.new,
);

class BurnPlanNotifier extends AsyncNotifier<BurnPlanState> {
  @override
  Future<BurnPlanState> build() async {
    final now = DateTime.now();
    final profile = await ref.watch(profileProvider.future);
    final logRepo = await ref.watch(logRepositoryProvider.future);
    final burnRepo = await ref.watch(burnRepositoryProvider.future);

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Get today and yesterday logs + burns
    final todayLogs = await logRepo.forDay(today);
    final todayBurns = await burnRepo.burnedKcalForDay(today);
    final yesterdayLogs = await logRepo.forDay(yesterday);
    final yesterdayBurns = await burnRepo.burnedKcalForDay(yesterday);

    const calculator = RangeCalculator();
    final todayStatus = calculator.dayStatus(
      logs: todayLogs,
      burnedKcal: todayBurns,
      allowanceKcal: profile.effectiveDailyLimit,
      targetKcal: profile.effectiveDailyTarget,
    );
    final yesterdayStatus = calculator.dayStatus(
      logs: yesterdayLogs,
      burnedKcal: yesterdayBurns,
      allowanceKcal: profile.effectiveDailyLimit,
      targetKcal: profile.effectiveDailyTarget,
    );

    final history = {today: todayStatus, yesterday: yesterdayStatus};

    const streakEngine = StreakEngine();
    final streakState = streakEngine.evaluate(dayHistory: history, now: now);

    // Goal: build & intake below target
    if (profile.goal == Goal.build) {
      final target = profile.effectiveDailyLimit - profile.allowanceKcal;
      final remainingToTarget = target - todayStatus.net.midpoint;
      if (remainingToTarget > 0) {
        return BurnPlanState(
          frame: BurnPlanFrame.buildDeficit,
          kcalToBurnOrEat: remainingToTarget.toInt(),
          options: [],
          targetDate: today,
        );
      }
    }

    // Is there a surplus yesterday (grace window)?
    if (streakState.kcalStillToBurn > 0 &&
        yesterdayStatus.state == DayState.over) {
      // It must be yesterday's surplus inside grace window
      final kcalOver = streakState.kcalStillToBurn;
      final options = const BurnPlanner().planFor(
        kcalOver: kcalOver,
        weightKg: profile.weightKg,
        equipment: profile.equipment,
      );
      return BurnPlanState(
        frame: BurnPlanFrame.surplusYesterday,
        kcalToBurnOrEat: kcalOver,
        options: options,
        targetDate: yesterday,
      );
    }

    // Is there a surplus today?
    if (todayStatus.state == DayState.over) {
      final kcalOver = (todayStatus.net.midpoint - profile.allowanceKcal)
          .clamp(0, double.infinity)
          .toInt();
      if (kcalOver > 0) {
        final options = const BurnPlanner().planFor(
          kcalOver: kcalOver,
          weightKg: profile.weightKg,
          equipment: profile.equipment,
        );
        return BurnPlanState(
          frame: BurnPlanFrame.surplusToday,
          kcalToBurnOrEat: kcalOver,
          options: options,
          targetDate: today,
        );
      }
    }

    // No surplus
    return BurnPlanState(
      frame: BurnPlanFrame.noSurplus,
      kcalToBurnOrEat: 0,
      options: [],
      targetDate: today,
    );
  }

  Future<void> markDone(BurnOption option) async {
    final stateValue = state.value;
    if (stateValue == null) return;

    final burnRepo = await ref.read(burnRepositoryProvider.future);

    await burnRepo.add(option, stateValue.targetDate, DateTime.now());

    // Refresh state
    ref.invalidateSelf();
    // Also invalidate todayProvider so Today UI refreshes
    ref.invalidate(todayProvider);
    ref.read(syncTriggerManagerProvider)?.onLocalWrite();
  }
}
