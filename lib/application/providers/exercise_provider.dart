import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/domain/engines/muscle_synonyms.dart';
import 'package:fitpilot/domain/entities/exercise.dart';

/// Currently selected category filter for the exercise library.
final exerciseCategoryFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Currently selected pace filter for the exercise library.
final exercisePaceFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Search query for the exercise library.
final exerciseSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Filtered exercise list based on search + category + pace filters.
final exerciseListProvider = FutureProvider.autoDispose<List<Exercise>>((ref) async {
  final repo = await ref.watch(exerciseRepositoryProvider.future);
  final query = ref.watch(exerciseSearchQueryProvider);
  final category = ref.watch(exerciseCategoryFilterProvider);
  final pace = ref.watch(exercisePaceFilterProvider);

  if (query.trim().isNotEmpty) {
    final results = await repo.searchByName(query);
    return results.where((e) {
      if (category != null && e.category.name != category) return false;
      if (pace != null && e.paceTier != pace) return false;
      return true;
    }).toList();
  }

  return repo.filtered(
    category: category,
    paceTier: pace,
  );
});

final hubMuscleExercisesProvider = FutureProvider.autoDispose.family<List<Exercise>, String>((ref, muscleId) async {
  final repo = await ref.watch(exerciseRepositoryProvider.future);
  final all = await repo.all();

  return all
      .where((e) => MuscleSynonyms.matches(e.primaryMuscles, muscleId))
      .toList();
});

final hubCategoryExercisesProvider = FutureProvider.autoDispose.family<List<Exercise>, String>((ref, categoryId) async {
  final repo = await ref.watch(exerciseRepositoryProvider.future);
  final all = await repo.all();

  final target = categoryId.toLowerCase();

  if (target == 'upper_body') {
    final upperMuscles = {'chest', 'back', 'lower back', 'traps', 'shoulders', 'biceps', 'triceps', 'grip', 'core'};
    return all.where((e) {
      final isFullBody = e.primaryMuscles.any((m) => m.toLowerCase() == 'full body');
      if (isFullBody) return true;
      return e.primaryMuscles.any((m) => upperMuscles.contains(m.toLowerCase()));
    }).toList();
  } else if (target == 'lower_body') {
    final lowerMuscles = {'legs', 'quads', 'hams', 'glutes', 'hip flexors'};
    return all.where((e) {
      final isFullBody = e.primaryMuscles.any((m) => m.toLowerCase() == 'full body');
      if (isFullBody) return true;
      return e.primaryMuscles.any((m) => lowerMuscles.contains(m.toLowerCase()));
    }).toList();
  }

  // Any other category id follows the same muscle-group rules as the tiles.
  return all
      .where((e) => MuscleSynonyms.matches(e.primaryMuscles, target))
      .toList();
});
