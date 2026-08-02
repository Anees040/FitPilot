import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/entities/program.dart';
import 'package:fitpilot/domain/entities/exercise.dart';

void main() {
  group('Program Entities & MET Math', () {
    test('ProgramWithSessions returns correct totalWeeks', () {
      final program = Program(id: 'test', name: 'test', icon: 'i', goal: 'g');
      final sessions = [
        ProgramSession(id: '1', programId: 'test', weekNumber: 1, dayNumber: 1, exerciseId: 'ex1', minutes: 20),
        ProgramSession(id: '2', programId: 'test', weekNumber: 4, dayNumber: 1, exerciseId: 'ex1', minutes: 20),
        ProgramSession(id: '3', programId: 'test', weekNumber: 2, dayNumber: 1, exerciseId: 'ex1', minutes: 20),
      ];
      final pws = ProgramWithSessions(program: program, sessions: sessions);
      expect(pws.totalWeeks, 4);
    });

    test('getSessionsForWeek returns sorted sessions', () {
      final program = Program(id: 'test', name: 'test', icon: 'i', goal: 'g');
      final sessions = [
        ProgramSession(id: '1', programId: 'test', weekNumber: 1, dayNumber: 3, exerciseId: 'ex1', minutes: 20),
        ProgramSession(id: '2', programId: 'test', weekNumber: 1, dayNumber: 1, exerciseId: 'ex1', minutes: 20),
        ProgramSession(id: '3', programId: 'test', weekNumber: 2, dayNumber: 1, exerciseId: 'ex1', minutes: 20),
      ];
      final pws = ProgramWithSessions(program: program, sessions: sessions);
      
      final week1 = pws.getSessionsForWeek(1);
      expect(week1.length, 2);
      expect(week1.first.dayNumber, 1);
      expect(week1.last.dayNumber, 3);
    });

    test('SessionWithExercise calculates MET correctly', () {
      final session = ProgramSession(
        id: '1', programId: 'p', weekNumber: 1, dayNumber: 1, exerciseId: 'ex', minutes: 30
      );
      final exercise = Exercise(
        id: 'ex', name: 'ex', category: 'indoor', 
        met: 8.0, // 8 MET
        primaryMuscles: const [], secondaryMuscles: const [],
        difficulty: 1, paceTier: 'quick', steps: const [], mistakes: const []
      );

      final swe = SessionWithExercise(session: session, exercise: exercise);
      // kcal = MET * weightKg * (minutes / 60)
      // weight = 70.0
      // 8.0 * 70.0 * 0.5 = 280
      expect(swe.estimatedKcal(70.0), 280);
    });
  });
}
