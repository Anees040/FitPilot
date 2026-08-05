import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

void main() {
  group('FoodItem validation', () {
    test('empty id throws', () {
      expect(
        () => FoodItem(
          id: '',
          name: 'Test',
          portionLabel: '1 pc',
          kcalPerPortion: KcalRange(100, 200),
        ),
        throwsArgumentError,
      );
    });

    test('empty name throws', () {
      expect(
        () => FoodItem(
          id: 'test-1',
          name: '',
          portionLabel: '1 pc',
          kcalPerPortion: KcalRange(100, 200),
        ),
        throwsArgumentError,
      );
    });

    test('empty portionLabel throws', () {
      expect(
        () => FoodItem(
          id: 'test-1',
          name: 'Test',
          portionLabel: '',
          kcalPerPortion: KcalRange(100, 200),
        ),
        throwsArgumentError,
      );
    });

    test('grams <= 0 throws', () {
      expect(
        () => FoodItem(
          id: 'test-1',
          name: 'Test',
          portionLabel: '1 pc',
          grams: 0,
          kcalPerPortion: KcalRange(100, 200),
        ),
        throwsArgumentError,
      );
    });

    test('grams null is valid', () {
      expect(
        () => FoodItem(
          id: 'test-1',
          name: 'Test',
          portionLabel: '1 pc',
          kcalPerPortion: KcalRange(100, 200),
        ),
        returnsNormally,
      );
    });
  });

  group('FoodLog validation', () {
    final now = DateTime(2026, 7, 27);

    test('both foodId and customName null throws', () {
      expect(
        () => FoodLog(
          id: 'log-1',
          quantity: 1,
          kcal: KcalRange(100, 200),
          source: LogSource.manual,
          loggedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('quantity 0 throws', () {
      expect(
        () => FoodLog(
          id: 'log-1',
          customName: 'Test',
          quantity: 0,
          kcal: KcalRange(100, 200),
          source: LogSource.manual,
          loggedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('quantity 0.5 passes', () {
      final log = FoodLog(
        id: 'log-1',
        customName: 'Test',
        quantity: 0.5,
        kcal: KcalRange(100, 200),
        source: LogSource.manual,
        loggedAt: now,
      );
      expect(log.quantity, 0.5);
    });

    test('quantity 20.1 throws', () {
      expect(
        () => FoodLog(
          id: 'log-1',
          customName: 'Test',
          quantity: 20.1,
          kcal: KcalRange(100, 200),
          source: LogSource.manual,
          loggedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('quantity 1 passes', () {
      expect(
        () => FoodLog(
          id: 'log-1',
          customName: 'Test',
          quantity: 1,
          kcal: KcalRange(100, 200),
          source: LogSource.manual,
          loggedAt: now,
        ),
        returnsNormally,
      );
    });

    test('quantity 20 passes', () {
      expect(
        () => FoodLog(
          id: 'log-1',
          customName: 'Test',
          quantity: 20,
          kcal: KcalRange(100, 200),
          source: LogSource.manual,
          loggedAt: now,
        ),
        returnsNormally,
      );
    });

    test('foodId alone is valid', () {
      expect(
        () => FoodLog(
          id: 'log-1',
          foodId: 'food-1',
          quantity: 1,
          kcal: KcalRange(100, 200),
          source: LogSource.search,
          loggedAt: now,
        ),
        returnsNormally,
      );
    });

    test('displayName returns customName when present', () {
      final log = FoodLog(
        id: 'log-1',
        customName: 'My Custom Food',
        quantity: 1,
        kcal: KcalRange(100, 200),
        source: LogSource.manual,
        loggedAt: now,
      );
      expect(log.displayName, 'My Custom Food');
    });

    test('displayName returns null when customName absent', () {
      final log = FoodLog(
        id: 'log-1',
        foodId: 'food-1',
        quantity: 1,
        kcal: KcalRange(100, 200),
        source: LogSource.search,
        loggedAt: now,
      );
      expect(log.displayName, isNull);
    });
  });

  group('Profile validation', () {
    final now = DateTime(2026, 7, 27);

    test('weightKg 24.9 throws', () {
      expect(
        () => Profile(weightKg: 24.9, heightCm: 170, age: 25, updatedAt: now),
        throwsArgumentError,
      );
    });

    test('weightKg 25.0 passes', () {
      expect(
        () => Profile(weightKg: 25.0, heightCm: 170, age: 25, updatedAt: now),
        returnsNormally,
      );
    });

    test('weightKg 300 passes', () {
      expect(
        () => Profile(weightKg: 300, heightCm: 170, age: 25, updatedAt: now),
        returnsNormally,
      );
    });

    test('weightKg 300.1 throws', () {
      expect(
        () => Profile(weightKg: 300.1, heightCm: 170, age: 25, updatedAt: now),
        throwsArgumentError,
      );
    });

    test('heightCm 99 throws', () {
      expect(
        () => Profile(weightKg: 70, heightCm: 99, age: 25, updatedAt: now),
        throwsArgumentError,
      );
    });

    test('heightCm 100 passes', () {
      expect(
        () => Profile(weightKg: 70, heightCm: 100, age: 25, updatedAt: now),
        returnsNormally,
      );
    });

    test('heightCm 250 passes', () {
      expect(
        () => Profile(weightKg: 70, heightCm: 250, age: 25, updatedAt: now),
        returnsNormally,
      );
    });

    test('age 12 throws', () {
      expect(
        () => Profile(weightKg: 70, heightCm: 170, age: 12, updatedAt: now),
        throwsArgumentError,
      );
    });

    test('age 13 passes', () {
      expect(
        () => Profile(weightKg: 70, heightCm: 170, age: 13, updatedAt: now),
        returnsNormally,
      );
    });

    test('age 100 passes', () {
      expect(
        () => Profile(weightKg: 70, heightCm: 170, age: 100, updatedAt: now),
        returnsNormally,
      );
    });

    test('allowanceKcal -1 throws', () {
      expect(
        () => Profile(
          weightKg: 70,
          heightCm: 170,
          age: 25,
          allowanceKcal: -1,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('allowanceKcal 0 passes', () {
      expect(
        () => Profile(
          weightKg: 70,
          heightCm: 170,
          age: 25,
          allowanceKcal: 0,
          updatedAt: now,
        ),
        returnsNormally,
      );
    });

    test('allowanceKcal 2000 passes', () {
      expect(
        () => Profile(
          weightKg: 70,
          heightCm: 170,
          age: 25,
          allowanceKcal: 2000,
          updatedAt: now,
        ),
        returnsNormally,
      );
    });

    test('allowanceKcal 2001 throws', () {
      expect(
        () => Profile(
          weightKg: 70,
          heightCm: 170,
          age: 25,
          allowanceKcal: 2001,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('defaultAllowanceKcal is 300', () {
      expect(Profile.defaultAllowanceKcal, 300);
    });

    test('copyWith preserves unchanged fields', () {
      final p = Profile(
        weightKg: 70,
        heightCm: 170,
        age: 25,
        gender: Gender.male,
        goal: Goal.lose,
        equipment: const ['gym', 'rope'],
        updatedAt: DateTime.now(),
      );
      final copy = p.copyWith();
      expect(copy.gender, Gender.male);
      final p2 = p.copyWith(weightKg: 75);
      expect(p2.weightKg, 75);
      expect(p2.heightCm, 170);
      expect(p2.age, 25);
      expect(p2.gender, Gender.male);
      expect(p2.goal, Goal.lose);
      expect(p2.equipment, ['gym', 'rope']);
    });
  });

  group('Exercise validation', () {
    test('difficulty 0 throws', () {
      expect(
        () => Exercise(
          id: 'ex-1',
          name: 'Test',
          category: ExerciseCategory.gym,
          difficulty: 0,
          met: 5.0,
        ),
        throwsArgumentError,
      );
    });

    test('difficulty 4 throws', () {
      expect(
        () => Exercise(
          id: 'ex-1',
          name: 'Test',
          category: ExerciseCategory.gym,
          difficulty: 4,
          met: 5.0,
        ),
        throwsArgumentError,
      );
    });

    test('difficulty 1–3 passes', () {
      for (final d in [1, 2, 3]) {
        expect(
          () => Exercise(
            id: 'ex-1',
            name: 'Test',
            category: ExerciseCategory.gym,
            difficulty: d,
            met: 5.0,
          ),
          returnsNormally,
        );
      }
    });

    test('met <= 0 throws', () {
      expect(
        () => Exercise(
          id: 'ex-1',
          name: 'Test',
          category: ExerciseCategory.gym,
          difficulty: 1,
          met: 0,
        ),
        throwsArgumentError,
      );
    });

    test('empty id throws', () {
      expect(
        () => Exercise(
          id: '',
          name: 'Test',
          category: ExerciseCategory.gym,
          difficulty: 1,
          met: 5.0,
        ),
        throwsArgumentError,
      );
    });

    test('empty name throws', () {
      expect(
        () => Exercise(
          id: 'ex-1',
          name: '',
          category: ExerciseCategory.gym,
          difficulty: 1,
          met: 5.0,
        ),
        throwsArgumentError,
      );
    });
  });
}
