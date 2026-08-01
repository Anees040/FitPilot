import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/features/profile/presentation/profile_screen.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class MockProfileNotifier extends AsyncNotifier<Profile> implements ProfileNotifier {
  Profile _current;
  
  MockProfileNotifier(this._current);

  @override
  Future<Profile> build() async {
    return _current;
  }

  void updateWeight(double newWeight) {
    _current = _current.copyWith(weightKg: newWeight);
    state = AsyncData(_current);
  }
}

void main() {
  testWidgets('ProfileScreen text field syncs when profile updates externally', (tester) async {
    final mockProfile = Profile(
      weightKg: 70.0,
      heightCm: 170,
      age: 25,
      gender: Gender.unspecified,
      goal: Goal.maintain,
      activityLevel: ActivityLevel.light,
      allowanceKcal: 300,
      equipment: const [],
      updatedAt: DateTime.now(),
    );

    final mockNotifier = MockProfileNotifier(mockProfile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => mockNotifier),
        ],
        child: MaterialApp(
          theme: AppTheme.getLightTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );

    // Wait for the mock async notifier to emit its initial data
    await tester.pump();
    await tester.pump();

    // The default weight should be 70.0
    expect(find.text('70.0'), findsOneWidget);

    // Simulate an external update (e.g., from ProgressScreen)
    mockNotifier.updateWeight(72.5);

    // Allow UI to rebuild
    await tester.pump();
    await tester.pump();

    // Verify the text field now shows 72.5 instead of 70.0
    expect(find.text('70.0'), findsNothing);
    expect(find.text('72.5'), findsOneWidget);
  });
}
