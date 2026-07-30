import 'package:equatable/equatable.dart';

/// Exercise category.
enum ExerciseCategory { gym, indoor, outdoor, calisthenics }

/// An exercise from the seed catalog.
class Exercise extends Equatable {
  final String id;
  final String name;
  final ExerciseCategory category;
  final String? subcategory;
  final double met;
  final String? equipment;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final int difficulty;
  final String paceTier;
  final List<String> steps;
  final List<String> mistakes;
  final String? mediaAsset;
  final String? videoUrl;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    this.subcategory,
    required this.met,
    this.equipment,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    required this.difficulty,
    this.paceTier = 'moderate',
    this.steps = const [],
    this.mistakes = const [],
    this.mediaAsset,
    this.videoUrl,
  }) {
    if (id.isEmpty) {
      throw ArgumentError('id must not be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError('name must not be empty');
    }
    if (difficulty < 1 || difficulty > 3) {
      throw ArgumentError('difficulty must be 1–3, got $difficulty');
    }
    if (met <= 0) {
      throw ArgumentError('met must be > 0, got $met');
    }
  }

  /// Human-readable equipment label.
  String get equipmentLabel => equipment ?? 'No equipment';

  /// Human-readable difficulty label.
  String get difficultyLabel {
    switch (difficulty) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Intermediate';
      case 3:
        return 'Advanced';
      default:
        return 'Beginner';
    }
  }

  /// Compute kcal burned in [minutes] for a user of [weightKg].
  double kcalForMinutes(double weightKg, int minutes) {
    return met * 3.5 * weightKg / 200 * minutes;
  }

  /// Compute kcal burned in 10 minutes, rounded to nearest 5.
  int kcalPer10Min(double weightKg) {
    final raw = met * 3.5 * weightKg / 200 * 10;
    return ((raw / 5).round() * 5).toInt();
  }

  /// Compute minutes needed to burn [kcal] for a user of [weightKg].
  /// Rounded UP to nearest 5, minimum 5.
  int minutesToBurn(double weightKg, int kcal) {
    if (kcal <= 0) return 0;
    final rawMinutes = kcal * 200 / (met * 3.5 * weightKg);
    var minutes = (rawMinutes / 5).ceil() * 5;
    if (minutes < 5) minutes = 5;
    return minutes;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    subcategory,
    met,
    equipment,
    primaryMuscles,
    secondaryMuscles,
    difficulty,
    paceTier,
    steps,
    mistakes,
    mediaAsset,
    videoUrl,
  ];

  @override
  String toString() => 'Exercise($id, $name, MET=$met)';
}
