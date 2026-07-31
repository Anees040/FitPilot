import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/data/auth/fake_auth_repository.dart';
import 'package:fitpilot/core/navigation/app_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/features/auth/presentation/sign_in_screen.dart';

void main() {
  Widget buildTestApp(FakeAuthRepository authRepo) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }

  testWidgets('Google sign-in routes away from SignInScreen', (tester) async {
    final repo = FakeAuthRepository();
    
    await tester.pumpWidget(buildTestApp(repo));
    appRouter.go('/signin');
    await tester.pumpAndSettle();
    
    expect(find.byType(SignInScreen), findsOneWidget);
    
    final googleBtn = find.byType(GoogleButton);
    expect(googleBtn, findsOneWidget);
    
    await tester.tap(googleBtn);
    await tester.pump();
    
    // Give it time to fake delay
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    
    expect(find.byType(SignInScreen), findsNothing);
  });
}
