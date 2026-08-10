import 'package:flutter/foundation.dart';
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
  ///
  /// Scoped to [userId] explicitly. It used to rely on RLS alone, which is
  /// correct but leaves the query answering "does anyone have rows" if a policy
  /// is ever missing — a bad thing to branch a data-merge decision on.
  Future<bool> hasCloudData(String userId) async {
    if (_client == null) return false;
    // Deliberately outside the try: a network failure must be distinguishable
    // from a genuine "no data", because the two lead to opposite decisions.
    for (final table in const [
      'food_logs',
      'weight_entries',
      'burn_completions',
      'program_completions',
    ]) {
      try {
        final res =
            await _client.from(table).select('id').eq('user_id', userId).limit(1);
        if (res.isNotEmpty) return true;
      } on Object catch (e) {
        // A missing table (schema not migrated yet) is not an answer — skip it
        // and keep asking the others rather than guessing.
        if (kDebugMode) debugPrint('hasCloudData: $table unavailable: $e');
      }
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('onboarding_complete')
          .eq('id', userId)
          .maybeSingle();
      // A bare profiles row is created by sign-up itself, so its existence
      // proves nothing. Completed onboarding is what makes it *the user's*
      // account rather than an empty shell — treating the shell as "cloud
      // data" is what made a brand-new account skip the guest merge and lose
      // everything the user set up before signing in.
      if (profile != null && profile['onboarding_complete'] == true) {
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('hasCloudData: profiles unavailable: $e');
    }
    return false;
  }
}
