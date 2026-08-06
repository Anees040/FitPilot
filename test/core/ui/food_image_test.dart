import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/food_image.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.getDarkTheme(),
  // Center passes loose constraints, so a FoodImage with an explicit size can
  // actually take that size instead of being stretched by the parent.
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('falls back to category art when nothing resolves', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const FoodImage(name: 'Zorbulax Surprise')));
    await tester.pump();

    expect(find.byType(FoodCategoryArt), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders the bundled asset when the name resolves', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const FoodImage(name: 'Chicken Biryani')));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, 'assets/food_images/biryani.webp');
  });

  testWidgets('an explicit imageKey wins over the name', (tester) async {
    await tester.pumpWidget(
      _wrap(const FoodImage(name: 'Zorbulax Surprise', imageKey: 'pizza')),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/food_images/pizza.webp');
  });

  testWidgets('a broken asset degrades to the icon, not an error box', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const FoodImage(name: 'Anything', imageKey: 'no_such_key')),
    );
    await tester.pump();
    // Let the asset load fail and the errorBuilder run.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FoodCategoryArt), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders at the requested size', (tester) async {
    await tester.pumpWidget(
      _wrap(const FoodImage(name: 'Chicken Biryani', size: 56)),
    );
    await tester.pump();

    final box = tester.getSize(find.byType(FoodImage));
    expect(box.width, 56);
    expect(box.height, 56);
  });
}
