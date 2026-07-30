import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/domain/entities/exercise.dart';

/// Currently selected category filter for the exercise library.
final exerciseCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Currently selected pace filter for the exercise library.
final exercisePaceFilterProvider = StateProvider<String?>((ref) => null);

/// Search query for the exercise library.
final exerciseSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered exercise list based on search + category + pace filters.
final exerciseListProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = await ref.watch(exerciseRepositoryProvider.future);
  final query = ref.watch(exerciseSearchQueryProvider);
  final category = ref.watch(exerciseCategoryFilterProvider);
  final pace = ref.watch(exercisePaceFilterProvider);

  // If there's a search query, use searchByName then filter in-memory
  if (query.trim().isNotEmpty) {
    final results = await repo.searchByName(query);
    return results.where((e) {
      if (category != null && e.category.name != category) return false;
      if (pace != null && e.paceTier != pace) return false;
      return true;
    }).toList();
  }

  // Otherwise use filtered() for DB-level filtering
  return repo.filtered(
    category: category,
    paceTier: pace,
  );
});
