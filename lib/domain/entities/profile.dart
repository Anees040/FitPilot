import 'package:equatable/equatable.dart';
import '../engines/target_calculator.dart';

/// User's fitness goal.
enum Goal { lose, maintain, build }

/// User's gender for BMR calculation.
enum Gender { male, female, unspecified }

/// User's activity level for TDEE calculation.
enum ActivityLevel { sedentary, light, moderate, active }

/// User profile — single-row entity.
class Profile extends Equatable {
  final double weightKg;
  final double? goalWeightKg;
  final int heightCm;
  final int age;
  final Gender gender;
  final Goal goal;
  final ActivityLevel activityLevel;
  final int allowanceKcal;
  final int? targetKcalOverride;
  final List<String> equipment;
  final DateTime updatedAt;

  static const int defaultAllowanceKcal = 300;

  Profile({
    required this.weightKg,
    this.goalWeightKg,
    required this.heightCm,
    required this.age,
    this.gender = Gender.unspecified,
    this.goal = Goal.maintain,
    this.activityLevel = ActivityLevel.light,
    this.allowanceKcal = defaultAllowanceKcal,
    this.targetKcalOverride,
    this.equipment = const [],
    required this.updatedAt,
  }) {
    if (weightKg < 25 || weightKg > 300) {
      throw ArgumentError('weightKg must be 25–300, got $weightKg');
    }
    if (goalWeightKg != null && (goalWeightKg! < 25 || goalWeightKg! > 300)) {
      throw ArgumentError('goalWeightKg must be 25–300, got $goalWeightKg');
    }
    if (heightCm < 100 || heightCm > 250) {
      throw ArgumentError('heightCm must be 100–250, got $heightCm');
    }
    if (age < 13 || age > 100) {
      throw ArgumentError('age must be 13–100, got $age');
    }
    if (allowanceKcal < 0 || allowanceKcal > 2000) {
      throw ArgumentError('allowanceKcal must be 0–2000, got $allowanceKcal');
    }
    if (targetKcalOverride != null &&
        (targetKcalOverride! < 1000 || targetKcalOverride! > 5000)) {
      throw ArgumentError(
        'targetKcalOverride must be 1000–5000, got $targetKcalOverride',
      );
    }
  }

  int get effectiveDailyTarget {
    if (targetKcalOverride != null) return targetKcalOverride!;
    const calc = TargetCalculator();
    final bmr = calc.bmr(
      weightKg: weightKg,
      heightCm: heightCm.toDouble(),
      age: age,
      gender: gender,
    );
    final tdee = calc.tdee(bmr, activityLevel);
    return calc.dailyTarget(tdeeValue: tdee, goal: goal, gender: gender);
  }

  int get effectiveDailyLimit => effectiveDailyTarget + allowanceKcal;

  Profile copyWith({
    double? weightKg,
    double? goalWeightKg,
    int? heightCm,
    int? age,
    Gender? gender,
    Goal? goal,
    ActivityLevel? activityLevel,
    int? allowanceKcal,
    int? targetKcalOverride,
    List<String>? equipment,
    DateTime? updatedAt,
  }) {
    return Profile(
      weightKg: weightKg ?? this.weightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      activityLevel: activityLevel ?? this.activityLevel,
      allowanceKcal: allowanceKcal ?? this.allowanceKcal,
      targetKcalOverride: targetKcalOverride ?? this.targetKcalOverride,
      equipment: equipment ?? this.equipment,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    weightKg,
    goalWeightKg,
    heightCm,
    age,
    gender,
    goal,
    activityLevel,
    allowanceKcal,
    targetKcalOverride,
    equipment,
    updatedAt,
  ];

  @override
  String toString() =>
      'Profile(${weightKg}kg, ${heightCm}cm, age=$age, limit=$effectiveDailyLimit)';
}
