import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/data/repositories/program_repository.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/program.dart';

/// Every seeded program, ordered for the browse screen.
final programsProvider = FutureProvider<List<ProgramWithSessions>>((ref) async {
  final repo = await ref.watch(programRepositoryProvider.future);
  return repo.all();
});

/// The program the user is enrolled in, or null.
///
/// Synchronous, for widgets that already handle a null/loading frame. Anything
/// that must not miss the value — the controller, the today-session provider —
/// uses [activeProgramFutureProvider] instead, because `valueOrNull` reads null
/// while the profile is rebuilding right after an enrol.
final activeProgramProvider = Provider<ProgramWithSessions?>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  final programId = profile?.activeProgramId;
  if (programId == null) return null;

  final programs = ref.watch(programsProvider).valueOrNull;
  if (programs == null) return null;

  for (final program in programs) {
    if (program.program.id == programId) return program;
  }
  return null;
});

/// Awaited variant of [activeProgramProvider].
final activeProgramFutureProvider = FutureProvider<ProgramWithSessions?>((
  ref,
) async {
  final profile = await ref.watch(profileProvider.future);
  final programId = profile.activeProgramId;
  if (programId == null) return null;

  final programs = await ref.watch(programsProvider.future);
  for (final program in programs) {
    if (program.program.id == programId) return program;
  }
  return null;
});

/// Completed days for one program.
final programProgressProvider =
    FutureProvider.family<ProgramProgress, String>((ref, programId) async {
  // Rebuilds whenever a session is marked done.
  ref.watch(programProgressRevisionProvider);
  final repo = await ref.watch(programRepositoryProvider.future);
  return repo.progressFor(programId);
});

/// Bumped after every completion so the family providers above refresh without
/// each caller having to invalidate by id.
final programProgressRevisionProvider = StateProvider<int>((ref) => 0);

/// Progress for the active program, or null when not enrolled.
final activeProgramProgressProvider = FutureProvider<ProgramProgress?>((
  ref,
) async {
  final active = await ref.watch(activeProgramFutureProvider.future);
  if (active == null) return null;
  return ref.watch(programProgressProvider(active.program.id).future);
});

/// The session at the user's current pointer, with every exercise resolved.
/// Null when not enrolled or when the pointer has run past the last day.
final todaySessionProvider = FutureProvider<ResolvedSession?>((ref) async {
  final active = await ref.watch(activeProgramFutureProvider.future);
  if (active == null) return null;

  final profile = await ref.watch(profileProvider.future);
  final day = profile.activeProgramDay;
  if (day == null) return null;

  final session = active.sessionForDay(day);
  if (session == null) return null;

  return ref.watch(resolvedSessionProvider(session).future);
});

/// Resolves a session's exercise ids against the catalog.
final resolvedSessionProvider =
    FutureProvider.family<ResolvedSession, ProgramSession>((ref, session) async {
  if (session.isRest) {
    return ResolvedSession(session: session, exercises: const []);
  }

  final repo = await ref.watch(exerciseRepositoryProvider.future);
  final exercises = <ProgramSessionExercise>[];
  for (final item in session.items) {
    final exercise = await repo.byId(item.exerciseId);
    // A missing id means the catalog and the seed drifted apart. Skip it rather
    // than blow up the whole session; the seed-integrity test guards against
    // this ever shipping.
    if (exercise == null) continue;
    exercises.add(ProgramSessionExercise(item: item, exercise: exercise));
  }
  return ResolvedSession(session: session, exercises: exercises);
});

/// Outcome of marking a session complete, so the UI knows whether to show the
/// congratulations screen.
class SessionCompletionResult {
  final bool recorded;
  final bool programFinished;
  final int kcal;
  final int completedSessions;
  final int totalKcal;

  const SessionCompletionResult({
    required this.recorded,
    required this.programFinished,
    this.kcal = 0,
    this.completedSessions = 0,
    this.totalKcal = 0,
  });
}

class ProgramsController {
  final Ref ref;
  ProgramsController(this.ref);

  /// Enrols in [programId], starting at day 1.
  ///
  /// Clears any completions for that program first: re-enrolling a plan you
  /// finished (or abandoned) must start from a clean slate, otherwise the day
  /// ticks and the progress bar show the previous run's state.
  Future<void> enroll(String programId) async {
    final profile = await ref.read(profileProvider.future);

    final programRepo = await ref.read(programRepositoryProvider.future);
    await programRepo.clearProgress(programId);

    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.save(
      profile.copyWith(
        activeProgramId: programId,
        activeProgramWeek: 1,
        activeProgramDay: 1,
        updatedAt: DateTime.now(),
      ),
    );
    _refresh();
  }

