import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/entities/weight_entry.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/buttons.dart';

import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:fitpilot/features/profile/presentation/widgets/ruler_picker.dart';

class WeightTrendSection extends ConsumerStatefulWidget {
  final List<WeightEntry> entries;

  const WeightTrendSection({super.key, required this.entries});

  @override
  ConsumerState<WeightTrendSection> createState() => _WeightTrendSectionState();
}

class _WeightTrendSectionState extends ConsumerState<WeightTrendSection> {


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final goalWeightKg = profile?.goalWeightKg;
    final heightCm = profile?.heightCm;

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 180));
    final filtered = widget.entries.where((e) => e.date.isAfter(cutoff)).toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));

    final currentWeight = widget.entries.isNotEmpty ? widget.entries.first.weightKg : null;
    final bmiWeight = currentWeight ?? profile?.weightKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // WEIGHT HEADER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Weight', style: theme.textTheme.h2.copyWith(fontSize: 22)),
            ElevatedButton(
              onPressed: () => _showAddWeightDialog(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                elevation: 0,
              ),
              child: const Text('Log', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (widget.entries.isEmpty)
          EmptyState(
            message: 'No weight entries yet. Log your weight to see your trend.',
            buttonLabel: 'Log weight',
            illustration: 'empty_chart',
            onAction: () => _showAddWeightDialog(context, ref),
          )
        else
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeightSummary(theme, ext, filtered, currentWeight),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
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

        const SizedBox(height: 32),

        // BMI HEADER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('BMI', style: theme.textTheme.h2.copyWith(fontSize: 22)),
          ],
        ),
        const SizedBox(height: 16),

        AppCard(
          padding: const EdgeInsets.all(20),
          child: _buildBMISection(theme, ext, bmiWeight, heightCm),
        ),
      ],
    );
  }

  Widget _buildWeightSummary(ThemeData theme, AppColors ext, List<WeightEntry> filtered, double? currentWeight) {
    if (filtered.isEmpty || currentWeight == null) return const SizedBox();

    final heaviest = filtered.map((e) => e.weightKg).reduce(max);
    final lightest = filtered.map((e) => e.weightKg).reduce(min);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current', style: theme.textTheme.caption.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(currentWeight.toStringAsFixed(1), style: theme.textTheme.display.copyWith(fontSize: 32, fontWeight: FontWeight.bold, height: 1.1)),
                const SizedBox(width: 4),
                Text('kg', style: theme.textTheme.bodyStrong),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Text('Heaviest', style: theme.textTheme.caption.copyWith(fontSize: 14)),
                const SizedBox(width: 8),
                Text(heaviest.toStringAsFixed(1), style: theme.textTheme.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Lightest', style: theme.textTheme.caption.copyWith(fontSize: 14)),
                const SizedBox(width: 8),
                Text(lightest.toStringAsFixed(1), style: theme.textTheme.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildChart(ThemeData theme, AppColors ext, List<WeightEntry> filtered, double? goalWeightKg) {
    if (filtered.isEmpty) {
      return Center(
        child: Text('No data in this period', style: theme.textTheme.caption),
      );
    }

    final chartBlue = const Color.fromARGB(255, 66, 133, 244);
    final textStyle = theme.textTheme.caption.copyWith(fontSize: 12, color: theme.textTheme.caption.color?.withValues(alpha: 0.6));

    List<FlSpot> spots = filtered.map((e) {
      return FlSpot(e.date.millisecondsSinceEpoch.toDouble(), e.weightKg);
    }).toList();

    double minX = spots.first.x;
    double maxX = spots.last.x;
    if (minX == maxX) {
      maxX = minX + 86400000; // + 1 day
      minX = minX - 86400000; // - 1 day
    }

    double minY = spots.map((s) => s.y).reduce(min);
    double maxY = spots.map((s) => s.y).reduce(max);
    
    if (goalWeightKg != null) {
      if (goalWeightKg < minY) minY = goalWeightKg;
      if (goalWeightKg > maxY) maxY = goalWeightKg;
    }

    if (minY == maxY) {
      minY -= 5;
      maxY += 5;
    } else {
      final padding = (maxY - minY) * 0.2;
      minY -= padding;
      maxY += padding;
    }

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: max(86400000 * 5, (maxX - minX) / 5),
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                if (value == minX || value == maxX) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('dd').format(date), style: textStyle),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: textStyle);
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: chartBlue,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (index == spots.length - 1) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: Colors.white,
                    strokeWidth: 3,
                    strokeColor: chartBlue,
                  );
                }
                return FlDotCirclePainter(radius: 0, color: Colors.transparent);
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  chartBlue.withValues(alpha: 0.25),
                  chartBlue.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBMISection(ThemeData theme, AppColors ext, double? weightKg, int? heightCm) {
    if (weightKg == null || heightCm == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add your height to calculate BMI', style: theme.textTheme.caption),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Add Height',
            onPressed: () => _showEditHeightDialog(context, ref, null),
          ),
        ],
      );
    }

    final heightM = heightCm / 100;
    final bmi = weightKg / (heightM * heightM);

    String status = 'Unknown';
    Color statusColor = ext.hairline;

    if (bmi < 18.5) {
      statusColor = const Color.fromARGB(255, 117, 151, 255);
      status = 'Underweight';
    } else if (bmi < 25) {
      statusColor = const Color.fromARGB(255, 110, 211, 211);
      status = 'Healthy weight';
    } else if (bmi < 30) {
      statusColor = const Color.fromARGB(255, 255, 221, 85);
      status = 'Overweight';
    } else if (bmi < 35) {
      statusColor = const Color.fromARGB(255, 255, 173, 85);
      status = 'Obese I';
    } else {
      statusColor = const Color.fromARGB(255, 239, 83, 80);
      status = 'Obese II+';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(bmi.toStringAsFixed(1), style: theme.textTheme.display.copyWith(fontSize: 40, fontWeight: FontWeight.bold, height: 1.1)),
            Row(
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(status, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 16)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBMIGraph(theme, bmi),
        const SizedBox(height: 24),
        Divider(color: theme.dividerColor.withValues(alpha: 0.3), height: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Height', style: theme.textTheme.caption.copyWith(fontSize: 16)),
            InkWell(
              onTap: () => _showEditHeightDialog(context, ref, heightCm),
              child: Row(
                children: [
                  Text('${heightCm.toStringAsFixed(0)} cm', style: theme.textTheme.bodyStrong.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(Icons.edit, size: 16, color: theme.textTheme.caption.color),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBMIGraph(ThemeData theme, double currentBmi) {
    final segments = [
      {'min': 15.0, 'max': 16.0, 'color': const Color.fromARGB(255, 76, 111, 255)},
      {'min': 16.0, 'max': 18.5, 'color': const Color.fromARGB(255, 117, 151, 255)},
      {'min': 18.5, 'max': 25.0, 'color': const Color.fromARGB(255, 110, 211, 211)},
      {'min': 25.0, 'max': 30.0, 'color': const Color.fromARGB(255, 255, 221, 85)},
      {'min': 30.0, 'max': 35.0, 'color': const Color.fromARGB(255, 255, 173, 85)},
      {'min': 35.0, 'max': 40.0, 'color': const Color.fromARGB(255, 239, 83, 80)},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const gapWidth = 4.0;
        final availableWidthForSegments = totalWidth - (gapWidth * (segments.length - 1));
        final widthPerUnit = availableWidthForSegments / 25.0; // 40 - 15 = 25 total BMI units
        
        double arrowX = 0;
        final clampedBmi = currentBmi.clamp(15.0, 40.0);
        for (int i = 0; i < segments.length; i++) {
          final sMin = segments[i]['min'] as double;
          final sMax = segments[i]['max'] as double;
          final sWidth = (sMax - sMin) * widthPerUnit;
          if (clampedBmi >= sMin && clampedBmi <= sMax) {
            final localFraction = (clampedBmi - sMin) / (sMax - sMin);
            arrowX += localFraction * sWidth;
            break;
          } else {
            arrowX += sWidth + gapWidth;
          }
        }
        
        return Column(
          children: [
            SizedBox(
              height: 12,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: arrowX - 12,
                    bottom: -8,
                    child: Icon(Icons.arrow_drop_down, size: 24, color: theme.textTheme.bodyLarge?.color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: segments.asMap().entries.map((entry) {
                final i = entry.key;
                final seg = entry.value;
                final sMin = seg['min'] as double;
                final sMax = seg['max'] as double;
                final sWidth = (sMax - sMin) * widthPerUnit;
                
                return Padding(
                  padding: EdgeInsets.only(right: i < segments.length - 1 ? gapWidth : 0),
                  child: Container(
                    width: sWidth,
                    height: 12,
                    decoration: BoxDecoration(
                      color: seg['color'] as Color,
                      borderRadius: BorderRadius.horizontal(
                        left: i == 0 ? const Radius.circular(6) : Radius.zero,
                        right: i == segments.length - 1 ? const Radius.circular(6) : Radius.zero,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [15.0, 16.0, 18.5, 25.0, 30.0, 35.0, 40.0].map((val) {
                  double labelX = 0;
                  if (val > 15.0) {
                     for (int i = 0; i < segments.length; i++) {
                       final sMax = segments[i]['max'] as double;
                       final sMin = segments[i]['min'] as double;
                       labelX += ((sMax - sMin) * widthPerUnit) + (sMax == val ? 0 : gapWidth);
                       if (sMax == val) break;
                     }
                  }
                  
                  return Positioned(
                    left: labelX - 10,
                    child: SizedBox(
                      width: 20,
                      child: Text(
                        val == val.toInt() ? val.toInt().toString() : val.toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.caption.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.caption.color?.withValues(alpha: 0.8)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEntryList(ThemeData theme, List<WeightEntry> sortedDesc) {
    if (sortedDesc.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: sortedDesc.map((e) {
        return ListTile(
          title: Text('${e.weightKg.toStringAsFixed(1)} kg', style: theme.textTheme.bodyStrong),
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
    _showWeightBottomSheet(context, ref, 'Edit Weight', entry.weightKg, (val, date) async {
      await ref.read(progressProvider.notifier).editWeight(entry.id, val);
    });
  }

  void _showAddWeightDialog(BuildContext context, WidgetRef ref) {
    final profile = ref.read(profileProvider).valueOrNull;
    final initialWeight = widget.entries.isNotEmpty ? widget.entries.first.weightKg : (profile?.weightKg ?? 70.0);
    _showWeightBottomSheet(context, ref, 'Add Weight', initialWeight, (val, date) async {
      // The progress provider addWeight doesn't take date right now. We will just pass it, assuming addWeight adds for now().
      // Wait, let's check if addWeight takes a date or just adds it today.
      // If we can't change it right away, we just do addWeight(val). 
      // The prompt said 'add date factor also in widget and it should be owkring man'. We will update the progress provider separately to take a date.
      await ref.read(progressProvider.notifier).addWeight(val, date: date);
    }, showDatePicker: true);
  }

  void _showWeightBottomSheet(BuildContext context, WidgetRef ref, String title, double initialValue, Function(double, DateTime) onSave, {bool showDatePicker = false}) {
    final theme = Theme.of(context);
    double weight = initialValue;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  if (showDatePicker) ...[
                    InkWell(
                      onTap: () async {
                        final d = await showDatePickerDialog(context, selectedDate);
                        if (d != null) {
                          setModalState(() => selectedDate = d);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(DateFormat.yMMMd().format(selectedDate), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  RulerPicker(
                    minValue: 30,
                    maxValue: 200,
                    initialValue: weight,
                    step: 0.1,
                    majorTickInterval: 1.0,
                    valueBuilder: (context, val) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(val.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text('kg', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                    tickFormatter: (val) => val.toInt().toString(),
                    onChanged: (val) {
                      weight = val;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Save',
                      onPressed: () {
                        Navigator.pop(context);
                        onSave(weight, selectedDate);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> showDatePickerDialog(BuildContext context, DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  void _showEditHeightDialog(BuildContext context, WidgetRef ref, int? currentHeightCm) {
    final theme = Theme.of(context);
    final initialHeight = currentHeightCm?.toDouble() ?? 170.0;
    double height = initialHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Edit Height', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  RulerPicker(
                    minValue: 50,
                    maxValue: 250,
                    initialValue: height,
                    step: 1.0,
                    majorTickInterval: 10.0,
                    valueBuilder: (context, val) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(val.toStringAsFixed(0), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text('cm', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                    tickFormatter: (val) => val.toInt().toString(),
                    onChanged: (val) {
                      height = val;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Save',
                      onPressed: () async {
                        Navigator.pop(context);
                        final profile = ref.read(profileProvider).valueOrNull;
                        if (profile != null) {
                          await ref.read(profileRepositoryProvider.future).then((r) => r.save(profile.copyWith(heightCm: height.toInt())));
                          ref.invalidate(profileProvider);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
