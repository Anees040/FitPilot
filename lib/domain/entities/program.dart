import 'package:equatable/equatable.dart';
import 'package:fitpilot/domain/entities/exercise.dart';

/// What a program is built around. Drives the browse filter chips, so every
/// seeded program must carry one of these — there is no "unknown" bucket.
enum ProgramFocus { core, fullBody, lowerBody, upperBody, strength, weightLoss, cardio }

/// How hard a program is, shown as a badge on the browse card.
enum ProgramLevel { beginner, intermediate, advanced }

/// What the user needs to run a program.
enum ProgramEquipment { none, minimal, gym }

/// A single day of a program. Rest days carry no exercises.
enum ProgramSessionKind { workout, rest }

ProgramFocus programFocusFrom(String? raw) {
  switch (raw) {
    case 'core':
      return ProgramFocus.core;
    case 'lower_body':
      return ProgramFocus.lowerBody;
    case 'upper_body':
      return ProgramFocus.upperBody;
    case 'strength':
      return ProgramFocus.strength;
    case 'weight_loss':
      return ProgramFocus.weightLoss;
    case 'cardio':
      return ProgramFocus.cardio;
    default:
      return ProgramFocus.fullBody;
  }
}

ProgramLevel programLevelFrom(String? raw) {
  switch (raw) {
    case 'intermediate':
      return ProgramLevel.intermediate;
    case 'advanced':
      return ProgramLevel.advanced;
    default:
      return ProgramLevel.beginner;
  }
}

ProgramEquipment programEquipmentFrom(String? raw) {
  switch (raw) {
    case 'minimal':
      return ProgramEquipment.minimal;
    case 'gym':
      return ProgramEquipment.gym;
    default:
      return ProgramEquipment.none;
  }
}

ProgramSessionKind programSessionKindFrom(String? raw) =>
    raw == 'rest' ? ProgramSessionKind.rest : ProgramSessionKind.workout;

extension ProgramFocusLabel on ProgramFocus {
  String get label {
    switch (this) {
      case ProgramFocus.core:
        return 'Core';
      case ProgramFocus.fullBody:
        return 'Full body';
      case ProgramFocus.lowerBody:
        return 'Lower body';
      case ProgramFocus.upperBody:
        return 'Upper body';
      case ProgramFocus.strength:
        return 'Strength';
      case ProgramFocus.weightLoss:
        return 'Weight loss';
      case ProgramFocus.cardio:
        return 'Cardio';
    }
  }
}

extension ProgramLevelLabel on ProgramLevel {
  String get label {
    switch (this) {
      case ProgramLevel.beginner:
        return 'Beginner';
      case ProgramLevel.intermediate:
        return 'Intermediate';
      case ProgramLevel.advanced:
        return 'Advanced';
    }
  }
}

extension ProgramEquipmentLabel on ProgramEquipment {
  String get label {
    switch (this) {
      case ProgramEquipment.none:
        return 'No equipment';
      case ProgramEquipment.minimal:
        return 'Minimal kit';
      case ProgramEquipment.gym:
        return 'Gym access';
    }
  }
}

class Program extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String goal;
  final ProgramLevel level;
  final ProgramFocus focus;
  final ProgramEquipment equipment;

  /// Total plan days, rest days included. Equals the highest [ProgramSession]
  /// day number, because day numbers run 1..durationDays across the program.
  final int durationDays;
  final int daysPerWeek;
  final String? heroImage;
  final int sortIndex;

  const Program({
    required this.id,
    required this.name,
    required this.icon,
    required this.goal,
    this.level = ProgramLevel.beginner,
    this.focus = ProgramFocus.fullBody,
    this.equipment = ProgramEquipment.none,
    this.durationDays = 0,
    this.daysPerWeek = 0,
    this.heroImage,
    this.sortIndex = 100,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    icon,
    goal,
    level,
    focus,
    equipment,
    durationDays,
    daysPerWeek,
    heroImage,
    sortIndex,
  ];
}

/// One exercise inside a session, in the order the user should perform it.
class ProgramSessionItem extends Equatable {
  final String id;
  final String sessionId;
  final int position;
  final String exerciseId;
  final int minutes;

  /// Sets / reps / hold prescription, e.g. "3 × 45 s hold". Carries the weekly
  /// progression that minutes alone can't express.
  final String? detail;

  const ProgramSessionItem({
    required this.id,
    required this.sessionId,
    required this.position,
    required this.exerciseId,
    required this.minutes,
    this.detail,
  });

