import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteDataSource {
  final SupabaseClient? _client;

  RemoteDataSource(this._client);

  Future<void> upsertProfile(Map<String, dynamic> data) async {
    if (_client == null) return;
    await _client.from('profile').upsert(data);
  }

  Future<void> upsertRows(String table, List<Map<String, dynamic>> rows) async {
    if (_client == null || rows.isEmpty) return;
    await _client.from(table).upsert(rows);
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
}
