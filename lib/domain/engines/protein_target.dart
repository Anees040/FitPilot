import 'package:fitpilot/domain/entities/profile.dart';

/// Works out how much protein a day should contain.
///
/// Deliberately goal-aware. A deficit is when muscle is most at risk, so the
/// target goes up while calories go down — the opposite of what most people
/// assume. The figures are the low end of what the evidence supports, chosen
/// because they are reachable on daal, eggs and dahi rather than on powder.
class ProteinTarget {
  const ProteinTarget._();

  /// Grams per kg of bodyweight, by goal.
  static const double _losing = 1.8;
  static const double _gaining = 1.7;
  static const double _maintaining = 1.6;

  /// Below this a target is not worth aiming at; above it is neither necessary
  /// nor affordable for the people this app is for.
  static const int minTarget = 40;
  static const int maxTarget = 250;

  /// Mirrors the range Profile itself enforces. Kept as an explicit guard so
  /// this engine stays safe if it is ever handed a value from elsewhere.
  static const double _minWeightKg = 25;
  static const double _maxWeightKg = 300;

  /// Recommended daily protein in grams, or null when the weight is not
  /// usable — the UI then asks for one instead of inventing a target.
  static int? recommend(Profile profile) {
    final weight = profile.weightKg;
    if (weight < _minWeightKg || weight > _maxWeightKg) return null;

    final perKg = switch (profile.goal) {
      Goal.lose => _losing,
      Goal.build => _gaining,
      Goal.maintain => _maintaining,
    };

    return (weight * perKg).round().clamp(minTarget, maxTarget);
  }

  /// The target actually in force: the user's own goal when it is sane,
  /// otherwise the recommendation.
  ///
  /// An out-of-range override is ignored rather than obeyed — a stored 0 or a
  /// mistyped 9999 should not become the number on the Today screen.
  static int? effectiveTarget(Profile profile) {
    final override = profile.proteinGoalG;
    if (override != null && override >= minTarget && override <= maxTarget) {
      return override.round();
    }
    return recommend(profile);
  }

  /// Roughly how much to aim for per meal.
  ///
  /// Rounded up so the parts are never short of the whole, and because protein
  /// is absorbed better spread across the day than taken in one sitting.
  static int perMeal(int dailyTarget, {int meals = 4}) {
    if (meals <= 0) return dailyTarget;
    return (dailyTarget / meals).ceil();
  }
}
