import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/features/log/presentation/widgets/kcal_range_text.dart';
import 'package:fitpilot/features/log/presentation/quantity_sheet.dart';
import 'package:fitpilot/domain/entities/food_item.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:intl/intl.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final stateAsync = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Today', style: theme.textTheme.h1),
        centerTitle: false,
      ),
      body: stateAsync.when(
        data: (state) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverToBoxAdapter(
                  child: _HeroSection(status: state.dayStatus),
                ),
              ),
              if (state.dayStatus.toBurn > 0)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  sliver: SliverToBoxAdapter(
                    child: AppCard(
                      color: ext.error.withValues(alpha: 0.1),
                      onTap: () => context.go('/plan'),
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department, color: ext.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You have a debt to burn',
                                  style: theme.textTheme.bodyStrong.copyWith(color: ext.error),
                                ),
                                Text(
                                  'Tap to view burn plan',
                                  style: theme.textTheme.caption.copyWith(color: ext.error),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: ext.error),
                        ],
                      ),
                    ),
                  ),
                ),
              if (state.logs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    message: 'No logs yet today. Tap the Capture button to add your first meal.',
                    buttonLabel: 'Add meal manually',
                    illustration: 'empty_plate',
                    onAction: () => context.go('/log'),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text('LOGGED TODAY', style: theme.textTheme.overline),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _LogListItem(log: state.logs[index]),
                    childCount: state.logs.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16.0),
          child: SkeletonList(count: 3),
        ),
        error: (error, stack) => ErrorState(
          reason: 'Failed to load today\'s data.\n$error',
          onRetry: () => ref.invalidate(todayProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.qr_code_scanner),
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
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    if (status.state == DayState.cleared) {
      return AppCard(
        color: ext.success.withValues(alpha: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department, size: 48, color: ext.success),
            const SizedBox(height: 16),
            Text(
              'All burned off 🔥',
              style: theme.textTheme.h1.copyWith(color: ext.success),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve cleared today\'s debt. Great job!',
              style: theme.textTheme.bodyMedium?.copyWith(color: ext.success),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildSecondaryStats(context),
          ],
        ),
      );
    }

    Color statusColor = status.toBurn > 0 ? ext.error : theme.textTheme.caption.color!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TO BURN', style: theme.textTheme.overline),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${status.toBurn}',
                  style: theme.textTheme.display.copyWith(color: statusColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  'kcal',
                  style: theme.textTheme.bodyStrong.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSecondaryStats(context),
        ],
      ),
    );
  }

  Widget _buildSecondaryStats(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EATEN', style: theme.textTheme.overline),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: KcalRangeText(
                  range: status.total,
                  style: theme.textTheme.bodyStrong,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('BURNED', style: theme.textTheme.overline),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${status.burnedKcal} kcal',
                  style: theme.textTheme.bodyStrong.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogListItem extends ConsumerWidget {
  final FoodLog log;

  const _LogListItem({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: ext.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        child: Icon(Icons.delete, color: theme.colorScheme.onPrimary),
      ),
      onDismissed: (_) {
        ref.read(todayProvider.notifier).deleteLog(log.id);
        AppSnackbar.success(
          context,
          'Meal deleted',
          actionLabel: 'UNDO',
          onAction: () {
            ref.read(todayProvider.notifier).addLog(log.copyWith(deletedAt: null));
          },
        );
      },
      child: InkWell(
        onTap: () {
          if (log.source == LogSource.manual) {
            AppSnackbar.success(context, 'Cannot edit manual entry quantity.');
            return;
          }

          final dummyFood = FoodItem(
            id: log.foodId ?? '',
            name: log.displayName ?? 'Unknown',
            portionLabel: 'Portion',
            kcalPerPortion: log.kcal.times(1 / log.quantity.toDouble()),
            isVerified: false,
          );

          AppBottomSheet.show(
            context,
            child: QuantitySheet(food: dummyFood),
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
                      style: theme.textTheme.bodyStrong,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${log.quantity.toInt() == log.quantity ? log.quantity.toInt() : log.quantity} × portion • ${DateFormat.jm().format(log.loggedAt)}',
                      style: theme.textTheme.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              KcalRangeText(
                range: log.kcal,
                style: theme.textTheme.bodyStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
