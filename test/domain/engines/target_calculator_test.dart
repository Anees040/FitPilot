import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/target_calculator.dart';
import 'package:fitpilot/domain/entities/profile.dart';

void main() {
  const calc = TargetCalculator();

  group('TargetCalculator', () {
    test('bmr: female, 25 years, 60kg, 165cm', () {
      // 10 * 60 + 6.25 * 165 - 5 * 25 - 161
      // 600 + 1031.25 - 125 - 161 = 1345.25
      final result = calc.bmr(weightKg: 60, heightCm: 165, age: 25, gender: Gender.female);
      expect(result, 1345.25);
    });

    test('bmr: male, 30 years, 80kg, 180cm', () {
      // 10 * 80 + 6.25 * 180 - 5 * 30 + 5
      // 800 + 1125 - 150 + 5 = 1780.0
      final result = calc.bmr(weightKg: 80, heightCm: 180, age: 30, gender: Gender.male);
      expect(result, 1780.0);
    });

    test('bmr: unspecified gender, 40 years, 70kg, 170cm', () {
      // 10 * 70 + 6.25 * 170 - 5 * 40 - 78
      // 700 + 1062.5 - 200 - 78 = 1484.5
      final result = calc.bmr(weightKg: 70, heightCm: 170, age: 40, gender: Gender.unspecified);
      expect(result, 1484.5);
    });

    test('tdee applies all four activity factors correctly', () {
      expect(calc.tdee(1000, ActivityLevel.sedentary), 1200.0);
      expect(calc.tdee(1000, ActivityLevel.light), 1375.0);
      expect(calc.tdee(1000, ActivityLevel.moderate), 1550.0);
      expect(calc.tdee(1000, ActivityLevel.active), 1725.0);
    });

    test('dailyTarget applies goal adjustments correctly', () {
      // Base TDEE = 2000
      // lose: 1600
      // maintain: 2000
      // build: 2200
      expect(calc.dailyTarget(tdeeValue: 2000, goal: Goal.lose, gender: Gender.female), 1600);
      expect(calc.dailyTarget(tdeeValue: 2000, goal: Goal.maintain, gender: Gender.female), 2000);
      expect(calc.dailyTarget(tdeeValue: 2000, goal: Goal.build, gender: Gender.female), 2200);
    });

    test('dailyTarget applies female and unspecified floor clamp (1200)', () {
      // TDEE = 1000, lose = 800
      expect(calc.dailyTarget(tdeeValue: 1000, goal: Goal.lose, gender: Gender.female), 1200);
      expect(calc.dailyTarget(tdeeValue: 1000, goal: Goal.lose, gender: Gender.unspecified), 1200);
    });

    test('dailyTarget applies male floor clamp (1500)', () {
      // TDEE = 1500, lose = 1200
      expect(calc.dailyTarget(tdeeValue: 1500, goal: Goal.lose, gender: Gender.male), 1500);
    });

    test('dailyTarget rounds correctly', () {
      expect(calc.dailyTarget(tdeeValue: 2000.6, goal: Goal.maintain, gender: Gender.female), 2001);
      expect(calc.dailyTarget(tdeeValue: 2000.4, goal: Goal.maintain, gender: Gender.female), 2000);
    });
  });
}
