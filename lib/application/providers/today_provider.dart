import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/engines/range_calculator.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/food_log.dart';

class TodayState {
  final List<FoodLog> logs;
  final DayStatus dayStatus;

  const TodayState({required this.logs, required this.dayStatus});
}

/// Provides the current day's logs and computed status.
final todayProvider = AsyncNotifierProvider<TodayNotifier, TodayState>(
  TodayNotifier.new,
);

class TodayNotifier extends AsyncNotifier<TodayState> {
  @override
  Future<TodayState> build() async {
    final now = DateTime.now();
    final logRepo = await ref.watch(logRepositoryProvider.future);
    final burnRepo = await ref.watch(burnRepositoryProvider.future);

    // Watch profile to automatically update when allowance changes
    final profile = await ref.watch(profileProvider.future);

    final logs = await logRepo.forDay(now);
    final burnedKcal = await burnRepo.burnedKcalForDay(now);

    const calculator = RangeCalculator();
    final dayStatus = calculator.dayStatus(
      logs: logs,
      burnedKcal: burnedKcal,
      allowanceKcal: profile.allowanceKcal,
    );

    return TodayState(logs: logs, dayStatus: dayStatus);
  }

  /// Adds a new log and refreshes the state.
  Future<void> addLog(FoodLog log) async {
    final logRepo = await ref.read(logRepositoryProvider.future);
    await logRepo.add(log);
    ref.invalidateSelf();
  }

  /// Updates the quantity of an existing log and refreshes.
  Future<void> updateLogQuantity(String logId, num newQuantity) async {
    final logRepo = await ref.read(logRepositoryProvider.future);

    // We need the existing log to update it
    final currentState = state.value;
    if (currentState == null) return;

    final existing = currentState.logs.firstWhere((l) => l.id == logId);
    final updated = existing.copyWith(quantity: newQuantity);

    await logRepo.update(updated);
    ref.invalidateSelf();
  }

  /// Soft deletes a log and refreshes.
  Future<void> deleteLog(String logId) async {
    final logRepo = await ref.read(logRepositoryProvider.future);
    await logRepo.softDelete(logId, DateTime.now());
    ref.invalidateSelf();
  }
}
