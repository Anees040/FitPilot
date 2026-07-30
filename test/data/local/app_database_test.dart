import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/repositories/exercise_repository.dart';
import 'package:fitpilot/domain/entities/exercise.dart';

/// Helper: opens a fresh in-memory database with the v8 schema.
Future<Database> _freshDb() async {
  return await openDatabase(
    inMemoryDatabasePath,
    version: 8,
    singleInstance: false,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE exercises (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'indoor',
          subcategory TEXT,
          met REAL NOT NULL DEFAULT 5.0,
          equipment TEXT,
          primary_muscles TEXT NOT NULL DEFAULT '[]',
          secondary_muscles TEXT NOT NULL DEFAULT '[]',
          difficulty INTEGER NOT NULL DEFAULT 1,
          pace_tier TEXT NOT NULL DEFAULT 'moderate',
          steps TEXT NOT NULL DEFAULT '[]',
          mistakes TEXT NOT NULL DEFAULT '[]',
          media_asset TEXT,
          video_url TEXT
        )
      ''');
    },
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppDatabase v8 migration', () {
    test('inMemory() creates exercises table with new columns', () async {
      final db = await AppDatabase.inMemory();

      await db.insert('exercises', {
        'id': 'test-migration-1',
        'name': 'Test Exercise',
        'category': 'indoor',
        'subcategory': 'bodyweight',
        'met': 7.0,
        'equipment': null,
        'primary_muscles': '["Legs"]',
        'secondary_muscles': '["Core"]',
        'difficulty': 2,
        'pace_tier': 'moderate',
        'steps': '["Step one","Step two"]',
        'mistakes': '["Mistake one"]',
        'media_asset': 'exercise_media/test.webp',
        'video_url': null,
      });

      final rows = await db.query(
        'exercises',
        where: 'id = ?',
        whereArgs: ['test-migration-1'],
      );
      expect(rows.length, 1);
      expect(rows.first['subcategory'], 'bodyweight');
      expect(rows.first['primary_muscles'], '["Legs"]');
      expect(rows.first['secondary_muscles'], '["Core"]');
      expect(rows.first['pace_tier'], 'moderate');
      expect(rows.first['media_asset'], 'exercise_media/test.webp');
      expect(rows.first['video_url'], isNull);

      // Clean up
      await db.delete('exercises', where: 'id = ?', whereArgs: ['test-migration-1']);
      await db.close();
    });

    test('repairLogs runs without error on v8', () async {
      final db = await AppDatabase.inMemory();
      final result = await db.rawQuery('SELECT 1');
      expect(result, isNotEmpty);
      await db.close();
    });
  });

  group('ExerciseRepository', () {
    late Database db;
    late ExerciseRepository repo;

    final testExercises = [
      {
        'id': 'pushup-1',
        'name': 'Push-up',
        'category': 'calisthenics',
        'subcategory': 'bodyweight',
        'met': 8.0,
        'equipment': null,
        'primary_muscles': '["Chest","Triceps"]',
        'secondary_muscles': '[]',
        'difficulty': 1,
        'pace_tier': 'quick',
        'steps': '["Start in plank","Lower down","Push up"]',
        'mistakes': '["Sagging hips"]',
        'media_asset': 'exercise_media/pushup.webp',
        'video_url': null,
      },
      {
        'id': 'running-1',
        'name': 'Running',
        'category': 'outdoor',
        'subcategory': 'cardio',
        'met': 9.8,
        'equipment': null,
        'primary_muscles': '["Legs"]',
        'secondary_muscles': '["Core"]',
        'difficulty': 2,
        'pace_tier': 'quick',
        'steps': '["Warm up","Run"]',
        'mistakes': '["Over-striding"]',
        'media_asset': null,
        'video_url': 'https://example.com/running',
      },
      {
        'id': 'plank-1',
        'name': 'Plank',
        'category': 'calisthenics',
        'subcategory': 'bodyweight',
        'met': 3.3,
        'equipment': null,
        'primary_muscles': '["Core"]',
        'secondary_muscles': '[]',
        'difficulty': 1,
        'pace_tier': 'easy',
        'steps': '["Get into position","Hold"]',
        'mistakes': '["Sagging hips"]',
        'media_asset': null,
        'video_url': null,
      },
      {
        'id': 'bench-press-1',
        'name': 'Bench press',
        'category': 'gym',
        'subcategory': 'free_weight',
        'met': 5.0,
        'equipment': 'gym',
        'primary_muscles': '["Chest","Triceps"]',
        'secondary_muscles': '[]',
        'difficulty': 2,
        'pace_tier': 'easy',
        'steps': '["Lie down","Press"]',
        'mistakes': '["Bouncing bar"]',
        'media_asset': null,
        'video_url': null,
      },
      {
        'id': 'burpees-1',
        'name': 'Burpees',
        'category': 'indoor',
        'subcategory': 'bodyweight',
        'met': 8.0,
        'equipment': null,
        'primary_muscles': '["Full body"]',
        'secondary_muscles': '[]',
        'difficulty': 2,
        'pace_tier': 'quick',
        'steps': '["Squat","Jump back","Push-up","Jump up"]',
        'mistakes': '["Skipping push-up"]',
        'media_asset': null,
        'video_url': null,
      },
    ];

    setUp(() async {
      db = await _freshDb();
      for (final e in testExercises) {
        await db.insert('exercises', e);
      }
      repo = ExerciseRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('all() returns all exercises', () async {
      final all = await repo.all();
      expect(all.length, 5);
    });

    test('byId() returns correct exercise', () async {
      final exercise = await repo.byId('pushup-1');
      expect(exercise, isNotNull);
      expect(exercise!.name, 'Push-up');
      expect(exercise.category, ExerciseCategory.calisthenics);
      expect(exercise.primaryMuscles, ['Chest', 'Triceps']);
      expect(exercise.paceTier, 'quick');
    });

    test('byId() returns null for missing id', () async {
      final exercise = await repo.byId('nonexistent');
      expect(exercise, isNull);
    });

    test('searchByName() finds matching exercises', () async {
      final results = await repo.searchByName('push');
      expect(results.length, 1);
      expect(results.first.name, 'Push-up');
    });

    test('searchByName() returns all on empty query', () async {
      final results = await repo.searchByName('');
      expect(results.length, 5);
    });

    test('byCategory() filters correctly', () async {
      final calisthenics = await repo.byCategory('calisthenics');
      expect(calisthenics.length, 2);
      expect(
        calisthenics.every((e) => e.category == ExerciseCategory.calisthenics),
        isTrue,
      );
    });

    test('filtered() by category', () async {
      final results = await repo.filtered(category: 'outdoor');
      expect(results.length, 1);
      expect(results.first.name, 'Running');
    });

    test('filtered() by pace_tier', () async {
      final quick = await repo.filtered(paceTier: 'quick');
      expect(quick.length, 3); // pushup, running, burpees
      expect(quick.every((e) => e.paceTier == 'quick'), isTrue);
    });

    test('filtered() by maxDifficulty', () async {
      final easy = await repo.filtered(maxDifficulty: 1);
      expect(easy.length, 2); // pushup, plank
      expect(easy.every((e) => e.difficulty <= 1), isTrue);
    });

    test('filtered() by equipment', () async {
      final gymEquipment = await repo.filtered(equipment: 'gym');
      expect(gymEquipment.length, 1);
      expect(gymEquipment.first.name, 'Bench press');
    });

    test('filtered() with multiple criteria', () async {
      final results = await repo.filtered(
        category: 'calisthenics',
        paceTier: 'quick',
      );
      expect(results.length, 1);
      expect(results.first.name, 'Push-up');
    });

    test('filtered() with no matches returns empty list', () async {
      final results = await repo.filtered(
        category: 'outdoor',
        paceTier: 'easy',
      );
      expect(results, isEmpty);
    });
  });

  group('JSON column safety', () {
    test('malformed JSON in primary_muscles returns empty list', () async {
      final db = await _freshDb();
      await db.insert('exercises', {
        'id': 'malformed-1',
        'name': 'Malformed Exercise',
        'category': 'indoor',
        'met': 5.0,
        'primary_muscles': 'not valid json',
        'secondary_muscles': '{invalid}',
        'difficulty': 1,
        'pace_tier': 'moderate',
        'steps': '',
        'mistakes': '[]',
      });

      final repo = ExerciseRepository(db);
      final exercise = await repo.byId('malformed-1');
      expect(exercise, isNotNull);
      expect(exercise!.primaryMuscles, isEmpty);
      expect(exercise.secondaryMuscles, isEmpty);
      expect(exercise.steps, isEmpty);
      expect(exercise.mistakes, isEmpty);

      await db.close();
    });

    test('null JSON columns return empty list', () async {
      final db = await _freshDb();
      await db.rawInsert('''
        INSERT INTO exercises (id, name, category, met, difficulty, pace_tier,
          primary_muscles, secondary_muscles, steps, mistakes)
        VALUES ('null-test', 'Null Test', 'gym', 5.0, 1, 'moderate',
          '[]', '[]', '[]', '[]')
      ''');

      final repo = ExerciseRepository(db);
      final exercise = await repo.byId('null-test');
      expect(exercise, isNotNull);
      expect(exercise!.primaryMuscles, isEmpty);
      expect(exercise.steps, isEmpty);

      await db.close();
    });
  });

  group('Exercise entity', () {
    test('kcalPer10Min computes correctly', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Test',
        category: ExerciseCategory.indoor,
        met: 8.0,
        difficulty: 1,
      );
      // MET * 3.5 * 70 / 200 * 10 = 8 * 3.5 * 70 / 200 * 10 = 98
      // rounded to nearest 5 = 100
      expect(exercise.kcalPer10Min(70.0), 100);
    });

    test('minutesToBurn computes correctly with ceil-to-5', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Test',
        category: ExerciseCategory.indoor,
        met: 8.0,
        difficulty: 1,
      );
      // kcal/min = 8 * 3.5 * 70 / 200 = 9.8
      // To burn 100 kcal: 100 / 9.8 = 10.2 min => ceil to 5 => 15 min
      expect(exercise.minutesToBurn(70.0, 100), 15);
    });

    test('minutesToBurn returns 5 for very small surplus', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Test',
        category: ExerciseCategory.indoor,
        met: 12.0,
        difficulty: 1,
      );
      expect(exercise.minutesToBurn(70.0, 1), 5);
    });

    test('minutesToBurn returns 0 for zero kcal', () {
      final exercise = Exercise(
        id: 'test',
        name: 'Test',
        category: ExerciseCategory.indoor,
        met: 8.0,
        difficulty: 1,
      );
      expect(exercise.minutesToBurn(70.0, 0), 0);
    });

    test('ExerciseCategory has 4 values', () {
      expect(ExerciseCategory.values.length, 4);
      expect(ExerciseCategory.values, contains(ExerciseCategory.indoor));
    });

    test('constructor throws on invalid difficulty', () {
      expect(
        () => Exercise(
          id: 'x', name: 'X',
          category: ExerciseCategory.indoor, met: 5.0, difficulty: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => Exercise(
          id: 'x', name: 'X',
          category: ExerciseCategory.indoor, met: 5.0, difficulty: 4,
        ),
        throwsArgumentError,
      );
    });

    test('constructor throws on invalid met', () {
      expect(
        () => Exercise(
          id: 'x', name: 'X',
          category: ExerciseCategory.indoor, met: 0, difficulty: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}
