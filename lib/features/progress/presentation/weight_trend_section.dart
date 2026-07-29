import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/entities/weight_entry.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:intl/intl.dart';

class WeightTrendSection extends ConsumerStatefulWidget {
  final List<WeightEntry> entries;

  const WeightTrendSection({super.key, required this.entries});

  @override
  ConsumerState<WeightTrendSection> createState() => _WeightTrendSectionState();
}

class _WeightTrendSectionState extends ConsumerState<WeightTrendSection> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final profileAsync = ref.watch(profileProvider);
    final goalWeightKg = profileAsync.valueOrNull?.goalWeightKg;

    final now = DateTime.now();
    final cutoff = _days == 365 ? now.subtract(const Duration(days: 3650)) : now.subtract(Duration(days: _days));
    final filtered = widget.entries.where((e) => e.date.isAfter(cutoff)).toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('WEIGHT TREND', style: theme.textTheme.overline),
            TertiaryButton(
              label: '+ Add',
              onPressed: () => _showAddWeightDialog(context, ref),
              color: theme.colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.entries.isEmpty)
          EmptyState(
            message: 'No weight entries yet. Log your weight to see your trend.',
            buttonLabel: 'Log weight',
            illustration: 'empty_chart',
            onAction: () => _showAddWeightDialog(context, ref),
          )
        else
          AppCard(
            child: Column(
              children: [
                _buildFilterChips(theme, ext),
                const SizedBox(height: 16),
                _buildSummaryText(theme, filtered),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: _buildChart(theme, ext, filtered, goalWeightKg),
                ),
              ],
            ),
          ),
        if (widget.entries.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: _buildEntryList(theme, filtered.reversed.toList()),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChips(ThemeData theme, AppColors ext) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [30, 90, 365].map((days) {
        final isSelected = _days == days;
        final label = days == 365 ? 'All' : '${days}d';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(
              label,
              style: theme.textTheme.bodyStrong.copyWith(
                color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.caption.color,
              ),
            ),
            selected: isSelected,
            selectedColor: theme.colorScheme.primary,
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: isSelected ? theme.colorScheme.primary : ext.hairline,
              ),
            ),
            showCheckmark: false,
            onSelected: (selected) {
              if (selected) setState(() => _days = days);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryText(ThemeData theme, List<WeightEntry> filtered) {
    if (filtered.length < 2) {
      return Text(
        'Not enough data in this period',
        style: theme.textTheme.caption,
      );
    }
    final first = filtered.first.weightKg;
    final last = filtered.last.weightKg;
    final diff = last - first;
    final label = _days == 365 ? 'overall' : 'in $_days days';

    if (diff == 0) {
      return Text('No change $label', style: theme.textTheme.bodyStrong);
    } else if (diff < 0) {
      return Text('Down ${diff.abs().toStringAsFixed(1)} kg $label', style: theme.textTheme.bodyStrong);
    } else {
      return Text('Up ${diff.abs().toStringAsFixed(1)} kg $label', style: theme.textTheme.bodyStrong);
    }
  }

  Widget _buildChart(ThemeData theme, AppColors ext, List<WeightEntry> filtered, double? goalWeightKg) {
    if (filtered.isEmpty) {
      return Center(
        child: Text('No data in this period', style: theme.textTheme.caption),
      );
    }

    List<FlSpot> spots = filtered.map((e) {
      return FlSpot(e.date.millisecondsSinceEpoch.toDouble(), e.weightKg);
    }).toList();

    if (spots.length == 1) {
      spots.add(FlSpot(spots.first.x + 1, spots.first.y));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: goalWeightKg != null
              ? [
                  HorizontalLine(
                    y: goalWeightKg,
                    color: ext.warning.withValues(alpha: 0.5),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 5, bottom: 5),
                      style: theme.textTheme.caption.copyWith(color: ext.warning),
                      labelResolver: (line) => 'Goal',
                    ),
                  )
                ]
              : [],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: theme.colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(ThemeData theme, List<WeightEntry> sortedDesc) {
    if (sortedDesc.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: sortedDesc.map((e) {
        return ListTile(
          title: Text('${e.weightKg} kg', style: theme.textTheme.bodyStrong),
          subtitle: Text(DateFormat.yMMMd().format(e.date), style: theme.textTheme.caption),
          trailing: IconButton(
            icon: Icon(Icons.more_horiz, color: theme.textTheme.caption.color),
            onPressed: () => _showEditOptions(context, e),
          ),
        );
      }).toList(),
    );
  }

  void _showEditOptions(BuildContext context, WeightEntry entry) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    
    AppBottomSheet.show(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit, color: theme.colorScheme.primary),
            title: Text('Edit Weight', style: theme.textTheme.bodyStrong),
            onTap: () {
              Navigator.pop(context);
              _showEditWeightDialog(context, ref, entry);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: ext.error),
            title: Text('Delete', style: theme.textTheme.bodyStrong.copyWith(color: ext.error)),
            onTap: () {
              Navigator.pop(context);
              ref.read(progressProvider.notifier).deleteWeight(entry.id);
            },
          ),
        ],
      ),
    );
  }

  void _showEditWeightDialog(BuildContext context, WidgetRef ref, WeightEntry entry) {
    final controller = TextEditingController(text: entry.weightKg.toString());
    _showWeightDialog(context, ref, 'Edit Weight', controller, () {
      final val = double.tryParse(controller.text);
      if (val != null && val >= 25 && val <= 300) {
        ref.read(progressProvider.notifier).editWeight(entry.id, val);
        Navigator.pop(context);
      }
    });
  }

  void _showAddWeightDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    _showWeightDialog(context, ref, 'Add Weight', controller, () {
      final val = double.tryParse(controller.text);
      if (val != null && val >= 25 && val <= 300) {
        ref.read(progressProvider.notifier).addWeight(val);
        Navigator.pop(context);
      }
    });
  }

  void _showWeightDialog(BuildContext context, WidgetRef ref, String title, TextEditingController controller, VoidCallback onSave) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(title, style: theme.textTheme.h2),
        content: AppTextField(
          label: 'WEIGHT (KG)',
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TertiaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
            color: theme.textTheme.caption.color,
          ),
          TertiaryButton(
            label: 'Save',
            onPressed: onSave,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
