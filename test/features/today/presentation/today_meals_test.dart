import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/features/today/presentation/today_screen.dart';
import 'package:fitpilot/features/today/presentation/widgets/log_list_item.dart';

void main() {
  testWidgets('shows a single meal preview and offers View all', (tester) async {
    await _pumpToday(tester, mealCount: 5);

    expect(find.byType(LogListItem), findsNWidgets(kTodayMealPreviewCount));
    expect(find.textContaining('View all'), findsOneWidget);
    // The affordance carries the true total, not the capped preview count.
    expect(find.textContaining('5'), findsWidgets);
    expect(find.textContaining('4 more'), findsOneWidget);
  });

  testWidgets('offers View all even with a single logged meal', (tester) async {
    await _pumpToday(tester, mealCount: 1);

    expect(find.byType(LogListItem), findsOneWidget);
    expect(find.textContaining('View all'), findsOneWidget);
    // Nothing is hidden, so the overflow hint stays away.
    expect(find.textContaining('more logged today'), findsNothing);
  });

  testWidgets('hides the meals section entirely on an empty day', (
    tester,
  ) async {
    await _pumpToday(tester, mealCount: 0);

    expect(find.byType(LogListItem), findsNothing);
    expect(find.text("Today's meals"), findsNothing);
    expect(find.textContaining('View all'), findsNothing);
  });
}

Future<void> _pumpToday(WidgetTester tester, {required int mealCount}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayProvider.overrideWith(() => _FakeTodayNotifier(mealCount)),
      ],
      child: MaterialApp(
        theme: AppTheme.getLightTheme(),
        home: const TodayScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeTodayNotifier extends TodayNotifier {
  final int mealCount;

  _FakeTodayNotifier(this.mealCount);

  @override
  Future<TodayState> build() async {
    final logs = List<FoodLog>.generate(
      mealCount,
      (i) => FoodLog(
        id: 'log-$i',
        foodName: 'Meal $i',
        quantity: 1,
        kcal: KcalRange(200, 240),
        source: LogSource.manual,
        loggedAt: DateTime(2026, 1, 1, 8 + i),
      ),
    );

    return TodayState(
      logs: logs,
      dayStatus: DayStatus(
        total: KcalRange(200 * mealCount, 240 * mealCount),
        burnedKcal: 0,
        net: KcalRange(200 * mealCount, 240 * mealCount),
        toBurn: mealCount == 0 ? 0 : 100,
        state: mealCount == 0 ? DayState.noData : DayState.unburned,
        wiggleRoomKcal: 300,
      ),
    );
  }

  @override
  Future<void> addLog(log) async {}

  @override
  Future<void> deleteLog(String logId) async {}

  @override
  Future<void> updateLogQuantity(String logId, num newQuantity) async {}

  @override
  Future<void> restoreLog(log) async {}
}
