import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/features/log/presentation/widgets/quantity_stepper.dart';
import 'package:fitpilot/features/log/presentation/manual_entry_sheet.dart';
import 'package:fitpilot/features/log/presentation/log_screen.dart';
import 'package:fitpilot/features/today/presentation/today_screen.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/application/providers/food_search_provider.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('quantity stepper respects 1 and 20 bounds', (tester) async {
      int value = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return QuantityStepper(
                  value: value,
                  onChanged: (v) => setState(() => value = v),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);

      // Tap minus, should remain 1 because it's disabled
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(value, 1);

      // Tap plus to max
      for (var i = 1; i < 20; i++) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
      }
      expect(value, 20);
      expect(find.text('20'), findsOneWidget);

      // Tap plus again, should remain 20
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(value, 20);
    });

    testWidgets('manual entry rejects 0 and 5001 with visible error text', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.getLightTheme(),
            home: const Scaffold(
              body: SingleChildScrollView(child: ManualEntrySheet()),
            ),
          ),
        ),
      );

      // Enter name
      await tester.enterText(find.byType(TextField).first, 'Test Food');

      // Enter 0
      await tester.enterText(find.byType(TextField).last, '0');
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(find.text('Calories must be between 1 and 5000'), findsOneWidget);

      // Enter 5001
      await tester.enterText(find.byType(TextField).last, '5001');
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(find.text('Calories must be between 1 and 5000'), findsOneWidget);
    });
  });

  group('Layout Tests (320x640)', () {
    testWidgets('LogScreen has no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      // Mock providers
      final container = ProviderContainer(
        overrides: [
          todayProvider.overrideWith(() => MockTodayNotifier()),
          foodSearchProvider.overrideWith(() => MockFoodSearchNotifier()),
        ],
      );

      // Render LogScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.getLightTheme(),
            home: const LogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle(); // Wait for any animations
      expect(tester.takeException(), isNull); // Ensures no overflow exception

      // Reset view
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('TodayScreen has no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      // Mock providers
      final container = ProviderContainer(
        overrides: [
          todayProvider.overrideWith(() => MockTodayNotifier()),
          foodSearchProvider.overrideWith(() => MockFoodSearchNotifier()),
        ],
      );

      // Render TodayScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.getLightTheme(),
            home: const TodayScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle(); // Wait for animations
      expect(tester.takeException(), isNull); // Ensures no overflow exception

      // Reset view
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });
}

// Mocks
class MockTodayNotifier extends AsyncNotifier<TodayState>
    implements TodayNotifier {
  @override
  Future<TodayState> build() async {
    return TodayState(
      logs: [],
      dayStatus: DayStatus(
        total: KcalRange.exact(0),
        burnedKcal: 0,
        net: KcalRange.exact(0),
        remainingKcal: 300,
        state: DayState.under,
        targetKcal: 2000, allowanceKcal: 300,
      ),
    );
  }

  @override
  Future<void> addLog(log) async {}

  @override
  Future<void> deleteLog(String logId) async {}

  @override
  Future<void> updateLogQuantity(String logId, num newQuantity) async {}
}

class MockFoodSearchNotifier extends AutoDisposeAsyncNotifier<List<FoodItem>>
    implements FoodSearchNotifier {
  @override
  Future<List<FoodItem>> build() async {
    return [];
  }
}
