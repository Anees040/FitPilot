import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/domain/engines/profile_identity_sync.dart';
import 'package:fitpilot/domain/entities/profile.dart';

import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/domain/entities/auth_user.dart';

/// Provides the user profile, falling back to sensible defaults
/// (70 kg, 300 kcal allowance) if the user has not completed onboarding.
final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<Profile> {
  @override
  Future<Profile> build() async {
    final user = ref.watch(currentUserProvider);
    final repo = await ref.watch(profileRepositoryProvider.future);
    final profile = await repo.get();

    if (profile != null) {
      // Google supplies a display name and photo at sign-in. Fill only the
      // gaps: anything the user set themselves outranks the provider, so
      // signing in again never undoes their own edit.
      final merged = ProfileIdentitySync.merge(profile: profile, user: user);
      if (merged != null) {
        await repo.save(merged);
        return merged;
      }
      return profile;
    }

    // First run for this account: seed it with whatever the identity provider
    // told us, so the app is personalised before onboarding is finished.
    return Profile(
      name: ProfileIdentitySync.displayNameFor(user),
      avatarUrl: _avatarFrom(user),
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

  /// The provider's photo URL, if it sent one.
  String? _avatarFrom(AuthUser? user) {
    if (user == null) return null;
    for (final key in const ['avatar_url', 'picture']) {
      final value = user.metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
