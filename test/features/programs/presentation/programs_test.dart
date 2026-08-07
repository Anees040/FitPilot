import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/features/programs/presentation/programs_screen.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/entities/program.dart';

Profile _profile({String? activeProgramId}) => Profile(
  weightKg: 70,
  heightCm: 175,
  age: 25,
  activeProgramId: activeProgramId,
  activeProgramWeek: activeProgramId == null ? null : 1,
  activeProgramDay: activeProgramId == null ? null : 1,
  updatedAt: DateTime(2026, 8, 7),
);

Widget _wrap(Widget child, {required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(theme: AppTheme.getDarkTheme(), home: child),
);

void main() {
  testWidgets('ProgramsScreen displays empty state when no programs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProgramsScreen(),
        overrides: [
          programsProvider.overrideWith((ref) => Future.value([])),
          profileProvider.overrideWith(_FakeProfile.new),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Check back later for curated plans.'), findsOneWidget);
  });

  testWidgets('ProgramsScreen lists programs with metadata chips', (
    WidgetTester tester,
  ) async {
    const program = Program(
      id: 'p1',
      name: 'Test Program',
      icon: '🔥',
      goal: 'Goal',
      focus: ProgramFocus.core,
      level: ProgramLevel.beginner,
      durationDays: 3,
      daysPerWeek: 2,
    );
    const sessions = [
      ProgramSession(
        id: 'p1-w1-d1',
        programId: 'p1',
        weekNumber: 1,
        dayNumber: 1,
        exerciseId: 'plank',
        minutes: 10,
        title: 'Core Day',
      ),
      ProgramSession(
        id: 'p1-w1-d2',
        programId: 'p1',
        weekNumber: 1,
        dayNumber: 2,
        exerciseId: 'rest',
        minutes: 0,
        title: 'Rest day',
        kind: ProgramSessionKind.rest,
      ),
      ProgramSession(
        id: 'p1-w1-d3',
        programId: 'p1',
        weekNumber: 1,
        dayNumber: 3,
        exerciseId: 'crunches',
        minutes: 12,
        title: 'Core Day 2',
      ),
    ];
    const pws = ProgramWithSessions(program: program, sessions: sessions);

    await tester.pumpWidget(
      _wrap(
        const ProgramsScreen(),
        overrides: [
          programsProvider.overrideWith((ref) => Future.value([pws])),
          profileProvider.overrideWith(_FakeProfile.new),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Test Program'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('2×/week'), findsOneWidget);
    // Focus chips are built from the programs actually present.
    expect(find.text('Core'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('Focus filter hides programs from other focuses', (
    WidgetTester tester,
  ) async {
    const core = ProgramWithSessions(
      program: Program(
        id: 'core-1',
        name: 'Core Plan',
        icon: '🔥',
        goal: 'g',
        focus: ProgramFocus.core,
        durationDays: 1,
      ),
      sessions: [],
    );
    const strength = ProgramWithSessions(
      program: Program(
        id: 'str-1',
        name: 'Strength Plan',
        icon: '🏋️',
        goal: 'g',
        focus: ProgramFocus.strength,
        durationDays: 1,
      ),
      sessions: [],
    );

    await tester.pumpWidget(
      _wrap(
        const ProgramsScreen(),
        overrides: [
          programsProvider.overrideWith((ref) => Future.value([core, strength])),
          profileProvider.overrideWith(_FakeProfile.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Core Plan'), findsOneWidget);
    expect(find.text('Strength Plan'), findsOneWidget);

    await tester.tap(find.text('Strength').first);
    await tester.pumpAndSettle();

    expect(find.text('Core Plan'), findsNothing);
    expect(find.text('Strength Plan'), findsOneWidget);
  });
}

class _FakeProfile extends ProfileNotifier {
  @override
  Future<Profile> build() async => _profile();
}
