import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/core/utils/type_readers.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
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
      orderBy: 'for_date ASC, updated_at DESC',
    );

    final Map<String, Map<String, Object?>> uniqueWeights = {};
    for (final r in weightRows) {
      final date = r['for_date'] as String;
      if (!uniqueWeights.containsKey(date)) {
        uniqueWeights[date] = r;
      } else {
        await db.delete('weight_entries', where: 'id = ?', whereArgs: [r['id']]);
      }
    }

    final weightEntries = uniqueWeights.values.map((r) {
      return WeightEntry(
        id: r['id'] as String,
        date: DateTime.parse(r['for_date'] as String),
        weightKg: TolerantReader.readDouble(r['weight_kg']) ?? 0.0,
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );
    }).toList();
    weightEntries.sort((a, b) => a.date.compareTo(b.date));

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

    final existing = await db.query('weight_entries', where: 'for_date = ?', whereArgs: [forDateStr]);
    final String id;
    
    if (existing.isNotEmpty) {
      id = existing.first['id'] as String;
      await db.update('weight_entries', {
        'weight_kg': weightKg,
        'updated_at': now.toIso8601String(),
      }, where: 'id = ?', whereArgs: [id]);
    } else {
      id = const Uuid().v4();
      await db.insert('weight_entries', {
        'id': id,
        'for_date': forDateStr,
        'weight_kg': weightKg,
        'updated_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    if (ref.read(currentUserProvider) != null) {
      await db.insert('sync_queue', {
        'table_name': 'weight_entries',
        'row_id': id,
        'op': 'upsert',
        'payload': null,
        'queued_at': now.toIso8601String(),
      });
    }

    final currentProfile = await ref.read(profileProvider.future);
    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.save(currentProfile.copyWith(weightKg: weightKg));
    ref.invalidate(profileProvider);

    ref.read(syncTriggerManagerProvider)?.onLocalWrite();
    ref.invalidateSelf();
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

    if (ref.read(currentUserProvider) != null) {
      await db.insert('sync_queue', {
        'table_name': 'weight_entries',
        'row_id': id,
        'op': 'upsert',
        'payload': null,
        'queued_at': now.toIso8601String(),
      });
    }

    final currentProfile = await ref.read(profileProvider.future);
    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.save(currentProfile.copyWith(weightKg: newWeight));
    ref.invalidate(profileProvider);

    ref.read(syncTriggerManagerProvider)?.onLocalWrite();
    ref.invalidateSelf();
  }

  Future<void> deleteWeight(String id) async {
    final db = await ref.read(databaseProvider.future);
    final now = DateTime.now();

    await db.delete(
      'weight_entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (ref.read(currentUserProvider) != null) {
      await db.insert('sync_queue', {
        'table_name': 'weight_entries',
        'row_id': id,
        'op': 'delete',
        'payload': null,
        'queued_at': now.toIso8601String(),
      });
    }

    ref.read(syncTriggerManagerProvider)?.onLocalWrite();
    ref.invalidateSelf();
  }
}
