import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/domain/entities/food_item.dart';

/// Holds the raw text input for the search field.
final foodSearchQueryProvider = StateProvider<String>((ref) => '');

/// When true, only foods with a known protein figure are shown, best first.
///
/// Composes with the search text rather than replacing it, so "chana" plus the
/// filter still narrows to chana.
final highProteinFilterProvider = StateProvider<bool>((ref) => false);

/// Whether the catalog has any protein data at all.
///
/// The filter chip hides itself when this is false — a filter that can only
/// ever return an empty list is worse than no filter.
final catalogHasProteinProvider = FutureProvider<bool>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final rows = await db.rawQuery(
    'SELECT 1 FROM food_catalog WHERE protein_g IS NOT NULL LIMIT 1',
  );
  return rows.isNotEmpty;
});

/// Debounced search results returning recent foods (if empty) or matched catalog items.
final foodSearchProvider =
    AutoDisposeAsyncNotifierProvider<FoodSearchNotifier, List<FoodItem>>(
      FoodSearchNotifier.new,
    );

class FoodSearchNotifier extends AutoDisposeAsyncNotifier<List<FoodItem>> {
  @override
  Future<List<FoodItem>> build() async {
    final query = ref.watch(foodSearchQueryProvider).trim();
    final highProteinOnly = ref.watch(highProteinFilterProvider);

    // Debounce by 250ms if query is not empty
    if (query.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (ref.read(foodSearchQueryProvider).trim() != query) {
        throw 'cancelled'; // Or return previous state
      }
    }

    final foodRepo = await ref.watch(foodRepositoryProvider.future);

    if (query.isEmpty) {
      // Return recent logs + some catalog items.
      // Since we can't modify LogRepository to do a GROUP BY, we fetch the last 7 days of logs.
      final logRepo = await ref.watch(logRepositoryProvider.future);
      final now = DateTime.now();
      final logsMap = await logRepo.forRange(
        now.subtract(const Duration(days: 7)),
        now,
      );

      final recentFoodIds = <String>{};
      // Flatten map into a list and sort by loggedAt descending
      final allRecentLogs = logsMap.values.expand((e) => e).toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

      for (final log in allRecentLogs) {
        if (log.foodId != null) {
          recentFoodIds.add(log.foodId!);
          if (recentFoodIds.length >= 5) break; // Keep top 5 recents
        }
      }

      final recentFoods = <FoodItem>[];
      for (final id in recentFoodIds) {
        final food = await foodRepo.byId(id);
        if (food != null) {
          recentFoods.add(food);
        }
      }

      // Fill the rest with catalog items (empty search)
      final catalog = await foodRepo.search('', limit: 30);
      for (final item in catalog) {
        if (!recentFoodIds.contains(item.id)) {
          recentFoods.add(item);
        }
      }

      return _applyProteinFilter(recentFoods, highProteinOnly);
    }

    // Normal search
    return _applyProteinFilter(await foodRepo.search(query), highProteinOnly);
  }

  /// Drops foods with no protein figure and sorts the rest by protein per
  /// portion, descending. A null value means "unknown", so those are excluded
  /// rather than sorted last — the filter promises protein data, and showing
  /// unknowns would break that promise.
  List<FoodItem> _applyProteinFilter(List<FoodItem> items, bool enabled) {
    if (!enabled) return items;
    final withProtein = items
        .where((f) => f.proteinPerPortionG != null)
        .toList();
    withProtein.sort(
      (a, b) => b.proteinPerPortionG!.compareTo(a.proteinPerPortionG!),
    );
    return withProtein;
  }
}
