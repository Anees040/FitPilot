import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:fitpilot/core/config/env.dart';
import 'package:fitpilot/domain/entities/auth_user.dart';
import 'package:fitpilot/domain/repositories/auth_repository.dart';
import 'package:fitpilot/data/auth/supabase_auth_repository.dart';
import 'package:fitpilot/data/auth/fake_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.isSupabaseConfigured) {
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
