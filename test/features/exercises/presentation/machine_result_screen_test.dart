import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/application/providers/machine_scanner_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';
import 'package:fitpilot/features/exercises/presentation/machine_result_screen.dart';

const _latPulldown = MachineAnalysis(
  isGymMachine: true,
  machineName: 'Lat Pulldown Machine',
  confidence: 0.93,
  primaryMuscles: ['Lats', 'Back'],
  secondaryMuscles: ['Biceps'],
  howToUse: [
    'Set the thigh pad so your legs are snug',
    'Grip the bar wider than your shoulders',
    'Sit down and let your arms extend',
    'Pull the bar to your upper chest',
    'Let the bar rise back under control',
  ],
  commonMistakes: [
    'Leaning far back and using momentum',
    'Pulling the bar behind your neck',
    'Choosing a weight you cannot control',
  ],
  safetyTips: [
    'Keep your chest up and back straight',
    'Never drop the stack between reps',
  ],
  suggestedExerciseKeywords: ['lat pulldown', 'seated cable row'],
);

Exercise _exercise(String id, String name) => Exercise(
  id: id,
  name: name,
  category: ExerciseCategory.gym,
  met: 5.0,
  difficulty: 1,
  equipment: 'Machine',
  primaryMuscles: const ['Back'],
);

Future<void> _pump(
  WidgetTester tester,
  MachineAnalysis analysis, {
  List<Exercise> related = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        relatedExercisesProvider(analysis).overrideWith((ref) async => related),
      ],
      child: MaterialApp(
        theme: AppTheme.getDarkTheme(),
        home: MachineResultScreen(analysis: analysis),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the result list until [finder] is built and visible.
///
/// The screen is a lazy ListView, so anything below the fold is not in the
/// widget tree until scrolled to — asserting on it directly would fail even
/// though the section renders correctly on a real device.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the machine name, muscles and all guidance', (tester) async {
    await _pump(tester, _latPulldown);

    expect(find.text('Lat Pulldown Machine'), findsOneWidget);

    // Confidence chip.
    expect(find.textContaining('High confidence'), findsOneWidget);

    // Muscle chips, primary and secondary.
    expect(find.text('Lats'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Biceps'), findsOneWidget);

    // Section headings.
    expect(find.text('How to use'), findsOneWidget);

    // Every step is rendered, numbered from 1.
    expect(find.text('Set the thigh pad so your legs are snug'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // The rest lives below the fold.
    await _scrollTo(tester, find.text('Common mistakes'));
    expect(find.text('Pulling the bar behind your neck'), findsOneWidget);

    await _scrollTo(tester, find.text('Safety tips'));
    expect(find.text('Never drop the stack between reps'), findsOneWidget);

    await _scrollTo(tester, find.text('Done'));
    expect(find.text('Scan another'), findsOneWidget);
  });

  testWidgets('a low-confidence result warns instead of asserting', (tester) async {
    const unsure = MachineAnalysis(
      isGymMachine: true,
      machineName: 'Cable Crossover',
      confidence: 0.52,
      primaryMuscles: ['Chest'],
      howToUse: ['Set the pulleys high'],
    );

    await _pump(tester, unsure);

    expect(find.textContaining('Medium confidence'), findsOneWidget);
    expect(find.textContaining('double-check'), findsOneWidget);
  });

  testWidgets('related exercises render when the matcher finds some', (tester) async {
    await _pump(
      tester,
      _latPulldown,
      related: [
        _exercise('lat-pulldown', 'Lat pulldown'),
        _exercise('seated-cable-row', 'Seated cable row'),
      ],
    );

    await _scrollTo(tester, find.text('Related exercises in FitPilot'));
    expect(find.text('Lat pulldown'), findsOneWidget);
    expect(find.text('Seated cable row'), findsOneWidget);
  });

  testWidgets('the related section is hidden when nothing matches', (tester) async {
    await _pump(tester, _latPulldown, related: const []);

    // Scroll to the bottom; the section must not appear anywhere.
    await _scrollTo(tester, find.text('Done'));
    expect(find.text('Related exercises in FitPilot'), findsNothing);
  });

  testWidgets('a non-machine photo gets the friendly retake state', (tester) async {
    const notAMachine = MachineAnalysis(
      isGymMachine: false,
      machineName: 'a domestic cat',
      confidence: 0.88,
    );

    await _pump(tester, notAMachine);

    expect(find.text("That doesn't look like a gym machine"), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    // It says what it actually saw, so the user knows why it failed.
    expect(find.textContaining('a domestic cat'), findsOneWidget);
    // None of the coaching UI leaks into this state.
    expect(find.text('How to use'), findsNothing);
    expect(find.text('Scan another'), findsNothing);
  });

  testWidgets('sections with no content are omitted rather than left empty', (tester) async {
    const sparse = MachineAnalysis(
      isGymMachine: true,
      machineName: 'Leg Press',
      confidence: 0.8,
      primaryMuscles: ['Quads'],
      howToUse: ['Sit down and press'],
    );

    await _pump(tester, sparse);

    expect(find.text('How to use'), findsOneWidget);
    // Short enough to fit without scrolling, so absence here is meaningful.
    expect(find.text('Common mistakes'), findsNothing);
    expect(find.text('Safety tips'), findsNothing);
  });

  testWidgets('a long result scrolls without overflowing', (tester) async {
    await _pump(tester, _latPulldown);

    // A RenderFlex overflow during layout fails the test via the exception
    // reporter, so reaching here with content scrolled is the assertion.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
