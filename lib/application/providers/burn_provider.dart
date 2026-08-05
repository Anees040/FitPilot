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


enum BurnPlanFrame { burnToday, yesterdayDebt, allClear, cleanDay }

class BurnPlanState {
  final BurnPlanFrame frame;
  final int kcalToBurnOrEat;
  final List<BurnOption> options;
  final DateTime targetDate;
  final String? selectedMealId;

  const BurnPlanState({
    required this.frame,
    required this.kcalToBurnOrEat,
    this.options = const [],
    required this.targetDate,
    this.selectedMealId,
  });
}

final burnCategoryFilterProvider = StateProvider<String?>((ref) => null);
final burnPaceFilterProvider = StateProvider<String?>((ref) => null);
final burnPlanMealIdProvider = StateProvider<String?>((ref) => null);

final burnPlanProvider = AsyncNotifierProvider<BurnPlanNotifier, BurnPlanState>(
  BurnPlanNotifier.new,
);

class BurnPlanNotifier extends AsyncNotifier<BurnPlanState> {
  @override
  Future<BurnPlanState> build() async {
    final now = DateTime.now();
    final categoryFilter = ref.watch(burnCategoryFilterProvider);
    final paceFilter = ref.watch(burnPaceFilterProvider);
    final selectedMealId = ref.watch(burnPlanMealIdProvider);
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
      wiggleRoomKcal: profile.allowanceKcal,
    );

    final history = {today: todayStatus, yesterday: yesterdayStatus};

    const streakEngine = StreakEngine();
    final streakState = streakEngine.evaluate(dayHistory: history, now: now);

    final allExercises = await exerciseRepo.all();
    final profileEq = profile.equipment;
    // Filter candidates by equipment (always include equipment-free/bodyweight exercises)
    var candidates = allExercises.where((e) {
      if (e.equipment == null || e.equipment!.trim().isEmpty) return true;
      final eqLower = e.equipment!.toLowerCase().trim();
      if (eqLower == 'none' ||
          eqLower == 'bodyweight' ||
          eqLower == 'body weight' ||
          eqLower == 'no equipment' ||
          eqLower.contains('none') ||
          eqLower.contains('bodyweight') ||
          eqLower.contains('body weight') ||
          eqLower.contains('no equipment')) {
        return true;
      }
      if (profileEq.isEmpty) return true;
      return profileEq.any((userEq) {
        final u = userEq.toLowerCase().trim();
        return u.isNotEmpty && eqLower.contains(u);
      });
    }).toList();

    if (candidates.isEmpty) {
      candidates = allExercises;
    }

    final activeCategoryPref = categoryFilter ?? profile.planCategoryPref;
    final activePacePref = paceFilter ?? profile.planPacePref;

    // Is there a surplus yesterday (grace window)?
    if (streakState.kcalStillToBurn > 0 &&
        (yesterdayStatus.state == DayState.inProgress ||
         yesterdayStatus.state == DayState.unburned)) {
      final kcalOver = streakState.kcalStillToBurn;
      final options = const BurnPlanner().planFor(
        kcalOver: kcalOver,
        weightKg: profile.weightKg,
        candidates: candidates,
        categoryPref: activeCategoryPref,
        pacePref: activePacePref,
      );
      return BurnPlanState(
        frame: BurnPlanFrame.yesterdayDebt,
        kcalToBurnOrEat: kcalOver,
        options: options,
        targetDate: yesterday,
      );
    }

    // Is there a surplus today or selected meal or logged meals?
    if (todayState.logs.isNotEmpty || todayStatus.toBurn > 0 || selectedMealId != null) {
      int calcTarget = todayStatus.toBurn;

      if (selectedMealId != null) {
        final meal = todayState.logs.where((l) => l.id == selectedMealId).firstOrNull;
        if (meal != null) {
          calcTarget = meal.kcal.midpoint;
        }
      }

      if (calcTarget <= 0) {
        calcTarget = todayStatus.net.midpoint > 0 
            ? todayStatus.net.midpoint 
            : (todayState.logs.firstOrNull?.kcal.midpoint ?? 300);
      }

      final options = const BurnPlanner().planFor(
        kcalOver: calcTarget,
        weightKg: profile.weightKg,
        candidates: candidates,
        categoryPref: activeCategoryPref,
        pacePref: activePacePref,
      );

      return BurnPlanState(
        frame: BurnPlanFrame.burnToday,
        kcalToBurnOrEat: calcTarget,
        options: options,
        targetDate: today,
        selectedMealId: selectedMealId,
      );
    }

    return BurnPlanState(
      frame: BurnPlanFrame.cleanDay,
      kcalToBurnOrEat: 0,
      options: const [],
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
