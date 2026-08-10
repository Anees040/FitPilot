import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:fitpilot/application/bootstrap.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/domain/entities/auth_user.dart';
import 'package:fitpilot/domain/repositories/auth_repository.dart';
import 'package:fitpilot/data/auth/supabase_auth_repository.dart';
import 'package:fitpilot/data/auth/fake_auth_repository.dart';

/// Resolves once the post-first-frame Supabase warm-up has settled.
///
/// Reading `Supabase.instance` before that throws, so every provider that needs
/// the client watches this first. Watching (not reading) matters: the value
/// flips from null to a bool when the warm-up lands, which rebuilds the
/// dependents that would otherwise be stuck holding a guest repository.
final supabaseReadyProvider = FutureProvider<bool>((ref) async {
  await FitPilotBootstrap.warmUp();
  return FitPilotBootstrap.supabaseReady;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final isReady = ref.watch(supabaseReadyProvider).valueOrNull ?? false;
  if (Env.isSupabaseConfigured && isReady) {
    return SupabaseAuthRepository(Supabase.instance.client);
  }
  return FakeAuthRepository();
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final asyncValue = ref.watch(authStateProvider);
  return asyncValue.value ?? repo.currentUser;
});
