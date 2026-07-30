import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/features/exercises/presentation/exercise_library_screen.dart';
import 'package:fitpilot/application/providers/exercise_provider.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

void main() {
  Widget createTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ExerciseLibraryScreen(),
      ),
    );
  }

  testWidgets('Renders library screen with empty state', (tester) async {
    final container = ProviderContainer(
      overrides: [
        exerciseListProvider.overrideWith((ref) => []),
      ],
    );

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('No exercises match. Try removing a filter.'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('Renders library screen with exercises', (tester) async {
    final mockExercise = Exercise(
      id: 'test-1',
      name: 'Push-ups',
      category: ExerciseCategory.calisthenics,
      met: 8.0,
      difficulty: 1,
      paceTier: 'quick',
      equipment: null,
      primaryMuscles: const ['Chest'],
    );

    final container = ProviderContainer(
      overrides: [
        exerciseListProvider.overrideWith((ref) => [mockExercise]),
      ],
    );

    await tester.pumpWidget(createTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('1 exercises'), findsOneWidget);
    expect(find.text('Push-ups'), findsOneWidget);
    expect(find.text('No equipment, Chest'), findsOneWidget);
  });
}
