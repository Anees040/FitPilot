import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/local/seed_importer.dart';

void main() {
  late Database db;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> catalogCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM food_catalog'),
      ) ??
      0;

  test('imports both seed files and every row has a usable calorie range', () async {
    await SeedImporter(db).importAll();

    final rows = await db.query('food_catalog');
    expect(rows.length, greaterThan(150));

    for (final row in rows) {
      final name = row['name'] as String;
      final min = row['kcal_min'] as int;
      final max = row['kcal_max'] as int;
      expect(min, lessThanOrEqualTo(max), reason: '$name has min > max');
      expect(min, greaterThanOrEqualTo(0), reason: '$name has a negative min');
      expect(
        (row['portion_label'] as String?)?.isNotEmpty,
        isTrue,
        reason: '$name has no portion label',
      );
      // Diet Coke is the one legitimate zero — everything else must carry a
      // real cost, otherwise there is nothing to burn off.
      if (row['id'] != 'cheat-diet-cola') {
        expect(max, greaterThan(0), reason: '$name has no calories');
      }
    }
  });

  test('the cheat catalog covers the foods that trigger a burn plan', () async {
    await SeedImporter(db).importAll();

    Future<bool> hasNameLike(String fragment) async {
      final rows = await db.rawQuery(
        'SELECT 1 FROM food_catalog WHERE LOWER(name) LIKE ? LIMIT 1',
        ['%${fragment.toLowerCase()}%'],
      );
      return rows.isNotEmpty;
    }

    for (final fragment in [
      'lays',
      'kurkure',
      'coca-cola',
      'pepsi',
      'sting',
      'red bull',
      'kitkat',
      'oreo',
      'ice cream',
      'burger',
      'pizza',
      'biryani',
      'samosa chaat',
      'paratha roll',
    ]) {
      expect(await hasNameLike(fragment), isTrue, reason: 'missing: $fragment');
    }
  });

  test('re-running the import never duplicates rows', () async {
    await SeedImporter(db).importAll();
    final first = await catalogCount();

    await SeedImporter(db).importAll();
    await SeedImporter(db).importAll();

    expect(await catalogCount(), first);

    final duplicates = await db.rawQuery(
      'SELECT id, COUNT(*) c FROM food_catalog GROUP BY id HAVING c > 1',
    );
    expect(duplicates, isEmpty);
  });

  test('seeding stays out of the sync queue', () async {
    await SeedImporter(db).importAll();

    // Seed rows ship inside the app. Pushing them would upload ~190 identical
    // catalog rows per user on first sign-in.
    final queued = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_queue'),
    );
    expect(queued, 0);
  });

  test('imported foods carry the image key that renders their photo', () async {
    await SeedImporter(db).importAll();

    Future<Object?> imageKeyOf(String id) async {
      final rows = await db.query(
        'food_catalog',
        columns: ['image_key'],
        where: 'id = ?',
        whereArgs: [id],
      );
      return rows.isEmpty ? null : rows.first['image_key'];
    }

    expect(await imageKeyOf('biryani-chicken-1'), 'biryani');
    expect(await imageKeyOf('cheat-lays-masala-sm'), 'chips');
    expect(await imageKeyOf('cheat-coke-can'), 'cola');
    expect(await imageKeyOf('cheat-sting'), 'energy_drink');

    // The bulk of the catalog should actually resolve to art, not fall back
    // to a grey icon.
    final total = await catalogCount();
    final withArt =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM food_catalog WHERE image_key IS NOT NULL',
          ),
        ) ??
        0;
    expect(withArt / total, greaterThan(0.85));
  });

  test('a later, larger cheat file still reaches existing installs', () async {
    // Simulate an install that received an earlier, shorter version of the
    // file: the count guard must notice the shortfall and top it up.
    await SeedImporter(db).importAll();
    final full = await catalogCount();

    await db.delete(
      'food_catalog',
      where: 'id IN (?, ?)',
      whereArgs: ['cheat-sting', 'cheat-kitkat'],
    );
    expect(await catalogCount(), full - 2);

    await SeedImporter(db).importAll();
    expect(await catalogCount(), full);
  });
}
