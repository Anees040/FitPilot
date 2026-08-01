import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/features/log/presentation/widgets/food_result_tile.dart';

void main() {
  testWidgets('FoodResultCard renders without overflow on small screens with large text', (WidgetTester tester) async {
    // 320px width x 600px height (small phone)
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final testFood = FoodItem(
      id: 'test_food',
      name: 'Very Long Food Name That Might Overflow If Not Handled Properly With MaxLines',
      portionLabel: '1 bowl',
      kcalPerPortion: KcalRange(300, 400),
      isVerified: true,
      imageUrl: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 600),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150, // Half of 320px in a 2-column grid
                child: FoodResultCard(
                  food: testFood,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FoodResultCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
