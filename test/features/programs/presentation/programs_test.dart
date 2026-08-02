import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/features/programs/presentation/programs_screen.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/domain/entities/program.dart';

void main() {
  testWidgets('ProgramsScreen displays empty state when no programs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: ProgramsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No Programs'), findsOneWidget);
  });

  testWidgets('ProgramsScreen displays list of programs', (WidgetTester tester) async {
    final program = Program(id: 'p1', name: 'Test Program', icon: '🔥', goal: 'Goal');
    final pws = ProgramWithSessions(program: program, sessions: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programsProvider.overrideWith((ref) => Future.value([pws])),
        ],
        child: const MaterialApp(
          home: ProgramsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Test Program'), findsOneWidget);
    expect(find.text('0 weeks • 0 sessions'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
  });
}
