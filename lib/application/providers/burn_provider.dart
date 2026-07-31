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

final burnCategoryFilterProvider = StateProvider<String?>((ref) => null);
final burnPaceFilterProvider = StateProvider<String?>((ref) => null);

final burnPlanProvider = AsyncNotifierProvider<BurnPlanNotifier, BurnPlanState>(
  BurnPlanNotifier.new,
);

class BurnPlanNotifier extends AsyncNotifier<BurnPlanState> {
  @override
  Future<BurnPlanState> build() async {
    final now = DateTime.now();
    final categoryFilter = ref.watch(burnCategoryFilterProvider);
    final paceFilter = ref.watch(burnPaceFilterProvider);
    final profile = await ref.watch(profileProvider.future);
    final logRepo = await ref.watch(logRepositoryProvider.future);
    final burnRepo = await ref.watch(burnRepositoryProvider.future);
    final exerciseRepo = await ref.watch(exerciseRepositoryProvider.future);

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Watch todayProvider so we update reactively when logs/burns change today
    final todayState = await ref.watch(todayProvider.future);
    final todayStatus = todayState.dayStatus;

    // Get yesterday logs + burns
    final yesterdayLogs = await logRepo.forDay(yesterday);
    final yesterdayBurns = await burnRepo.burnedKcalForDay(yesterday);

    const calculator = RangeCalculator();
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

    final allExercises = await exerciseRepo.all();
    final profileEq = profile.equipment;
    // Filter candidates by equipment
    final candidates = allExercises.where((e) {
      if (e.equipment == null) return true; // Needs no equipment
      if (e.equipment == 'none') return true;
      return profileEq.contains(e.equipment);
    }).toList();

    final activeCategoryPref = categoryFilter ?? profile.planCategoryPref;
    final activePacePref = paceFilter ?? profile.planPacePref;

    // Is there a surplus yesterday (grace window)?
    if (streakState.kcalStillToBurn > 0 &&
        yesterdayStatus.state == DayState.over) {
      // It must be yesterday's surplus inside grace window
      final kcalOver = streakState.kcalStillToBurn;
      final options = const BurnPlanner().planFor(
        kcalOver: kcalOver,
        weightKg: profile.weightKg,
        candidates: candidates,
        categoryPref: activeCategoryPref,
        pacePref: activePacePref,
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
      final kcalOver = (todayStatus.net.midpoint - profile.effectiveDailyLimit)
          .clamp(0, double.infinity)
          .toInt();
      if (kcalOver > 0) {
        final options = const BurnPlanner().planFor(
          kcalOver: kcalOver,
          weightKg: profile.weightKg,
          candidates: candidates,
          categoryPref: activeCategoryPref,
          pacePref: activePacePref,
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
