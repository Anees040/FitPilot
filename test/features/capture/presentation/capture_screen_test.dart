import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/features/capture/presentation/capture_screen.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

void main() {
  testWidgets('CaptureScreen mode switching and locked Scan Food', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CaptureScreen(),
        ),
      ),
    );

    // Initial mode is Barcode
    expect(find.text('Barcode'), findsOneWidget);

    // Tap Scan Food
    await tester.tap(find.text('Scan Food'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('AI Photo Logging'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // Mode is still barcode
    expect(
      find.byIcon(Icons.camera_alt),
      findsNothing,
    ); // Barcode mode has no manual capture button

    // Tap Food Label
    await tester.tap(find.text('Food Label'));
    await tester.pumpAndSettle();

    // Capture button appears
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('Layout Tests (320x640) CaptureScreen has no overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CaptureScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
