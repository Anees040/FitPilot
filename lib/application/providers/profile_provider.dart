import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/domain/entities/profile.dart';

/// Provides the user profile, falling back to sensible defaults
/// (70 kg, 300 kcal allowance) if the user has not completed onboarding.
final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() async {
    final repo = await ref.watch(profileRepositoryProvider.future);
    final profile = await repo.get();

    if (profile != null) {
      return profile;
    }

    // Sensible defaults when profile doesn't exist yet
    return Profile(
      weightKg: 70.0,
      heightCm: 170, // Arbitrary valid height
      age: 25, // Arbitrary valid age
      gender: Gender.unspecified,
      goal: Goal.maintain,
      activityLevel: ActivityLevel.light,
      allowanceKcal: 300,
      equipment: const [],
      updatedAt: DateTime.now(),
    );
  }
}
