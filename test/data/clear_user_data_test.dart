import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';

/// Tables holding something personal that must not survive a sign-out.
///
/// The local-only ones matter most: they never reach Supabase, so nothing else
/// in the app would ever clear them. Before this was fixed, signing out left
/// one account's coach conversations, machine scans and notifications on screen
/// for whoever signed in next on the same phone.
const _mustBeEmptied = [
  'food_logs',
  'weight_entries',
  'burn_completions',
  'sync_queue',
  'chat_messages',
  'chat_conversations',
  'machine_scans',
  'notifications',
  'program_completions',
  'saved_products',
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('sign-out leaves no personal data behind', () async {
    final db = await AppDatabase.inMemory();
    final now = DateTime.now().toIso8601String();

    // Seed one row into every table that should be wiped.
    await db.insert('food_logs', {
      'id': 'log-1',
      'food_name': 'Biryani',
      'quantity': 1.0,
      'kcal_min': 400,
      'kcal_max': 500,
      'source': 'search',
      'logged_at': now,
      'updated_at': now,
    });
    await db.insert('weight_entries', {
      'id': 'w-1',
      'for_date': '2026-08-09',
      'weight_kg': 70.0,
      'updated_at': now,
    });
    await db.insert('burn_completions', {
      'id': 'b-1',
      'for_date': '2026-08-09',
      'activity': 'Walking',
      'minutes': 30,
      'kcal': 150,
      'completed_at': now,
      'updated_at': now,
    });
    await db.insert('sync_queue', {
      'table_name': 'food_logs',
      'row_id': 'log-1',
      'op': 'insert',
      'payload': '{}',
      'queued_at': now,
    });
    await db.insert('chat_conversations', {
      'id': 'c-1',
      'title': 'My cutting plan',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('chat_messages', {
      'id': 'm-1',
      'conversation_id': 'c-1',
      'role': 'user',
      'content': 'a private question about my body',
      'created_at': now,
    });
    await db.insert('machine_scans', {
      'id': 's-1',
      'machine_name': 'Lat Pulldown',
      'response_json': '{}',
      'created_at': now,
    });
    await db.insert('notifications', {
      'id': 'n-1',
      'category': 'mealReminder',
      'title': 'Log your lunch',
      'body': 'text',
      'created_at': now,
    });
    await db.insert('program_completions', {
      'session_id': 'pc-1',
      'program_id': 'p-1',
      'week_number': 1,
      'day_number': 1,
      'completed_at': now,
    });
    await db.insert('saved_products', {
      'barcode': '123',
      'quantity': 40.0,
      'updated_at': now,
    });

    // Every table genuinely had a row, so an empty result below means the
    // wipe worked rather than that nothing was ever there.
    for (final table in _mustBeEmptied) {
      expect(
        await db.query(table),
        isNotEmpty,
        reason: '$table was not seeded — the assertion below would be vacuous',
      );
    }

    await AppDatabase.clearUserData(db);

    for (final table in _mustBeEmptied) {
      expect(
        await db.query(table),
        isEmpty,
        reason: '$table still holds data after sign-out',
      );
    }
  });

  test('the profile is reset to a usable guest state, not deleted', () async {
    final db = await AppDatabase.inMemory();

    await db.update('profile', {
      'name': 'Muhammad Anees',
      'avatar_url': 'https://lh3.googleusercontent.com/a/abc',
      'weight_kg': 82.0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = 1');

    await AppDatabase.clearUserData(db);

    final rows = await db.query('profile');
    expect(rows, hasLength(1), reason: 'the app needs a profile row to exist');
    expect(rows.single['name'], isNull, reason: "the previous user's name must go");
    expect(rows.single['avatar_url'], isNull, reason: 'their photo must go too');
  });

  test('the exercise library survives — it is seed content, not user data', () async {
    final db = await AppDatabase.inMemory();
    await db.insert('exercises', {
      'id': 'walk',
      'name': 'Walking',
      'category': 'outdoor',
      'met': 3.5,
    });

    await AppDatabase.clearUserData(db);

    expect(
      await db.query('exercises'),
      isNotEmpty,
      reason: 'wiping the seed would leave the app empty after a sign-out',
    );
  });
}
