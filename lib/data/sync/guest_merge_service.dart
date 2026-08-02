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
        final profile = Map<String, dynamic>.from(profiles.first);
        profile.remove('id');
        profile.remove('active_program_id');
        profile.remove('active_program_week');
        profile.remove('active_program_day');
        profile['id'] = userId;
        await _remote.upsertRows('profiles', [profile]);
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
        await _remote.upsertRows('weight_entries', mapped);
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

      debugPrint('Guest data successfully merged to cloud for user $userId');
    } catch (e) {
      debugPrint('Failed to merge guest data: $e');
    }
  }
}
