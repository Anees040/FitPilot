import '../entities/day_status.dart';
import '../entities/food_log.dart';
import '../entities/kcal_range.dart';

/// Computes the daily calorie status from logs, burns, and allowance.
///
/// Pure, deterministic — no side effects.
class RangeCalculator {
  const RangeCalculator();

  /// Calculates the [DayStatus] for a given set of logs, burned kcal,
  /// and wiggle room.
  ///
  /// Logs with a non-null [FoodLog.deletedAt] are excluded.
  DayStatus dayStatus({
    required List<FoodLog> logs,
    required int burnedKcal,
    required int wiggleRoomKcal,
  }) {
    final activeLogs = logs.where((l) => l.deletedAt == null);
    final total = KcalRange.sum(activeLogs.map((l) => l.kcal));
    final net = total.minus(burnedKcal);
    
    // toBurn = max(0, net.midpoint - wiggleRoomKcal)
    final toBurn = (net.midpoint - wiggleRoomKcal).clamp(0, double.infinity).toInt();

    final DayState state;
    if (activeLogs.isEmpty) {
      state = DayState.noData;
    } else if (toBurn == 0) {
      state = DayState.cleared;
    } else if (burnedKcal > 0) {
      state = DayState.inProgress;
    } else {
      state = DayState.unburned;
    }

    return DayStatus(
      total: total,
      burnedKcal: burnedKcal,
      net: net,
      toBurn: toBurn,
      state: state,
      wiggleRoomKcal: wiggleRoomKcal,
    );
  }
}
