import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/engines/protein_target.dart';
import 'package:fitpilot/domain/entities/profile.dart';

Profile _profile({
  double weightKg = 70,
  Goal goal = Goal.maintain,
  double? proteinGoalG,
}) => Profile(
  weightKg: weightKg,
  heightCm: 175,
  age: 25,
  gender: Gender.male,
  goal: goal,
  proteinGoalG: proteinGoalG,
  updatedAt: DateTime(2026, 8, 8),
);

void main() {
  group('recommend', () {
    test('70 kg gives 110 g — 1.6 g/kg rounded to the nearest 5', () {
      expect(ProteinTarget.recommend(_profile(weightKg: 70)), 110);
    });

    test('the same target regardless of goal', () {
      // Deliberately goal-independent: 1.6 g/kg is already the muscle-building
      // figure, so it covers cutting and building alike.
      expect(ProteinTarget.recommend(_profile(weightKg: 70, goal: Goal.lose)), 110);
      expect(ProteinTarget.recommend(_profile(weightKg: 70, goal: Goal.build)), 110);
    });

    test('rounds to the nearest 5, not the nearest gram', () {
      // 80 x 1.6 = 128 -> 130
      expect(ProteinTarget.recommend(_profile(weightKg: 80)), 130);
    });

    test('a null weight yields no target rather than a guess', () {
      expect(ProteinTarget.recommendForWeight(null), isNull);
    });

    test('a light bodyweight is floored at 50 g', () {
      expect(ProteinTarget.recommend(_profile(weightKg: 25)), 50);
    });

    test('a heavy bodyweight is capped at 200 g', () {
      expect(ProteinTarget.recommend(_profile(weightKg: 300)), 200);
    });

    test('a mid-range bodyweight is not capped prematurely', () {
      // 120 x 1.6 = 192 -> 190
      expect(ProteinTarget.recommend(_profile(weightKg: 120)), 190);
    });
  });

  group('effectiveTarget', () {
    test("the user's own goal wins over the recommendation", () {
      expect(
        ProteinTarget.effectiveTarget(_profile(weightKg: 70, proteinGoalG: 150)),
        150,
      );
    });

    test('falls back to the recommendation when no goal is set', () {
      expect(ProteinTarget.effectiveTarget(_profile(weightKg: 70)), 110);
    });

    test('an override applies regardless of weight', () {
      expect(ProteinTarget.effectiveTarget(_profile(proteinGoalG: 120)), 120);
    });

    test('a nonsense override is ignored, not obeyed', () {
      // Falls back to the recommendation rather than showing a 0 g target.
      expect(
        ProteinTarget.effectiveTarget(_profile(weightKg: 70, proteinGoalG: 0)),
        110,
      );
      expect(
        ProteinTarget.effectiveTarget(_profile(weightKg: 70, proteinGoalG: 9999)),
        110,
      );
    });
  });

  group('perMeal', () {
    test('splits the day into even portions', () {
      expect(ProteinTarget.perMeal(120, meals: 4), 30);
    });

    test('rounds up so the parts are never short of the whole', () {
      expect(ProteinTarget.perMeal(100, meals: 3), 34);
    });

    test('guards against a zero or negative meal count', () {
      expect(ProteinTarget.perMeal(120, meals: 0), 120);
      expect(ProteinTarget.perMeal(120, meals: -2), 120);
    });
  });
}
