import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/core/utils/require_online.dart';
import 'package:fitpilot/application/providers/network_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

void main() {
  testWidgets('requireOnline shows snackbar and returns false when offline', (tester) async {
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: MaterialApp(
          theme: AppTheme.getLightTheme(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(isOnlineProvider); // Keep it alive
                return ElevatedButton(
                  onPressed: () {
                    result = requireOnline(context, ref, feature: 'Test Feature');
                  },
                  child: const Text('Check'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Wait for stream to emit
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(result, false);
    expect(find.textContaining('Test Feature needs an internet connection'), findsOneWidget);
  });

  testWidgets('requireOnline returns true when online', (tester) async {
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: AppTheme.getLightTheme(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(isOnlineProvider);
                return ElevatedButton(
                  onPressed: () {
                    result = requireOnline(context, ref, feature: 'Test Feature');
                  },
                  child: const Text('Check'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Wait for stream to emit
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(result, true);
    expect(find.textContaining('Test Feature needs an internet connection'), findsNothing);
  });
}