  /// Switches to a different program, wiping progress for both the one being
  /// left and the one being started.
  Future<void> switchTo(String programId) async {
    final profile = await ref.read(profileProvider.future);
    final previousId = profile.activeProgramId;
    if (previousId != null && previousId != programId) {
      final programRepo = await ref.read(programRepositoryProvider.future);
      await programRepo.clearProgress(previousId);
    }
    await enroll(programId);
  }

  /// Leaves the active program and discards its progress.
  Future<void> abandon() async {
    final profile = await ref.read(profileProvider.future);

    final programId = profile.activeProgramId;
    if (programId != null) {
      final programRepo = await ref.read(programRepositoryProvider.future);
      await programRepo.clearProgress(programId);
    }

    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.save(
      profile.copyWith(clearProgram: true, updatedAt: DateTime.now()),
    );
    _refresh();
  }

  /// Marks [resolved] done and advances the pointer by one day.
  ///
  /// A workout day inserts exactly ONE `burn_completion` labelled with the
  /// session title, so Progress and the burn maths count the program. A rest
  /// day records the day but inserts no burn — resting does not burn calories.
  ///
  /// Re-tapping an already-recorded session is a no-op: `program_completions`
  /// is keyed by session id, so the insert is ignored and the pointer stays put.
  Future<SessionCompletionResult> completeSession(ResolvedSession resolved) async {
    final profile = await ref.read(profileProvider.future);
    final active = await ref.read(activeProgramFutureProvider.future);
    if (active == null) {
      return const SessionCompletionResult(recorded: false, programFinished: false);
    }

    final session = resolved.session;
    final programRepo = await ref.read(programRepositoryProvider.future);
    final kcal = resolved.estimatedKcal(profile.weightKg);

    final recorded = await programRepo.recordCompletion(
      session: session,
      kcal: kcal,
      completedAt: DateTime.now(),
    );
    if (!recorded) {
      return const SessionCompletionResult(recorded: false, programFinished: false);
    }

    if (!session.isRest && kcal > 0) {
      final burnRepo = await ref.read(burnRepositoryProvider.future);
      final now = DateTime.now();
      await burnRepo.add(
        BurnOption(
          exerciseId: resolved.exercises.isNotEmpty
              ? resolved.exercises.first.exercise.id
              : null,
          activity: '${active.program.name}: ${session.displayTitle}',
          minutes: resolved.totalMinutes,
          kcal: kcal,
        ),
        now,
        now,
      );
    }

    final nextDay = session.dayNumber + 1;
    final nextSession = active.sessionForDay(nextDay);
    final progress = await programRepo.progressFor(active.program.id);

    if (nextSession == null) {
      // Past the last day — the plan is done. The caller shows the congrats
      // screen; the pointer is cleared but progress is kept until then so the
      // totals can be read off it.
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.save(
        profile.copyWith(clearProgram: true, updatedAt: DateTime.now()),
      );
      _refresh();
      return SessionCompletionResult(
        recorded: true,
        programFinished: true,
        kcal: kcal,
        completedSessions: progress.completedCount,
        totalKcal: progress.totalKcal,
      );
    }

    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.save(
      profile.copyWith(
        activeProgramWeek: nextSession.weekNumber,
        activeProgramDay: nextSession.dayNumber,
        updatedAt: DateTime.now(),
      ),
    );
    _refresh();
    return SessionCompletionResult(
      recorded: true,
      programFinished: false,
      kcal: kcal,
      completedSessions: progress.completedCount,
      totalKcal: progress.totalKcal,
    );
  }

  void _refresh() {
    ref.invalidate(profileProvider);
    ref.invalidate(todayProvider);
    ref.invalidate(progressProvider);
    ref.read(programProgressRevisionProvider.notifier).state++;
  }
}

final programsControllerProvider = Provider((ref) => ProgramsController(ref));

/// Convenience for screens that only need one exercise by id.
final exerciseByIdProvider = FutureProvider.family<Exercise, String>((
  ref,
  id,
) async {
  final repo = await ref.watch(exerciseRepositoryProvider.future);
  final exercise = await repo.byId(id);
  if (exercise == null) throw Exception('Exercise not found: $id');
  return exercise;
});
