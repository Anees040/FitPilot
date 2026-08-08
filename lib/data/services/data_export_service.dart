import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Builds a portable copy of everything the user has actually entered.
///
/// Deliberately excludes the bundled seed content (the food catalog, the
/// exercise library, the programme templates): those are shipped with the app,
/// identical for everyone, and would bury the user's own rows in tens of
/// thousands of lines. It also excludes sync_queue, which is transport
/// bookkeeping rather than data.
///
/// Offline by design — this reads the local database, which is the source of
/// truth, so an export works with no network and no account.
class DataExportService {
  final Database db;

  DataExportService(this.db);

  /// Tables holding user-authored rows, in a sensible reading order.
  ///
  /// `saved_products` is included because a barcode the user taught the app is
  /// their own work, and losing it would mean re-teaching every local product.
  static const userTables = <String>[
    'profile',
    'food_logs',
    'burn_completions',
    'weight_entries',
    'program_completions',
    'saved_products',
    'notification_prefs',
  ];

  /// The export as a JSON-ready map.
  ///
  /// A missing table is skipped rather than fatal: an export must never fail
  /// because of a schema difference between app versions.
  Future<Map<String, Object?>> build() async {
    final data = <String, Object?>{};
    var rowCount = 0;

    for (final table in userTables) {
      try {
        final rows = await db.query(table);
        data[table] = rows;
        rowCount += rows.length;
      } catch (_) {
        // Table absent on this schema version — leave it out.
      }
    }

    return {
      'app': 'FitPilot',
      'formatVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'rowCount': rowCount,
      'note':
          'Your own logs, weights and settings. The bundled food catalog and '
          'exercise library are not included — they ship with the app.',
      'data': data,
    };
  }

  /// Pretty-printed JSON, ready to save or share.
  Future<String> buildJson() async {
    return const JsonEncoder.withIndent('  ').convert(await build());
  }

  /// Writes the export next to the app's own files and returns the path.
  ///
  /// Returns null on web, where there is no filesystem to write to — callers
  /// fall back to the clipboard, which works everywhere.
  Future<String?> writeToFile() async {
    if (kIsWeb) return null;

    final json = await buildJson();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;

    // On Android the external app directory is reachable from a file manager,
    // which the internal one is not, so prefer it when available.
    Directory? dir;
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {
      dir = null;
    }
    dir ??= await getApplicationDocumentsDirectory();

    final file = File('${dir.path}/fitpilot-export-$stamp.json');
    await file.writeAsString(json);
    return file.path;
  }

  /// Row counts per table, for showing the user what they are about to export.
  Future<Map<String, int>> summary() async {
    final counts = <String, int>{};
    for (final table in userTables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
        counts[table] = (result.first['c'] as int?) ?? 0;
      } catch (_) {
        // Skip absent tables.
      }
    }
    return counts;
  }
}
