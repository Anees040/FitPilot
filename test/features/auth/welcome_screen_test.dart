import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/features/auth/presentation/welcome_screen.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

void main() {
  Widget buildTestApp({bool disableAnimations = false}) {
    final testRouter = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: Text('Today Screen Mock')),
        ),
      ],
    );

    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: testRouter,
      ),
    );
  }

  testWidgets('WelcomeScreen auto-advances if animations are enabled', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    
    // Initial page text should be visible
    expect(find.text('Log food in seconds'), findsOneWidget);

    // Wait 4 seconds for timer
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Now it should have advanced to page 2
    expect(find.text('See your day at a glance'), findsOneWidget);
  });

  testWidgets('WelcomeScreen does NOT auto-advance if animations disabled', (tester) async {
    await tester.pumpWidget(buildTestApp(disableAnimations: true));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Log food in seconds'), findsOneWidget);

    // Wait 4 seconds for timer
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Still on page 1
    expect(find.text('Log food in seconds'), findsOneWidget);
    expect(find.text('See your day at a glance'), findsNothing);
  });

  testWidgets('Skip button navigates away', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Find and tap Skip
    final skipBtn = find.text('Skip');
    expect(skipBtn, findsOneWidget);
    await tester.tap(skipBtn);
    await tester.pumpAndSettle();

    // Should no longer be on welcome screen
    expect(find.byType(WelcomeScreen), findsNothing);
  });
}
