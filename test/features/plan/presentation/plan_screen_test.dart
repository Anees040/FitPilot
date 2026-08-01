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