  @override
  List<Object?> get props => [id, sessionId, position, exerciseId, minutes, detail];
}

class ProgramSession extends Equatable {
  final String id;
  final String programId;
  final int weekNumber;

  /// Position in the whole plan, 1..[Program.durationDays] — not per-week.
  final int dayNumber;

  /// First exercise of the session, or `'rest'` on a rest day. Kept as a column
  /// so the session row is readable on its own.
  final String exerciseId;

  /// Total minutes across [items].
  final int minutes;
  final String title;
  final String? focus;
  final ProgramSessionKind kind;
  final String? notes;
  final List<ProgramSessionItem> items;

  const ProgramSession({
    required this.id,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    required this.exerciseId,
    required this.minutes,
    this.title = '',
    this.focus,
    this.kind = ProgramSessionKind.workout,
    this.notes,
    this.items = const [],
  });

  bool get isRest => kind == ProgramSessionKind.rest;

  /// Falls back to the stored column so legacy single-exercise rows still work.
  int get totalMinutes => items.isEmpty
      ? minutes
      : items.fold(0, (sum, item) => sum + item.minutes);

  String get displayTitle {
    if (title.isNotEmpty) return title;
    return isRest ? 'Rest day' : 'Day $dayNumber';
  }

  @override
  List<Object?> get props => [
    id,
    programId,
    weekNumber,
    dayNumber,
    exerciseId,
    minutes,
    title,
    focus,
    kind,
    notes,
    items,
  ];
}

class ProgramWithSessions extends Equatable {
  final Program program;

  /// Ordered by [ProgramSession.dayNumber].
  final List<ProgramSession> sessions;

  const ProgramWithSessions({required this.program, required this.sessions});

  int get totalWeeks {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.weekNumber).reduce((a, b) => a > b ? a : b);
  }

  /// Plan length in days. Prefers the seeded value and falls back to the
  /// session count so a program is never advertised as "0 days".
  int get totalDays =>
      program.durationDays > 0 ? program.durationDays : sessions.length;

  int get workoutDays => sessions.where((s) => !s.isRest).length;

  int get restDays => sessions.where((s) => s.isRest).length;

  List<ProgramSession> getSessionsForWeek(int week) {
    return sessions.where((s) => s.weekNumber == week).toList()
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
  }

  /// The session at plan day [day], or null when [day] runs past the end —
  /// which is exactly how the controller detects "program finished".
  ProgramSession? sessionForDay(int day) {
    for (final session in sessions) {
      if (session.dayNumber == day) return session;
    }
    return null;
  }

  @override
  List<Object?> get props => [program, sessions];
}

/// A session item paired with the exercise it points at.
class ProgramSessionExercise extends Equatable {
  final ProgramSessionItem item;
  final Exercise exercise;

  const ProgramSessionExercise({required this.item, required this.exercise});

  /// kcal/min = MET × 3.5 × weightKg ÷ 200.
  int estimatedKcal(double weightKg) =>
      exercise.kcalForMinutes(weightKg, item.minutes).round();

  @override
  List<Object?> get props => [item, exercise];
}

/// A session with every exercise resolved — what the session screen renders and
/// what the "mark complete" burn entry is costed from.
class ResolvedSession extends Equatable {
  final ProgramSession session;
  final List<ProgramSessionExercise> exercises;

  const ResolvedSession({required this.session, required this.exercises});

  bool get isRest => session.isRest;

  int get totalMinutes =>
      exercises.fold(0, (sum, e) => sum + e.item.minutes);

  /// Summed per-exercise rather than rounded once, so the total always matches
  /// the numbers listed beside each exercise.
  int estimatedKcal(double weightKg) {
    if (isRest) return 0;
    return exercises.fold(0, (sum, e) => sum + e.estimatedKcal(weightKg));
  }

  @override
  List<Object?> get props => [session, exercises];
}

/// Single-exercise pairing kept for the legacy seed shape.
class SessionWithExercise extends Equatable {
  final ProgramSession session;
  final Exercise exercise;

  const SessionWithExercise({required this.session, required this.exercise});

  /// kcal/min = MET × 3.5 × weightKg ÷ 200.
  int estimatedKcal(double weightKg) =>
      exercise.kcalForMinutes(weightKg, session.totalMinutes).round();

  @override
  List<Object?> get props => [session, exercise];
}
