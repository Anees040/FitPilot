import 'package:equatable/equatable.dart';

/// A single burn option (activity + duration).
class BurnOption extends Equatable {
  final String activity;
  final int minutes;
  final int kcal;
  final int? steps;
  final String? exerciseId;
  final int? difficulty;
  final String? mediaAsset;
  final int sessions;
  final int minutesPerSession;

  /// MET value of the underlying exercise. Present for single-exercise options
  /// so the UI can re-cost an edited duration; null for composite options
  /// (e.g. a whole program session) whose kcal is already fixed.
  final double? met;

  const BurnOption({
    required this.activity,
    required this.minutes,
    required this.kcal,
    this.steps,
    this.exerciseId,
    this.difficulty,
    this.mediaAsset,
    this.sessions = 1,
    this.minutesPerSession = 0,
    this.met,
  });

  @override
  List<Object?> get props => [activity, minutes, kcal, steps, exerciseId, difficulty, mediaAsset, sessions, minutesPerSession, met];

  @override
  String toString() =>
      'BurnOption($activity, ${minutes}min, ${kcal}kcal'
      '${steps != null ? ', ${steps}steps' : ''})';
}
