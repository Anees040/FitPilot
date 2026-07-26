import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/domain/engines/range_calculator.dart';
import 'package:fitpilot/domain/engines/streak_engine.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ProgressState {
  final Map<DateTime, DayStatus> last35Days;
  final StreakState streak;
  final KcalRange weeklyIntake;
  final int weeklyBurned;
  final double adherencePercent;
  final List<WeightEntry> weightEntries;

  const ProgressState({
    required this.last35Days,
    required this.streak,
    required this.weeklyIntake,
    required this.weeklyBurned,
    required this.adherencePercent,
    required this.weightEntries,
  });
}

class WeightEntry {
  final DateTime date;
  final double weightKg;

  const WeightEntry(this.date, this.weightKg);
}

final progressProvider = AsyncNotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);

class ProgressNotifier extends AsyncNotifier<ProgressState> {
  @override
  Future<ProgressState> build() async {
    final now = DateTime.now();
    final profile = await ref.watch(profileProvider.future);
    final logRepo = await ref.watch(logRepositoryProvider.future);
    final burnRepo = await ref.watch(burnRepositoryProvider.future);
    
    // We need weight entries from the database, let's assume we have a way or query it directly
    final db = await ref.watch(databaseProvider.future);
    final weightRows = await db.query('weight_entries', orderBy: 'for_date ASC');
    final weightEntries = weightRows.map((r) {
      return WeightEntry(
        DateTime.parse(r['for_date'] as String),
        (r['weight_kg'] as num).toDouble(),
      );
    }).toList();

    const calculator = RangeCalculator();
    final history = <DateTime, DayStatus>{};
    
    // 35 days for heatmap
    for (int i = 0; i < 35; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final logs = await logRepo.forDay(date);
      final burns = await burnRepo.burnedKcalForDay(date);
      final status = calculator.dayStatus(
        logs: logs,
        burnedKcal: burns,
        allowanceKcal: profile.effectiveDailyLimit,
      );
      history[date] = status;
    }

    const streakEngine = StreakEngine();
    final streak = streakEngine.evaluate(dayHistory: history, now: now);

    // Weekly summary (last 7 days)
    var weeklyIntake = KcalRange(0, 0);
    var weeklyBurned = 0;
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final status = history[date]!;
      weeklyIntake = weeklyIntake.plus(status.total);
      weeklyBurned += status.burnedKcal;
    }

    return ProgressState(
      last35Days: history,
      streak: streak,
      weeklyIntake: weeklyIntake,
      weeklyBurned: weeklyBurned,
      adherencePercent: 0, // Adherence is 0 until planner exists in Milestone C
      weightEntries: weightEntries,
    );
  }

  Future<void> addWeight(double weightKg) async {
    final db = await ref.read(databaseProvider.future);
    final now = DateTime.now();
    final forDateStr = DateTime(now.year, now.month, now.day).toIso8601String();
    
    await db.insert('weight_entries', {
      'id': const Uuid().v4(),
      'for_date': forDateStr,
      'weight_kg': weightKg,
      'updated_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace); // Upsert requires a UNIQUE constraint on for_date, which we have

    ref.invalidateSelf();
    // Invalidate profile because weight might affect burn minutes
    // Actually profile is separate, let's keep it separate or maybe update profile weight? 
    // The prompt says "changing weight in the profile changes burn minutes" which means the main source of truth is Profile. 
    // So if the user adds weight here, we should update the Profile too!
    // So if the user adds weight here, we should update the Profile too!
    final currentProfile = await ref.read(profileProvider.future);
    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.save(currentProfile.copyWith(weightKg: weightKg));
    ref.invalidate(profileProvider);
  }
}
