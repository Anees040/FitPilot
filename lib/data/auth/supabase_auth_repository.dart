import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:fitpilot/domain/entities/auth_user.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final supa.SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Stream<AuthUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return AuthUser(
        id: user.id,
        email: user.email ?? '',
        emailConfirmed: user.emailConfirmedAt != null,
      );
    });
  }

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      emailConfirmed: user.emailConfirmedAt != null,
    );
  }

  AuthFailure _mapException(Object e) {
    if (e is supa.AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return const InvalidCredentialsFailure();
      }
      if (msg.contains('already registered') ||
          msg.contains('user already exists')) {
        return const EmailAlreadyRegisteredFailure();
      }
      if (msg.contains('rate limit')) {
        return const RateLimitedFailure();
      }
      if (msg.contains('email not confirmed')) {
        return const UnverifiedEmailFailure();
      }
      return UnknownAuthFailure(e.message);
    }
    if (e.toString().contains('SocketException') ||
        e.toString().contains('ClientException')) {
      return const NetworkUnavailableFailure();
    }
    return UnknownAuthFailure(e.toString());
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> verifyOtp({required String email, required String token}) async {
    try {
      await _client.auth.verifyOTP(
        type: supa.OtpType.signup,
        email: email,
        token: token,
      );
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw _mapException(e);
    }
  }
}
