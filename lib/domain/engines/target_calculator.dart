import '../entities/profile.dart';

class TargetCalculator {
  const TargetCalculator();

  /// Calculates Basal Metabolic Rate using Mifflin-St Jeor equation.
  double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    switch (gender) {
      case Gender.male:
        return base + 5;
      case Gender.female:
        return base - 161;
      case Gender.unspecified:
        return base - 78;
    }
  }

  /// Calculates Total Daily Energy Expenditure.
  double tdee(double bmrValue, ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return bmrValue * 1.2;
      case ActivityLevel.light:
        return bmrValue * 1.375;
      case ActivityLevel.moderate:
        return bmrValue * 1.55;
      case ActivityLevel.active:
        return bmrValue * 1.725;
    }
  }

  /// Calculates the final daily target kilocalories, applying goal multipliers
  /// and gender-based floor clamps.
  int dailyTarget({
    required double tdeeValue,
    required Goal goal,
    required Gender gender,
  }) {
    double target = tdeeValue;
    switch (goal) {
      case Goal.lose:
        target = tdeeValue * 0.8; // -20%
        break;
      case Goal.maintain:
        target = tdeeValue; // 0%
        break;
      case Goal.build:
        target = tdeeValue * 1.1; // +10%
        break;
    }

    // Floor clamping
    int floor = 1200;
    if (gender == Gender.male) floor = 1500;
    
    int roundedTarget = target.round();
    return roundedTarget < floor ? floor : roundedTarget;
  }
}
