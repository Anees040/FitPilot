import 'package:fitpilot/domain/entities/profile.dart';

/// Works out how much protein a day should contain.
///
/// 1.6 g per kg of bodyweight — the muscle-building default, and the low end of
/// the range the evidence supports. Chosen because it is reachable on daal,
/// eggs and dahi. Higher figures sell supplements; they do not help someone
/// eating on a normal budget.
///
/// Rounded to the nearest 5 g, because a target of "112 g" implies a precision
/// that home cooking does not have.
class ProteinTarget {
  const ProteinTarget._();

  /// Grams per kg of bodyweight.
  static const double gramsPerKg = 1.6;

  /// Below 50 g is not worth aiming at; above 200 g is neither necessary nor
  /// affordable for the people this app is for.
  static const int minTarget = 50;
  static const int maxTarget = 200;

  /// Mirrors the range Profile itself enforces, kept as an explicit guard in
  /// case this engine is ever handed a value from elsewhere.
  static const double _minWeightKg = 25;
  static const double _maxWeightKg = 300;

  /// Recommended daily protein in grams, or null when the weight is unusable —
  /// the UI then asks for one instead of inventing a target.
  static int? recommend(Profile profile) {
    return recommendForWeight(profile.weightKg);
  }

  /// Weight-only form, so callers that have a weight but no Profile (the
  /// onboarding flow, tests) do not have to build one.
  static int? recommendForWeight(double? weightKg) {
    if (weightKg == null) return null;
    if (weightKg < _minWeightKg || weightKg > _maxWeightKg) return null;

    final raw = weightKg * gramsPerKg;
    final roundedToFive = (raw / 5).round() * 5;
    return roundedToFive.clamp(minTarget, maxTarget);
  }

  /// The target actually in force: the user's own goal when it is sane,
  /// otherwise the recommendation.
  ///
  /// An out-of-range override is ignored rather than obeyed — a stored 0 or a
  /// mistyped 9999 must not become the number on the Today screen.
  static int? effectiveTarget(Profile profile) {
    final override = profile.proteinGoalG;
    if (override != null && override >= 40 && override <= 250) {
      return override.round();
    }
    return recommend(profile);
  }

  /// Roughly how much to aim for per meal.
  ///
  /// Rounded up so the parts are never short of the whole, and because protein
  /// is used better spread across the day than taken in one sitting.
  static int perMeal(int dailyTarget, {int meals = 4}) {
    if (meals <= 0) return dailyTarget;
    return (dailyTarget / meals).ceil();
  }
}
