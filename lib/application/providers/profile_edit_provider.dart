import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/entities/profile.dart';

final profileEditProvider = AsyncNotifierProvider<ProfileEditNotifier, void>(
  ProfileEditNotifier.new,
);

class ProfileEditNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateProfile({
    double? weightKg,
    double? goalWeightKg,
    int? heightCm,
    int? age,
    Gender? gender,
    Goal? goal,
    ActivityLevel? activityLevel,
    int? allowanceKcal,
    int? targetKcalOverride,
    bool clearOverride = false,
    List<String>? equipment,
  }) async {
    final repo = await ref.read(profileRepositoryProvider.future);
    final currentProfile = await ref.read(profileProvider.future);

    final updated = currentProfile.copyWith(
      weightKg: weightKg,
      goalWeightKg: goalWeightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
      goal: goal,
      activityLevel: activityLevel,
      allowanceKcal: allowanceKcal,
      targetKcalOverride: clearOverride
          ? null
          : (targetKcalOverride ?? currentProfile.targetKcalOverride),
      equipment: equipment,
      updatedAt: DateTime.now(),
    );

    await repo.save(updated);

    // Refresh global states
    ref.invalidate(profileProvider);
    ref.read(syncTriggerManagerProvider)?.onLocalWrite();
    // Invalidating profileProvider might automatically invalidate those that watch it
  }
}
