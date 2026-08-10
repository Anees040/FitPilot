import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:fitpilot/data/sync/sync_tables.dart';

/// Adopts data created while signed out into the account that just signed in.
///
/// It works by queueing every local row for upload rather than uploading them
/// itself. That matters: the previous version hand-rolled its own upserts for
/// four tables, which meant it (a) never carried program progress, notification
/// settings, coach threads, scanner history or saved barcodes, and (b) sent raw
/// SQLite values — 0/1 where Postgres wanted booleans, plus columns like
/// `protein_goal_g` that do not exist in the cloud — so PostgREST rejected the
/// whole profile row and the user's height and preferences never left the
/// device. Queueing instead reuses SyncService's push, which already knows the
/// column mapping and the conflict rule.
class GuestMergeService {
  final Database _db;

  GuestMergeService(this._db);

  /// Queues every local row for upload under [userId].
  ///
  /// Rows are queued, not pushed. The caller runs a sync afterwards, and the
  /// push resolves each row against the cloud by `updated_at` — so a guest row
  /// the user just created wins over an older cloud row, and a stale guest row
  /// loses. That is the behaviour people expect from "keep my data", and it is
  /// the same rule every other write already follows.
  Future<void> mergeGuestData(String userId) async {
    var queued = 0;
    for (final spec in kSyncTables) {
      try {
        final rows = await _db.query(spec.local, columns: [spec.localPk]);
        for (final row in rows) {
          final rowId = row[spec.localPk]?.toString();
          if (rowId == null) continue;
          await _db.insert('sync_queue', {
            'table_name': spec.local,
            'row_id': rowId,
            'op': 'upsert',
            'payload': null,
            'queued_at': DateTime.now().toUtc().toIso8601String(),
          });
          queued++;
        }
      } catch (e) {
        // One missing table (an install part-way through a migration) must not
        // abandon the rest of the user's data.
        debugPrint('Guest merge skipped ${spec.local}: $e');
      }
    }
    debugPrint('Guest merge queued $queued rows for $userId');
  }

  /// Whether the device holds anything worth asking the user about.
  ///
  /// Checks every synced table, not just food logs and weights. A user who had
  /// only started a program and set their reminders still has data to lose, and
  /// the old version would have silently discarded it.
  Future<bool> hasGuestData() async {
    for (final spec in kSyncTables) {
      // The profile row always exists — clearUserData recreates a blank one —
      // so its presence proves nothing. Onboarding having been completed does.
      if (spec.local == 'profile') {
        try {
          final rows = await _db.query(
            'profile',
            where: 'onboarding_complete = 1 OR weight_kg IS NOT NULL',
            limit: 1,
          );
          if (rows.isNotEmpty) return true;
        } catch (_) {}
        continue;
      }
      // Likewise the seeded food catalog: only foods the user added count.
      if (spec.local == 'food_catalog') {
        try {
          final rows = await _db.query(
            'food_catalog',
            where: 'is_verified = 0',
            limit: 1,
          );
          if (rows.isNotEmpty) return true;
        } catch (_) {}
        continue;
      }
      try {
        final rows = await _db.query(spec.local, limit: 1);
        if (rows.isNotEmpty) return true;
      } catch (_) {}
    }
    return false;
  }
}
