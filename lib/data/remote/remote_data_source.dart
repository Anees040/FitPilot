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

  Future<Map<String, DateTime>> fetchCloudUpdatedAts(String table, List<String> ids) async {
    if (_client == null || ids.isEmpty) return {};
    final res = await _client
        .from(table)
        .select('id, updated_at')
        .inFilter('id', ids);
    final map = <String, DateTime>{};
    for (final row in res) {
      if (row['id'] != null && row['updated_at'] != null) {
        map[row['id'].toString()] = DateTime.parse(row['updated_at'].toString());
      }
    }
    return map;
  }

  Future<bool> hasCloudProfile(String userId) async {
    if (_client == null) return false;
    final res = await _client.from('profiles').select('id').eq('id', userId).maybeSingle();
    return res != null;
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
      
      // Also check profile: if they have any profiles row, count it as cloud data
      final profile = await _client.from('profiles').select('id').maybeSingle();
      if (profile != null) {
        return true;
      }
    } catch (e) {
      // In case of error, err on the side of caution and assume data exists to trigger the dialog
      return true;
    }
    return false;
  }
}
