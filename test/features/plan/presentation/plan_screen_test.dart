import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';
import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/features/plan/presentation/plan_screen.dart';

void main() {
  testWidgets('PlanScreen renders BurnOption with mediaAsset without crashing', (WidgetTester tester) async {
    const testOption = BurnOption(
      activity: 'Jumping Jacks',
      minutes: 10,
      kcal: 100,
      mediaAsset: 'exercises/jumping_jacks.webp', // Has mediaAsset
    );

    final mockState = BurnPlanState(
      frame: BurnPlanFrame.burnToday,
      kcalToBurnOrEat: 500,
      options: const [testOption],
      targetDate: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          burnPlanProvider.overrideWith(() => _MockBurnPlanNotifier(mockState)),
        ],
        child: MaterialApp(
          theme: AppTheme.getLightTheme(),
          home: const PlanScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The burn frame leads with the goal ring, target picker and filters, so on
    // the 800x600 test surface the first card sits below the fold.
    await tester.scrollUntilVisible(
      find.text('Jumping Jacks'),
      200,
      // The screen nests scrollables, so target the outer page list.
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Jumping Jacks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cleared day celebrates and still offers extra credit', (
    tester,
  ) async {
    const bonus = BurnOption(
      activity: 'Jumping Jacks',
      minutes: 10,
      kcal: 100,
      met: 8.0,
    );

    final cleared = BurnPlanState(
      frame: BurnPlanFrame.allClear,
      kcalToBurnOrEat: 0,
      options: const [bonus],
      burnedToday: 520,
      targetDate: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          burnPlanProvider.overrideWith(() => _MockBurnPlanNotifier(cleared)),
        ],
        child: MaterialApp(
          theme: AppTheme.getLightTheme(),
          home: const PlanScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Surplus cleared!'), findsOneWidget);
    expect(find.textContaining('520'), findsWidgets);
    expect(find.textContaining('streak is safe'), findsOneWidget);

    // The activity list survives so a keen user can keep training.
    expect(find.text('EXTRA CREDIT'), findsOneWidget);
    expect(find.text('Jumping Jacks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MockBurnPlanNotifier extends BurnPlanNotifier {
  final BurnPlanState _mockState;

  _MockBurnPlanNotifier(this._mockState);

  @override
  Future<BurnPlanState> build() async {
    return _mockState;
  }

  @override
  Future<void> markDone(BurnOption option) async {}

}
