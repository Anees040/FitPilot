import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/core/utils/food_image_resolver.dart';
import 'package:fitpilot/core/utils/type_readers.dart';

/// Loads seed data from bundled JSON assets into the database.
///
/// Idempotent: only inserts when the target table is empty.
class SeedImporter {
  final Database db;

  /// Every id in `foods_cheat.json` carries this prefix, so the importer can
  /// tell how many of that file's rows are already present without needing a
  /// version table.
  static const _cheatIdPrefix = 'cheat-';

  const SeedImporter(this.db);

  Future<void> importAll() async {
    int foods = await _importFoods();
    int cheats = await _importCheatFoods();
    int exercises = await _importExercises();
    int programs = await _importPrograms();
    await _backfillFoodProtein();
    debugPrint(
      '[Seed] foods=$foods (cheat=$cheats) '
      'exercises=$exercises programs=$programs',
    );
  }

  Future<int> _importFoods() async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM food_catalog'),
    );
    if (count != null && count > 0) return count;

    final jsonStr = await rootBundle.loadString('assets/seed/foods.json');
    final List<dynamic> foods = json.decode(jsonStr) as List<dynamic>;

    final batch = db.batch();
    for (final food in foods) {
      final f = food as Map<String, dynamic>;
      final name = f['name'] as String;
      batch.insert('food_catalog', {
        'id': f['id'] as String,
        'name': name,
        'name_ur': f['name_ur'] as String?,
        'portion_label': f['portion_label'] as String,
        'grams': TolerantReader.readInt(f['grams']),
        'kcal_min': TolerantReader.readInt(f['kcal_min']) ?? 0,
        'kcal_max': TolerantReader.readInt(f['kcal_max']) ?? 0,
        'image_key': resolveImageKey(name),
        'protein_g': TolerantReader.readDouble(f['protein_g']),
        'is_verified': 1,
      });
    }
    await batch.commit(noResult: true);

    final finalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM food_catalog'),
    );
    return finalCount ?? 0;
  }

  /// Imports the high-regret catalog — packaged snacks, cold drinks, fast food
  /// and desi cheat meals — the foods a gym-goer actually wants a burn plan for.
  ///
  /// Runs on existing installs too, unlike [_importFoods], which stops as soon
  /// as the catalog is non-empty. The guard compares how many `cheat-` rows are
  /// present against the asset, so adding items to the file later ships them to
  /// users who already have the earlier ones. Inserts use `ignore` and stable
  /// ids, so a re-run never duplicates and never overwrites a user's edits.
  ///
  /// Writes through a raw batch, which deliberately bypasses `sync_queue`:
  /// seed rows are bundled with the app and must not be pushed to Supabase.
  /// Fills in protein for seeded foods that predate the protein columns.
  ///
  /// [_importFoods] returns early once the catalog has rows, so an existing
  /// install would otherwise keep NULL protein for every food forever. This
  /// runs on each launch but does nothing once the values are in place: the
  /// guard query is a single indexed COUNT.
  ///
  /// Only rows still missing a value are touched, so a figure the user edited
  /// is never overwritten.
  Future<void> _backfillFoodProtein() async {
    final pending = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM food_catalog WHERE protein_g IS NULL',
      ),
    );
    if (pending == null || pending == 0) return;

    final jsonStr = await rootBundle.loadString('assets/seed/foods.json');
    final foods = json.decode(jsonStr) as List<dynamic>;

    final batch = db.batch();
    var updated = 0;
    for (final food in foods) {
      final f = food as Map<String, dynamic>;
      final protein = TolerantReader.readDouble(f['protein_g']);
      if (protein == null) continue;
      batch.update(
        'food_catalog',
        {'protein_g': protein},
        where: 'id = ? AND protein_g IS NULL',
        whereArgs: [f['id']],
      );
      updated++;
    }
    if (updated == 0) return;
    await batch.commit(noResult: true);
    debugPrint('[Seed] backfilled protein for up to $updated foods');
  }

  Future<int> _importCheatFoods() async {
    final jsonStr = await rootBundle.loadString('assets/seed/foods_cheat.json');
    final List<dynamic> foods = json.decode(jsonStr) as List<dynamic>;

    final present =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM food_catalog WHERE id LIKE ?',
            ['$_cheatIdPrefix%'],
          ),
        ) ??
        0;
    if (present >= foods.length) return present;

    final batch = db.batch();
    for (final food in foods) {
      final f = food as Map<String, dynamic>;
      final name = f['name'] as String;
      batch.insert(
        'food_catalog',
        {
          'id': f['id'] as String,
          'name': name,
          'name_ur': f['name_ur'] as String?,
          'portion_label': f['portion_label'] as String,
          'grams': TolerantReader.readInt(f['grams']),
          'kcal_min': TolerantReader.readInt(f['kcal_min']) ?? 0,
          'kcal_max': TolerantReader.readInt(f['kcal_max']) ?? 0,
          'image_key': resolveImageKey(name),
          'protein_g': TolerantReader.readDouble(f['protein_g']),
          'is_verified': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM food_catalog WHERE id LIKE ?',
            ['$_cheatIdPrefix%'],
          ),
        ) ??
        0;
  }

  Future<int> _importExercises() async {
    final jsonStr = await rootBundle.loadString('assets/seed/exercises.json');
    final List<dynamic> exercises = json.decode(jsonStr) as List<dynamic>;

    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM exercises'),
        ) ??
        0;
    // Compare against the asset rather than a fixed floor, so exercises added
    // to the file later reach installs that already have the earlier ones.
    // Rows are replaced by stable id, so a re-run never duplicates.
    if (count >= exercises.length) return count;

    final batch = db.batch();
    for (final ex in exercises) {
      final e = ex as Map<String, dynamic>;
      batch.insert(
        'exercises',
        {
          'id': e['id'] as String,
          'name': e['name'] as String,
          'category': e['category'] as String,
          'subcategory': e['subcategory'] as String?,
          'met': TolerantReader.readDouble(e['met']) ?? 5.0,
          'equipment': (e['equipment'] as String?) ?? '',
          'primary_muscles': json.encode(e['primary_muscles'] ?? []),
          'secondary_muscles': json.encode(e['secondary_muscles'] ?? []),
          'difficulty': TolerantReader.readInt(e['difficulty']) ?? 1,
          'pace_tier': e['pace_tier'] as String,
          'steps': json.encode(e['steps'] ?? []),
          'mistakes': json.encode(e['mistakes'] ?? []),
          'media_asset': e['media_asset'] as String?,
          'video_url': e['video_url'] as String?,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    try {
      await batch.commit(noResult: true);
    } catch (e) {
      // Ignore duplicate or constraint conflicts during seed import
    }
    
    final finalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM exercises'),
    );
    return finalCount ?? 0;
  }

  /// Imports the training-program catalog.
  ///
  /// The guard is deliberately split:
  ///
  /// * **Program metadata is upserted on every run.** Installs that seeded
  ///   programs before v20 have rows with default level/focus/duration, and a
  ///   program with no focus would land in an "unknown" bucket in the browse
  ///   filter. Replacing the row every launch also lets copy fixes ship.
  /// * **Sessions and their exercise items are only written when that program
  ///   has none**, so the loop never churns rows the user is midway through.
  ///
  /// Day numbers are assigned **across the whole program** (1..durationDays,
  /// rest days included) rather than restarting each week, so `day_number`
  /// doubles as "Day 12 of 30" and advancing is a plain +1.
  ///
  /// Accepts both session shapes: the legacy `{day_number, exercise_id,
  /// minutes}` and the richer `{title, kind, notes, exercises:[…]}`.
  ///
  /// Writes through a raw batch, which deliberately bypasses `sync_queue`:
  /// program tables are local-only and must not be pushed to Supabase.
  Future<int> _importPrograms() async {
    final jsonStr = await rootBundle.loadString('assets/seed/programs.json');
    final List<dynamic> programs = json.decode(jsonStr) as List<dynamic>;

    final seededSessions = await db.rawQuery(
      'SELECT program_id, COUNT(*) AS c FROM program_sessions GROUP BY program_id',
    );
    final sessionCounts = <String, int>{
      for (final row in seededSessions)
        row['program_id'] as String: TolerantReader.readInt(row['c']) ?? 0,
    };

    final batch = db.batch();
    for (final p in programs) {
      final prog = p as Map<String, dynamic>;
      final programId = prog['id'] as String;
      final days = _flattenDays(prog);

      batch.insert('programs', {
        'id': programId,
        'name': prog['name'] as String,
        'icon': prog['icon'] as String,
        'goal': prog['goal'] as String,
        'level': (prog['level'] as String?) ?? 'beginner',
        'focus': (prog['focus'] as String?) ?? 'full_body',
        'equipment': (prog['equipment'] as String?) ?? 'none',
        'duration_days':
            TolerantReader.readInt(prog['duration_days']) ?? days.length,
        'days_per_week': TolerantReader.readInt(prog['days_per_week']) ?? 0,
        'hero_image': prog['hero_image'] as String?,
        'sort_index': TolerantReader.readInt(prog['sort_index']) ?? 100,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if ((sessionCounts[programId] ?? 0) > 0) continue;

      for (final day in days) {
        batch.insert('program_sessions', day.sessionRow);
        for (final item in day.itemRows) {
          batch.insert('program_session_items', item);
        }
      }
    }
    await batch.commit(noResult: true);

    final finalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM programs'),
    );
    return finalCount ?? 0;
  }

  /// Walks a program's weeks and returns one [_SeedDay] per plan day, numbering
  /// them 1..N across the whole program.
  List<_SeedDay> _flattenDays(Map<String, dynamic> prog) {
    final programId = prog['id'] as String;
    final weeks = (prog['weeks'] as List<dynamic>?) ?? const [];
    final days = <_SeedDay>[];
    var dayNumber = 0;

    for (final w in weeks) {
      final week = w as Map<String, dynamic>;
      final weekNumber = TolerantReader.readInt(week['week_number']) ?? 1;
      final sessions = (week['sessions'] as List<dynamic>?) ?? const [];

      for (final s in sessions) {
        final session = s as Map<String, dynamic>;
        dayNumber++;
        final sessionId = '$programId-w$weekNumber-d$dayNumber';
        final kind = (session['kind'] as String?) ?? 'workout';
        final isRest = kind == 'rest';

        final rawItems = session['exercises'] as List<dynamic>?;
        final items = <Map<String, Object?>>[];
        var totalMinutes = 0;

        if (!isRest) {
          if (rawItems != null) {
            for (var i = 0; i < rawItems.length; i++) {
              final item = rawItems[i] as Map<String, dynamic>;
              final minutes = TolerantReader.readInt(item['minutes']) ?? 10;
              totalMinutes += minutes;
              items.add({
                'id': '$sessionId-i${i + 1}',
                'session_id': sessionId,
                'position': i + 1,
                'exercise_id': item['exercise_id'] as String,
                'minutes': minutes,
                'detail': item['detail'] as String?,
              });
            }
          } else {
            // Legacy shape: a single exercise on the session itself.
            final minutes = TolerantReader.readInt(session['minutes']) ?? 10;
            totalMinutes = minutes;
            items.add({
              'id': '$sessionId-i1',
              'session_id': sessionId,
              'position': 1,
              'exercise_id': session['exercise_id'] as String,
              'minutes': minutes,
              'detail': null,
            });
          }
        }

        days.add(
          _SeedDay(
            sessionRow: {
              'id': sessionId,
              'program_id': programId,
              'week_number': weekNumber,
              'day_number': dayNumber,
              // Rest days have no exercise; the sentinel keeps the NOT NULL
              // column honest and is skipped by the seed-integrity test.
              'exercise_id': items.isEmpty
                  ? 'rest'
                  : items.first['exercise_id'] as String,
              'minutes': totalMinutes,
              'title': (session['title'] as String?) ??
                  (isRest ? 'Rest day' : 'Day $dayNumber'),
              'focus': session['focus'] as String?,
              'kind': kind,
              'notes': session['notes'] as String?,
            },
            itemRows: items,
          ),
        );
      }
    }
    return days;
  }
}

/// One plan day ready to insert: the session row plus its ordered exercises.
class _SeedDay {
  final Map<String, Object?> sessionRow;
  final List<Map<String, Object?>> itemRows;

  const _SeedDay({required this.sessionRow, required this.itemRows});
}
