import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/data/auth/fake_auth_repository.dart';
import 'package:fitpilot/core/navigation/app_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/features/auth/presentation/auth_screen.dart';

void main() {
  Widget buildTestApp(FakeAuthRepository authRepo) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
      child: MaterialApp.router(
        theme: AppTheme.getLightTheme(),
        routerConfig: appRouter,
      ),
    );
  }

  testWidgets('Google sign-in routes away from AuthScreen', (tester) async {
    final repo = FakeAuthRepository();

    await tester.pumpWidget(buildTestApp(repo));
    // Use pump(Duration) instead of pumpAndSettle — the SplashScreen has an
    // infinite pulse animation that causes pumpAndSettle to time out.
    await tester.pump(const Duration(milliseconds: 100));
    appRouter.go('/auth');
    // Pump fixed durations to allow route animation to complete.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AuthScreen), findsOneWidget);

    final googleBtn = find.byType(GoogleButton);
    expect(googleBtn, findsOneWidget);

    await tester.ensureVisible(googleBtn);
    await tester.pump(const Duration(milliseconds: 500));
    
    await tester.tap(googleBtn);
    await tester.pump();

    // Give it time for the fake 1s delay in FakeAuthRepository.signInWithGoogle.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AuthScreen), findsNothing);
  });
}
