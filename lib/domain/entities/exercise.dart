import 'package:equatable/equatable.dart';

/// Exercise category.
enum ExerciseCategory { gym, outdoor, calisthenics }

/// An exercise from the seed catalog.
class Exercise extends Equatable {
  final String id;
  final String name;
  final ExerciseCategory category;
  final List<String> equipment;
  final int difficulty;
  final List<String> muscles;
  final List<String> steps;
  final List<String> mistakes;
  final double met;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    this.equipment = const [],
    required this.difficulty,
    this.muscles = const [],
    this.steps = const [],
    this.mistakes = const [],
    required this.met,
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

  @override
  List<Object?> get props =>
      [id, name, category, equipment, difficulty, muscles, steps, mistakes, met];

  @override
  String toString() => 'Exercise($id, $name, MET=$met)';
}
