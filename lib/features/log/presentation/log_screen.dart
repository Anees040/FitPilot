import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/application/providers/food_search_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'widgets/food_result_tile.dart';
import 'quantity_sheet.dart';
import 'manual_entry_sheet.dart';

class LogScreen extends ConsumerWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchState = ref.watch(foodSearchProvider);
    final queryText = ref.watch(foodSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Log Food', style: theme.textTheme.h1),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: AppTextField(
                label: 'SEARCH FOODS',
                trailing: IconButton(
                  icon: Icon(Icons.document_scanner, color: theme.colorScheme.primary),
                  onPressed: () => context.push('/capture'),
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
                    return EmptyState(
                      message: queryText.isEmpty ? 'No recent foods.' : 'No results found for "$queryText".',
                      buttonLabel: "Add manually",
                      illustration: 'empty_search',
                      onAction: () {
                        AppBottomSheet.show(
                          context,
                          child: const ManualEntrySheet(),
                        );
                      },
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 220,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final food = results[index];
                            return FoodResultCard(
                              food: food,
                              onTap: () {
                                AppBottomSheet.show(
                                  context,
                                  child: QuantitySheet(food: food),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: TextButton(
                            onPressed: () {
                              AppBottomSheet.show(
                                context,
                                child: const ManualEntrySheet(),
                              );
                            },
                            child: Text(
                              "Can't find it? Add manually",
                              style: theme.textTheme.bodyStrong.copyWith(color: theme.colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SkeletonList(count: 6),
                ),
                error: (error, stack) => ErrorState(
                  reason: 'Error loading foods.\n$error',
                  onRetry: () => ref.invalidate(foodSearchProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
