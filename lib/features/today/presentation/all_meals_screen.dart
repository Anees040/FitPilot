import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/features/log/presentation/widgets/kcal_range_text.dart';
import 'package:fitpilot/features/today/presentation/widgets/log_list_item.dart';

/// Every meal logged today, in one scrollable list.
///
/// Reached from the "View all" affordance on Today once the day has more
/// meals than the three the summary shows.
class AllMealsScreen extends ConsumerWidget {
  const AllMealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final todayState = ref.watch(todayProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final weightKg = profile?.weightKg ?? 70.0;

    return Scaffold(
      appBar: AppBar(
        title: Text("Today's meals", style: theme.textTheme.h1),
        centerTitle: false,
      ),
      body: SafeArea(
        child: todayState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ErrorState(
            reason: 'Could not load your meals.\n$err',
            onRetry: () => ref.invalidate(todayProvider),
          ),
          data: (state) {
            if (state.logs.isEmpty) {
              return EmptyState(
                message: 'No meals logged today.',
                buttonLabel: 'Log food',
                illustration: 'empty_plate',
                onAction: () => context.go('/log'),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                AppCard(
                  variant: AppCardVariant.raised,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EATEN TODAY', style: theme.textTheme.overline),
                          const SizedBox(height: 6),
                          KcalRangeText(
                            range: state.dayStatus.total,
                            style: theme.textTheme.h2.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('MEALS', style: theme.textTheme.overline),
                          const SizedBox(height: 6),
                          Text(
                            '${state.logs.length}',
                            style: theme.textTheme.h2.copyWith(
                              color: ext.energy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (final log in state.logs) ...[
                  LogListItem(log: log, weightKg: weightKg),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
