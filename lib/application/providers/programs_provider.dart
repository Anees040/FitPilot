import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/domain/entities/program.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';

final programsProvider = FutureProvider<List<ProgramWithSessions>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  
  final programsResult = await db.query('programs');
  final sessionsResult = await db.query('program_sessions');
  
  final programs = <Program>[];
  for (final row in programsResult) {
    programs.add(Program(
      id: row['id'] as String,
      name: row['name'] as String,
      icon: row['icon'] as String,
      goal: row['goal'] as String,
    ));
  }
  
  final sessions = <ProgramSession>[];
  for (final row in sessionsResult) {
    sessions.add(ProgramSession(
      id: row['id'] as String,
      programId: row['program_id'] as String,
      weekNumber: row['week_number'] as int,
      dayNumber: row['day_number'] as int,
      exerciseId: row['exercise_id'] as String,
      minutes: row['minutes'] as int,
    ));
  }
  
  final result = <ProgramWithSessions>[];
  for (final p in programs) {
    final pSessions = sessions.where((s) => s.programId == p.id).toList();
    result.add(ProgramWithSessions(program: p, sessions: pSessions));
  }
  
  return result;
});

final activeProgramProvider = Provider<ProgramWithSessions?>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile?.activeProgramId == null) return null;
  
  final programs = ref.watch(programsProvider).valueOrNull;
  if (programs == null) return null;
  
  try {
    return programs.firstWhere((p) => p.program.id == profile!.activeProgramId);
  } catch (_) {
    return null;
  }
});

class ProgramsController {
  final Ref ref;
  ProgramsController(this.ref);

  Future<void> enroll(String programId) async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;
    
    final repo = await ref.read(profileRepositoryProvider.future);
    final newProfile = profile.copyWith(
      activeProgramId: programId,
      activeProgramWeek: 1,
      activeProgramDay: 1,
    );
    await repo.save(newProfile);
    ref.invalidate(profileProvider);
  }

  Future<void> leaveProgram() async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;
    
    final repo = await ref.read(profileRepositoryProvider.future);
    final newProfile = profile.copyWith(
      clearProgram: true,
      activeProgramWeek: null,
      activeProgramDay: null,
    );
    await repo.save(newProfile);
    ref.invalidate(profileProvider);
  }

  Future<void> markSessionDone(ProgramSession session, int burnedKcal) async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;

    // 1. Insert burn completion
    final burnRepo = await ref.read(burnRepositoryProvider.future);
    
    // Fetch exercise name for activity string
    final db = await ref.read(databaseProvider.future);
    final exRow = await db.query('exercises', where: 'id = ?', whereArgs: [session.exerciseId]);
    final exName = exRow.isNotEmpty ? exRow.first['name'] as String : 'Exercise';

    final burn = BurnOption(
      exerciseId: session.exerciseId,
      activity: 'Program: $exName',
      minutes: session.minutes,
      kcal: burnedKcal,
    );
    
    await burnRepo.add(burn, DateTime.now().toUtc(), DateTime.now().toUtc());
    ref.invalidate(todayProvider);
    
    // 2. Advance program progress
    final program = ref.read(activeProgramProvider);
    if (program != null && profile.activeProgramWeek != null && profile.activeProgramDay != null) {
      int nextWeek = profile.activeProgramWeek!;
      int nextDay = profile.activeProgramDay! + 1;
      
      final currentWeekSessions = program.getSessionsForWeek(nextWeek);
      if (nextDay > currentWeekSessions.length) {
        nextWeek++;
        nextDay = 1;
      }
      
      if (nextWeek > program.totalWeeks) {
        // Finished program
        await leaveProgram();
        return;
      }
      
      final repo = await ref.read(profileRepositoryProvider.future);
      final newProfile = profile.copyWith(
        activeProgramWeek: nextWeek,
        activeProgramDay: nextDay,
      );
      await repo.save(newProfile);
      ref.invalidate(profileProvider);
    }
  }
}

final programsControllerProvider = Provider((ref) => ProgramsController(ref));
