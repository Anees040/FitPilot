import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/domain/engines/range_calculator.dart';
import 'package:fitpilot/domain/engines/streak_engine.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';
import 'package:fitpilot/domain/entities/weight_entry.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ProgressState {
  final Map<DateTime, DayStatus> last35Days;
  final StreakState streak;
  final KcalRange weeklyIntake;
  final int weeklyBurned;
  final List<WeightEntry> weightEntries;

  const ProgressState({
    required this.last35Days,
    required this.streak,
    required this.weeklyIntake,
    required this.weeklyBurned,
    required this.weightEntries,
  });
}


final progressProvider = AsyncNotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);

class ProgressNotifier extends AsyncNotifier<ProgressState> {
  @override
  Future<ProgressState> build() async {
    final now = DateTime.now();
    final profile = await ref.watch(profileProvider.future);
    
    // Watch todayProvider so that progress chart updates when food is logged today
    // We watch the async value to ensure rebuilds happen when state changes
    ref.watch(todayProvider);

    final logRepo = await ref.watch(logRepositoryProvider.future);
    final burnRepo = await ref.watch(burnRepositoryProvider.future);

    // We need weight entries from the database, let's assume we have a way or query it directly
    final db = await ref.watch(databaseProvider.future);
    final weightRows = await db.query(
      'weight_entries',
      orderBy: 'for_date ASC',
    );
    final weightEntries = weightRows.map((r) {
      return WeightEntry(
        id: r['id'] as String,
        date: DateTime.parse(r['for_date'] as String),
        weightKg: (r['weight_kg'] as num?)?.toDouble() ?? 0.0,
        updatedAt: DateTime.parse(r['updated_at'] as String),
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
        wiggleRoomKcal: profile.allowanceKcal,
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
      weightEntries: weightEntries,
    );
  }

  Future<void> addWeight(double weightKg, {DateTime? date}) async {
    final db = await ref.read(databaseProvider.future);
    final now = DateTime.now();
    final effectiveDate = date ?? now;
    final forDateStr = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day).toIso8601String();

    final id = const Uuid().v4();
    await db.insert('weight_entries', {
      'id': id,
      'for_date': forDateStr,
      'weight_kg': weightKg,
      'updated_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('sync_queue', {
      'table_name': 'weight_entries',
      'row_id': id,
      'op': 'upsert',
      'payload': null,
      'queued_at': now.toIso8601String(),
    }); // Upsert requires a UNIQUE constraint on for_date, which we have

    ref.invalidateSelf();
    ref.read(syncTriggerManagerProvider)?.onLocalWrite();
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

  Future<void> editWeight(String id, double newWeight) async {
    final db = await ref.read(databaseProvider.future);
    final now = DateTime.now();

    await db.update(
      'weight_entries',
      {'weight_kg': newWeight, 'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    await db.insert('sync_queue', {
      'table_name': 'weight_entries',
      'row_id': id,
      'op': 'upsert',
      'payload': null,
      'queued_at': now.toIso8601String(),
    });

    ref.invalidateSelf();
    ref.read(syncTriggerManagerProvider)?.onLocalWrite();
    
    // Also update profile weight if it was the most recent entry? 
    // We can just keep it simple and update profile weight to the new weight.
    final currentProfile = await ref.read(profileProvider.future);
    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.save(currentProfile.copyWith(weightKg: newWeight));
    ref.invalidate(profileProvider);
  }

  Future<void> deleteWeight(String id) async {
    final db = await ref.read(databaseProvider.future);
    final now = DateTime.now();

    await db.delete(
      'weight_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    await db.insert('sync_queue', {
      'table_name': 'weight_entries',
      'row_id': id,
      'op': 'delete',
      'payload': null,
      'queued_at': now.toIso8601String(),
    });

    ref.invalidateSelf();
    ref.read(syncTriggerManagerProvider)?.onLocalWrite();
  }
}
