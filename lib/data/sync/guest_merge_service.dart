import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/data/remote/remote_data_source.dart';

class GuestMergeService {
  final Database _db;
  final RemoteDataSource _remote;

  GuestMergeService(this._db, this._remote);

  Future<void> mergeGuestData(String userId) async {
    try {
      final profiles = await _db.query('profile');
      if (profiles.isNotEmpty) {
        // STEP 2: Do not clobber existing cloud profile
        final hasCloudProfile = await _remote.hasCloudProfile(userId);
        
        if (!hasCloudProfile) {
          final profile = Map<String, dynamic>.from(profiles.first);
          profile.remove('id');
          profile.remove('onboarding_complete');
          profile['id'] = userId;
          // Convert equipment JSON string → Dart List for Postgres text[] column
          _fixProfileArrayFields(profile);
          await _remote.upsertRows('profiles', [profile]);
        } else {
          debugPrint('Cloud profile exists for $userId, skipping guest profile merge.');
        }
      }

      final logs = await _db.query('food_logs');
      if (logs.isNotEmpty) {
        final List<Map<String, dynamic>> mapped = logs.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['user_id'] = userId;
          return map;
        }).toList();
        await _remote.upsertRows('food_logs', mapped);
      }

      final weights = await _db.query('weight_entries');
      if (weights.isNotEmpty) {
        final List<Map<String, dynamic>> mapped = weights.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['user_id'] = userId;
          return map;
        }).toList();
        await _remote.upsertRows('weight_entries', mapped, onConflict: 'user_id, for_date');
      }

      final burns = await _db.query('burn_completions');
      if (burns.isNotEmpty) {
        final List<Map<String, dynamic>> mapped = burns.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['user_id'] = userId;
          return map;
        }).toList();
        await _remote.upsertRows('burn_completions', mapped);
      }

      final programCompletions = await _db.query('program_completions');
      if (programCompletions.isNotEmpty) {
        final List<Map<String, dynamic>> mapped = programCompletions.map((e) {
          final map = Map<String, dynamic>.from(e);
          map['user_id'] = userId;
          return map;
        }).toList();
        await _remote.upsertRows('program_completions', mapped);
      }

      debugPrint('Guest data successfully merged to cloud for user $userId');
    } catch (e) {
      debugPrint('Failed to merge guest data: $e');
      rethrow;
    }
  }

  /// Checks if the local database contains significant guest data
  Future<bool> hasGuestData() async {
    try {
      final logs = await _db.query('food_logs', limit: 1);
      if (logs.isNotEmpty) return true;
      final weights = await _db.query('weight_entries', limit: 1);
      if (weights.isNotEmpty) return true;
      final burns = await _db.query('burn_completions', limit: 1);
      if (burns.isNotEmpty) return true;
      final programCompletions = await _db.query('program_completions', limit: 1);
      if (programCompletions.isNotEmpty) return true;
    } catch (_) {}
    return false;
  }

  /// Converts JSON-encoded array fields (stored as text in SQLite) to Dart
  /// lists of strings so Supabase can insert them into PostgreSQL `text[]` columns.
  void _fixProfileArrayFields(Map<String, dynamic> data) {
    const arrayFields = ['equipment'];
    for (final field in arrayFields) {
      final raw = data[field];
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            data[field] = decoded.cast<String>();
          } else {
            data[field] = <String>[];
          }
        } catch (_) {
          data[field] = <String>[];
        }
      } else if (raw == null) {
        data[field] = <String>[];
      }
    }
  }
}
