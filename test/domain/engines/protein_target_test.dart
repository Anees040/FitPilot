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
    test('uses 1.6 g/kg for maintenance', () {
      expect(ProteinTarget.recommend(_profile(weightKg: 70)), 112);
    });

    test('is higher in a deficit, where muscle is at risk', () {
      final cut = ProteinTarget.recommend(_profile(weightKg: 70, goal: Goal.lose))!;
      final maintain = ProteinTarget.recommend(_profile(weightKg: 70))!;
      expect(cut, greaterThan(maintain));
      expect(cut, 126); // 1.8 g/kg
    });

    test('is moderate when gaining', () {
      expect(ProteinTarget.recommend(_profile(weightKg: 70, goal: Goal.build)), 119);
    });

    test('a default-shaped profile still yields a sane target', () {
      // weightKg is non-nullable and defaults to 70 kg for a fresh profile.
      expect(ProteinTarget.recommend(_profile()), 112);
    });

    test('the lightest allowed bodyweight still gets the floor', () {
      // Profile itself rejects anything under 25 kg, so this is the low bound.
      expect(ProteinTarget.recommend(_profile(weightKg: 25)), 40);
    });

    test('the heaviest allowed bodyweight is capped at a sane ceiling', () {
      expect(ProteinTarget.recommend(_profile(weightKg: 300)), 250);
    });

    test('a mid-range heavy bodyweight is not capped prematurely', () {
      expect(ProteinTarget.recommend(_profile(weightKg: 120)), 192);
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
      expect(ProteinTarget.effectiveTarget(_profile(weightKg: 70)), 112);
    });

    test('an override applies regardless of weight', () {
      expect(ProteinTarget.effectiveTarget(_profile(proteinGoalG: 120)), 120);
    });

    test('a nonsense override is ignored, not obeyed', () {
      // Falls back to the recommendation rather than showing a 0 g target.
      expect(
        ProteinTarget.effectiveTarget(_profile(weightKg: 70, proteinGoalG: 0)),
        112,
      );
      expect(
        ProteinTarget.effectiveTarget(_profile(weightKg: 70, proteinGoalG: 9999)),
        112,
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
