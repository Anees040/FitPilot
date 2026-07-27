import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/features/log/presentation/widgets/kcal_range_text.dart';
import 'package:fitpilot/features/log/presentation/quantity_sheet.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:go_router/go_router.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(todayProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Today',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: stateAsync.when(
        data: (state) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _HeroSection(status: state.dayStatus)),
              if (state.dayStatus.state == DayState.over)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: InkWell(
                      onTap: () => context.go('/plan'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          border: Border.all(color: AppTheme.error),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You are over your limit',
                                    style: AppTheme.body.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                  Text(
                                    'Tap to view your burn plan',
                                    style: AppTheme.caption.copyWith(
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppTheme.error,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (state.logs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: 48,
                            color: AppTheme.secondaryText.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No logs today',
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(color: AppTheme.secondaryText),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the Log tab to add your first meal.',
                            style: AppTheme.lightTheme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final log = state.logs[index];
                    return _LogListItem(log: log);
                  }, childCount: state.logs.length),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.document_scanner),
        onPressed: () => context.push('/capture'),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final DayStatus status;

  const _HeroSection({required this.status});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status.state) {
      case DayState.under:
        statusColor = AppTheme.success;
        break;
      case DayState.near:
        statusColor = AppTheme.warning;
        break;
      case DayState.over:
        statusColor = AppTheme.error;
        break;
    }

    // A simple progress bar ratio
    final midpoint = status.net.midpoint;
    final ratio = (midpoint / status.allowanceKcal).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        children: [
          Text('Net Calories', style: AppTheme.lightTheme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          KcalRangeText(
            range: status.net,
            style: AppTheme.lightTheme.textTheme.displayLarge?.copyWith(
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Limit: ${status.allowanceKcal} kcal',
            style: AppTheme.lightTheme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppTheme.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogListItem extends ConsumerWidget {
  final FoodLog log;

  const _LogListItem({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(todayProvider.notifier).deleteLog(log.id);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Log deleted'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Re-add the log but without the deleted_at date
                ref
                    .read(todayProvider.notifier)
                    .addLog(log.copyWith(deletedAt: null));
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          if (log.source == LogSource.manual) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot edit manual entry quantity'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          // Show quantity sheet for catalog item
          // We need a dummy FoodItem to pass to the QuantitySheet
          final dummyFood = FoodItem(
            id: log.foodId ?? '',
            name: log.customName ?? 'Unknown',
            portionLabel: 'Portion',
            kcalPerPortion: log.kcal.times(
              1 / log.quantity.toDouble(),
            ), // Approximate single portion range
            isVerified: false,
          );

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppTheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) => QuantitySheet(food: dummyFood),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.displayName ?? 'Unknown',
                      style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${log.quantity}x • ${log.loggedAt.hour}:${log.loggedAt.minute.toString().padLeft(2, '0')}',
                      style: AppTheme.lightTheme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              KcalRangeText(range: log.kcal),
            ],
          ),
        ),
      ),
    );
  }
}
