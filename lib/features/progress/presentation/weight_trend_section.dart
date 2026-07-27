import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/entities/weight_entry.dart';
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
    final profileAsync = ref.watch(profileProvider);
    final goalWeightKg = profileAsync.valueOrNull?.goalWeightKg;

    final now = DateTime.now();
    final cutoff = _days == 365 ? now.subtract(const Duration(days: 3650)) : now.subtract(Duration(days: _days));
    final filtered = widget.entries.where((e) => e.date.isAfter(cutoff)).toList();
    // Sort oldest to newest
    filtered.sort((a, b) => a.date.compareTo(b.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Weight Trend', style: AppTheme.title),
            TextButton(
              onPressed: () => _showAddWeightDialog(context, ref),
              child: const Text(
                '+ Add Weight',
                style: TextStyle(color: AppTheme.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: Center(
              child: Text(
                'Log your weight to see your trend.',
                style: AppTheme.body,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: Column(
              children: [
                _buildFilterChips(),
                const SizedBox(height: 16),
                _buildSummaryText(filtered),
                const SizedBox(height: 16),
                SizedBox(height: 200, child: _buildChart(filtered, goalWeightKg)),
                const SizedBox(height: 16),
                _buildEntryList(filtered.reversed.toList()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChips() {
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
              style: AppTheme.caption.copyWith(
                color: isSelected ? AppTheme.surface : AppTheme.text,
              ),
            ),
            selected: isSelected,
            selectedColor: AppTheme.accent,
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: AppTheme.hairline),
            ),
            onSelected: (selected) {
              if (selected) setState(() => _days = days);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryText(List<WeightEntry> filtered) {
    if (filtered.length < 2) {
      return Text(
        'Not enough data in this period',
        style: AppTheme.body.copyWith(color: AppTheme.secondaryText),
      );
    }
    final first = filtered.first.weightKg;
    final last = filtered.last.weightKg;
    final diff = last - first;
    final label = _days == 365 ? 'overall' : 'in $_days days';

    if (diff == 0) {
      return Text('No change $label', style: AppTheme.body);
    } else if (diff < 0) {
      return Text('Down ${diff.abs().toStringAsFixed(1)} kg $label', style: AppTheme.body);
    } else {
      return Text('Up ${diff.abs().toStringAsFixed(1)} kg $label', style: AppTheme.body);
    }
  }

  Widget _buildChart(List<WeightEntry> filtered, double? goalWeightKg) {
    if (filtered.isEmpty) {
      return Center(
        child: Text('No data in this period', style: AppTheme.body),
      );
    }

    // fl_chart requires at least 2 spots to draw a line. If only 1 entry, 
    // we duplicate it to render a horizontal line, or just show a dot.
    List<FlSpot> spots = filtered.map((e) {
      return FlSpot(e.date.millisecondsSinceEpoch.toDouble(), e.weightKg);
    }).toList();

    if (spots.length == 1) {
      // Add a dummy spot 1 ms later so the chart doesn't crash on single points
      spots.add(FlSpot(spots.first.x + 1, spots.first.y));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
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
                    color: AppTheme.warning.withAlpha(127),
                    strokeWidth: 2,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 5, bottom: 5),
                      style: AppTheme.caption.copyWith(color: AppTheme.warning),
                      labelResolver: (line) => 'Goal',
                    ),
                  )
                ]
              : [],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false, // gaps between months look better with straight lines or simple curves
            color: AppTheme.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(List<WeightEntry> sortedDesc) {
    if (sortedDesc.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: sortedDesc.map((e) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${e.weightKg} kg', style: AppTheme.body.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text(DateFormat.yMMMd().format(e.date), style: AppTheme.caption),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showEditOptions(context, e),
          ),
        );
      }).toList(),
    );
  }

  void _showEditOptions(BuildContext context, WeightEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: AppTheme.accent),
                title: Text('Edit Weight', style: AppTheme.body),
                onTap: () {
                  Navigator.pop(context);
                  _showEditWeightDialog(context, ref, entry);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: AppTheme.error),
                title: Text('Delete', style: AppTheme.body),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(progressProvider.notifier).deleteWeight(entry.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditWeightDialog(BuildContext context, WidgetRef ref, WeightEntry entry) {
    final controller = TextEditingController(text: entry.weightKg.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Edit Weight (kg)', style: AppTheme.title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.hairline),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.body.copyWith(color: AppTheme.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 25 && val <= 300) {
                ref.read(progressProvider.notifier).editWeight(entry.id, val);
                Navigator.pop(context);
              }
            },
            child: Text('Save', style: AppTheme.body),
          ),
        ],
      ),
    );
  }

  void _showAddWeightDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Add Weight (kg)', style: AppTheme.title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'e.g. 70.5',
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.hairline),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.body.copyWith(color: AppTheme.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 25 && val <= 300) {
                ref.read(progressProvider.notifier).addWeight(val);
                Navigator.pop(context);
              }
            },
            child: Text('Save', style: AppTheme.body),
          ),
        ],
      ),
    );
  }
}

