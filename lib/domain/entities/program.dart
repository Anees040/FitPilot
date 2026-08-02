import 'package:equatable/equatable.dart';
import 'package:fitpilot/domain/entities/exercise.dart';

class Program extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String goal;

  const Program({
    required this.id,
    required this.name,
    required this.icon,
    required this.goal,
  });

  @override
  List<Object?> get props => [id, name, icon, goal];
}

class ProgramSession extends Equatable {
  final String id;
  final String programId;
  final int weekNumber;
  final int dayNumber;
  final String exerciseId;
  final int minutes;

  const ProgramSession({
    required this.id,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    required this.exerciseId,
    required this.minutes,
  });

  @override
  List<Object?> get props => [
        id,
        programId,
        weekNumber,
        dayNumber,
        exerciseId,
        minutes,
      ];
}

class ProgramWithSessions extends Equatable {
  final Program program;
  final List<ProgramSession> sessions;

  const ProgramWithSessions({
    required this.program,
    required this.sessions,
  });

  int get totalWeeks {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.weekNumber).reduce((a, b) => a > b ? a : b);
  }

  List<ProgramSession> getSessionsForWeek(int week) {
    return sessions.where((s) => s.weekNumber == week).toList()
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
  }

  @override
  List<Object?> get props => [program, sessions];
}

class SessionWithExercise extends Equatable {
  final ProgramSession session;
  final Exercise exercise;

  const SessionWithExercise({
    required this.session,
    required this.exercise,
  });

  int estimatedKcal(double weightKg) {
    return (exercise.met * weightKg * (session.minutes / 60)).round();
  }

  @override
  List<Object?> get props => [session, exercise];
}
