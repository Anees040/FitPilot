import 'package:equatable/equatable.dart';

/// The phase of the streak state machine.
enum StreakPhase { neutral, safe, overPending, cleared, broken }

/// The current streak state — computed from day history, never stored.
class StreakState extends Equatable {
  final StreakPhase phase;
  final int currentStreak;
  final DateTime? graceDeadline;
  final int kcalStillToBurn;

  const StreakState({
    required this.phase,
    required this.currentStreak,
    this.graceDeadline,
    this.kcalStillToBurn = 0,
  });

  @override
  List<Object?> get props => [
    phase,
    currentStreak,
    graceDeadline,
    kcalStillToBurn,
  ];

  @override
  String toString() =>
      'StreakState($phase, streak=$currentStreak, '
      'toBurn=$kcalStillToBurn)';
}
