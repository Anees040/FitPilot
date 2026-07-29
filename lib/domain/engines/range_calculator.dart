import '../entities/day_status.dart';
import '../entities/food_log.dart';
import '../entities/kcal_range.dart';

/// Computes the daily calorie status from logs, burns, and allowance.
///
/// Pure, deterministic — no side effects.
class RangeCalculator {
  const RangeCalculator();

  /// Calculates the [DayStatus] for a given set of logs, burned kcal,
  /// and allowance.
  ///
  /// Logs with a non-null [FoodLog.deletedAt] are excluded.
  DayStatus dayStatus({
    required List<FoodLog> logs,
    required int burnedKcal,
    required int allowanceKcal,
    required int targetKcal,
  }) {
    final activeLogs = logs.where((l) => l.deletedAt == null);
    final total = KcalRange.sum(activeLogs.map((l) => l.kcal));
    final net = total.minus(burnedKcal);
    final remainingKcal = allowanceKcal - net.midpoint;

    final DayState state;
    if (activeLogs.isEmpty && burnedKcal == 0) {
      state = DayState.noData;
    } else if (net.midpoint > allowanceKcal) {
      state = DayState.over;
    } else if (net.midpoint > allowanceKcal * 0.8) {
      state = DayState.near;
    } else {
      state = DayState.under;
    }

    return DayStatus(
      total: total,
      burnedKcal: burnedKcal,
      net: net,
      remainingKcal: remainingKcal,
      state: state,
      allowanceKcal: allowanceKcal,
      targetKcal: targetKcal,
    );
  }
}
