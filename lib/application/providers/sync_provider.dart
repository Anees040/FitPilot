import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/data/remote/remote_data_source.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
import 'package:fitpilot/data/sync/sync_trigger_manager.dart';
import 'package:fitpilot/application/providers/network_provider.dart';
import 'package:fitpilot/data/sync/guest_merge_service.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final remoteDataSourceProvider = Provider<RemoteDataSource>((ref) {
  if (Env.isSupabaseConfigured) {
    return RemoteDataSource(Supabase.instance.client);
  }
  return RemoteDataSource(null);
});

final guestMergeServiceProvider = Provider<GuestMergeService?>((ref) {
  if (!Env.isSupabaseConfigured) return null;
  final db = ref.watch(databaseProvider).value;
  if (db == null) return null;
  final remote = ref.watch(remoteDataSourceProvider);
  return GuestMergeService(db, remote);
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  if (!Env.isSupabaseConfigured) return null;
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final db = ref.watch(databaseProvider).value;
  if (db == null) return null; // Db not initialized yet

  final remote = ref.watch(remoteDataSourceProvider);
  return SyncService(db: db, remote: remote, userId: user.id);
});

final syncTriggerManagerProvider = Provider<SyncTriggerManager?>((ref) {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return null;

  final authRepo = ref.watch(authRepositoryProvider);
  final manager = SyncTriggerManager(service, authRepo);

  ref.listen(isOnlineProvider, (prev, next) {
    if (next.valueOrNull == true) {
      manager.triggerNetworkRegained();
    }
  });

  ref.onDispose(() => manager.dispose());
  return manager;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  if (service == null) {
    return Stream.value(const SyncStatus());
  }
  // Initialize the trigger manager so it starts listening
  ref.watch(syncTriggerManagerProvider);
  return service.status;
});
