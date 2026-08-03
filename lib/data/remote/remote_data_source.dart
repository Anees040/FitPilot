import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteDataSource {
  final SupabaseClient? _client;

  RemoteDataSource(this._client);

  Future<void> upsertProfile(Map<String, dynamic> data) async {
    if (_client == null) return;
    await _client.from('profiles').upsert(data);
  }

  Future<void> upsertRows(String table, List<Map<String, dynamic>> rows, {String? onConflict}) async {
    if (_client == null || rows.isEmpty) return;
    await _client.from(table).upsert(rows, onConflict: onConflict);
  }

  Future<List<Map<String, dynamic>>> pullSince(
    String table,
    String sinceIso8601,
  ) async {
    if (_client == null) return [];
    final res = await _client
        .from(table)
        .select()
        .gt('updated_at', sinceIso8601);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Checks if the cloud account has meaningful data by querying tables.
  Future<bool> hasCloudData(String userId) async {
    if (_client == null) return false;
    try {
      final List<String> tablesToCheck = ['food_logs', 'weight_entries', 'burn_completions'];
      for (final table in tablesToCheck) {
        final res = await _client.from(table).select('id').limit(1);
        if (res.isNotEmpty) return true;
      }
      
      // Also check profile if they ever entered weight or changed allowance
      final profile = await _client.from('profiles').select('weight_kg, allowance_kcal').maybeSingle();
      if (profile != null) {
        if (profile['weight_kg'] != null || profile['allowance_kcal'] != 300) {
          return true;
        }
      }
    } catch (e) {
      // In case of error, err on the side of caution and assume data exists to trigger the dialog
      return true;
    }
    return false;
  }
}
