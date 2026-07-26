import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Weight Trend', style: AppTheme.title),
            TextButton(
              onPressed: () => _showAddWeightDialog(context, ref),
              child: const Text('+ Add Weight', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.entries.length < 2)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.hairline),
            ),
            child: Center(
              child: Text(
                'Log your weight at least twice to see your trend.',
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
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: _buildChart(),
                ),
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text('${days}d', style: AppTheme.caption.copyWith(color: isSelected ? AppTheme.surface : AppTheme.text)),
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

  Widget _buildChart() {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _days));
    final filtered = widget.entries.where((e) => e.date.isAfter(cutoff)).toList();

    if (filtered.isEmpty) {
      return Center(child: Text('No data in this period', style: AppTheme.body));
    }

    final spots = filtered.map((e) {
      return FlSpot(e.date.millisecondsSinceEpoch.toDouble(), e.weightKg);
    }).toList();

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
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
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
            child: Text('Cancel', style: AppTheme.body.copyWith(color: AppTheme.secondaryText)),
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
