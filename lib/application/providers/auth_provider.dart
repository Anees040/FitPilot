import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:fitpilot/application/bootstrap.dart';
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/domain/entities/auth_user.dart';
import 'package:fitpilot/domain/repositories/auth_repository.dart';
import 'package:fitpilot/data/auth/supabase_auth_repository.dart';
import 'package:fitpilot/data/auth/fake_auth_repository.dart';

/// Resolves the warm-up started after the first frame. Private: everything
/// reads [supabaseReadyProvider] instead, which avoids a needless rebuild.
final _supabaseWarmUpProvider = FutureProvider<bool>((ref) async {
  await FitPilotBootstrap.warmUp();
  return FitPilotBootstrap.supabaseReady;
});

/// Whether `Supabase.instance` is safe to touch.
///
/// Reads the plain flag first and only falls back to watching the future when
/// the warm-up is genuinely still running. That ordering matters more than it
/// looks: as a bare FutureProvider this always resolved false-then-true, and
/// the flip rebuilt [authRepositoryProvider] → [currentUserProvider] → every
/// repository provider. Any async method holding a notifier across an await
/// then tripped Riverpod's `!_didChangeDependency` assertion — which is how
/// finishing the profile wizard threw a red screen on first launch and worked
/// on the second. The splash awaits the warm-up before it routes, so by the
/// time a real screen reads this the flag is already set and nothing rebuilds.
final supabaseReadyProvider = Provider<bool>((ref) {
  if (FitPilotBootstrap.supabaseReady) return true;
  return ref.watch(_supabaseWarmUpProvider).valueOrNull ?? false;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final isReady = ref.watch(supabaseReadyProvider);
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
