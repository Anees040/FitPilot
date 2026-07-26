import 'package:equatable/equatable.dart';

/// User's fitness goal.
enum Goal { lose, maintain, build }

/// User profile — single-row entity.
class Profile extends Equatable {
  final double weightKg;
  final int heightCm;
  final int age;
  final String? gender;
  final Goal goal;
  final int allowanceKcal;
  final List<String> equipment;
  final DateTime updatedAt;

  static const int defaultAllowanceKcal = 300;

  Profile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    this.gender,
    this.goal = Goal.maintain,
    this.allowanceKcal = defaultAllowanceKcal,
    this.equipment = const [],
    required this.updatedAt,
  }) {
    if (weightKg < 25 || weightKg > 300) {
      throw ArgumentError('weightKg must be 25–300, got $weightKg');
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
  }

  Profile copyWith({
    double? weightKg,
    int? heightCm,
    int? age,
    String? gender,
    Goal? goal,
    int? allowanceKcal,
    List<String>? equipment,
    DateTime? updatedAt,
  }) {
    return Profile(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      allowanceKcal: allowanceKcal ?? this.allowanceKcal,
      equipment: equipment ?? this.equipment,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    weightKg,
    heightCm,
    age,
    gender,
    goal,
    allowanceKcal,
    equipment,
    updatedAt,
  ];

  @override
  String toString() => 'Profile(${weightKg}kg, ${heightCm}cm, age=$age)';
}
