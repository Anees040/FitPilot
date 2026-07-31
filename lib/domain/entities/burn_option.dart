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
  });

  @override
  List<Object?> get props => [activity, minutes, kcal, steps, exerciseId, difficulty, mediaAsset, sessions, minutesPerSession];

  @override
  String toString() =>
      'BurnOption($activity, ${minutes}min, ${kcal}kcal'
      '${steps != null ? ', ${steps}steps' : ''})';
}
