import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/food_search_provider.dart';
import 'widgets/food_result_tile.dart';
import 'quantity_sheet.dart';
import 'manual_entry_sheet.dart';

class LogScreen extends ConsumerWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(foodSearchProvider);
    final queryText = ref.watch(foodSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search foods...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.secondaryText,
                  ),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (val) {
                  ref.read(foodSearchQueryProvider.notifier).state = val;
                },
              ),
            ),
            Expanded(
              child: searchState.when(
                data: (results) {
                  if (results.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: AppTheme.secondaryText.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              queryText.isEmpty
                                  ? 'No recent foods'
                                  : 'No results found',
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(color: AppTheme.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: results.length + 1,
                    separatorBuilder: (context, index) {
                      if (index == results.length) {
                        return const SizedBox.shrink();
                      }
                      return const Divider(
                        height: 1,
                        color: AppTheme.hairline,
                        indent: 16,
                        endIndent: 16,
                      );
                    },
                    itemBuilder: (context, index) {
                      if (index == results.length) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: AppTheme.surface,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  builder: (context) =>
                                      const ManualEntrySheet(),
                                );
                              },
                              child: Text(
                                "Can't find it? Add manually",
                                style: AppTheme.lightTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        );
                      }

                      final food = results[index];
                      return FoodResultTile(
                        food: food,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: AppTheme.surface,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (context) => QuantitySheet(food: food),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Error loading foods',
                      style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
