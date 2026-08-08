import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/repositories/log_repository.dart';
import 'package:fitpilot/data/repositories/profile_repository.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/domain/entities/profile.dart';

FoodLog _log({required String id, double? proteinG}) => FoodLog(
  id: id,
  customName: 'Daal chawal',
  quantity: 1,
  kcal: KcalRange(400, 480),
  source: LogSource.manual,
  loggedAt: DateTime(2026, 8, 8, 13),
  proteinG: proteinG,
);

Profile _profile() => Profile(
  weightKg: 70,
  heightCm: 175,
  age: 25,
  gender: Gender.male,
  goal: Goal.maintain,
  activityLevel: ActivityLevel.light,
  allowanceKcal: 300,
  equipment: const [],
  updatedAt: DateTime(2026, 8, 8),
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> freshDb() async {
    final db = await AppDatabase.inMemory();
    await db.delete('food_logs');
    await db.delete('sync_queue');
    return db;
  }

  // Signed-in, so the guest shield does not suppress sync_queue writes.
  LogRepository logRepo(Database db) =>
      LogRepository(db, isGuest: () => false);

  group('food log protein', () {
    test('survives a write and read', () async {
      final repo = logRepo(await freshDb());
      await repo.add(_log(id: 'a', proteinG: 22.5));

      final rows = await repo.forDay(DateTime(2026, 8, 8));
      expect(rows.single.proteinG, 22.5);
    });

    test('an unknown protein value stays null rather than becoming zero', () async {
      // Zero would be a lie — it reads as "this food has no protein" when the
      // truth is "nobody told us". The Today row depends on that difference.
      final repo = logRepo(await freshDb());
      await repo.add(_log(id: 'b'));

      final rows = await repo.forDay(DateTime(2026, 8, 8));
      expect(rows.single.proteinG, isNull);
    });

    test('an update can add protein to a log that had none', () async {
      final repo = logRepo(await freshDb());
      await repo.add(_log(id: 'c'));
      await repo.update(_log(id: 'c', proteinG: 30));

      final rows = await repo.forDay(DateTime(2026, 8, 8));
      expect(rows.single.proteinG, 30);
    });
  });

  group('protein goal on the profile', () {
    test('round-trips through the database', () async {
      final db = await freshDb();
      final repo = ProfileRepository(db, isGuest: () => false);

      await repo.save(_profile().copyWith(proteinGoalG: 145));
      expect((await repo.get())?.proteinGoalG, 145);
    });

    test('can be cleared back to unset', () async {
      final db = await freshDb();
      final repo = ProfileRepository(db, isGuest: () => false);

      await repo.save(_profile().copyWith(proteinGoalG: 145));
      await repo.save(_profile().copyWith(clearProteinGoal: true));

      expect((await repo.get())?.proteinGoalG, isNull);
    });
  });

  group('local-only guarantee', () {
    test('protein_g never reaches the sync queue payload', () async {
      // The column does not exist in Supabase, so pushing it would fail the
      // whole sync. This guard keeps that from regressing.
      final db = await freshDb();
      await logRepo(db).add(_log(id: 'd', proteinG: 40));

      final queued = await db.query('sync_queue');
      expect(queued, isNotEmpty, reason: 'the log itself must still sync');
      for (final row in queued) {
        expect(
          row['payload']?.toString() ?? '',
          isNot(contains('protein_g')),
          reason: 'protein_g must not appear in a queued payload',
        );
      }
    });
  });
}
