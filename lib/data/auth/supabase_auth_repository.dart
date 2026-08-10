import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
        createdAt: DateTime.tryParse(user.createdAt),
        // Carries the provider's display name and photo. Dropping these meant
        // a Google sign-in arrived with nothing to populate the profile from,
        // so the app greeted the user as "Pilot" with a generic avatar.
        metadata: user.userMetadata ?? const {},
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
      createdAt: DateTime.tryParse(user.createdAt),
      metadata: user.userMetadata ?? const {},
    );
  }

  AuthFailure _mapException(Object e) {
    // Already mapped. Without this guard the catch blocks below re-wrap their
    // own deliberate throws, and the fallback at the end turns them into
    // UnknownAuthFailure(e.toString()) — which is how "Instance of
    // 'UnknownAuthFailure'" used to end up on the login screen.
    if (e is AuthFailure) return e;

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
      // Supabase reports a password attempt on a Google-only account as a
      // generic failure. Naming the real cause saves the user retyping a
      // password they never set.
      if (msg.contains('no password') ||
          msg.contains('oauth') ||
          msg.contains('identity not found')) {
        return const WrongSignInMethodFailure();
      }
      if (msg.contains('user not found')) {
        return const AccountNotFoundFailure();
      }
      // Supabase's own text is written for developers. Passing it through put
      // strings like "AuthApiException(message: ...)" in front of users, so
      // anything unrecognised gets neutral wording instead.
      if (kDebugMode) debugPrint('Unmapped AuthException: ${e.message}');
      return const UnknownAuthFailure(
        'Something went wrong signing you in. Please try again.',
      );
    }
    if (e.toString().contains('SocketException') ||
        e.toString().contains('ClientException')) {
      return const NetworkUnavailableFailure();
    }
    if (kDebugMode) debugPrint('Unmapped auth error: $e');
    return const UnknownAuthFailure(
      'Something went wrong. Please try again in a moment.',
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      final user = _client.auth.currentUser;
      if (user != null && user.userMetadata?['deleted'] == true) {
        // Undelete the account and let them sign in as a fresh user
        await _client.auth.updateUser(supa.UserAttributes(data: {'deleted': false}));
      }
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
  Future<void> resendOtp({required String email}) async {
    try {
      await _client.auth.resend(
        type: supa.OtpType.signup,
        email: email,
      );
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'io.fitpilot://login-callback',
      );
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> signInWithGoogle({required String webClientId, String? webClientSecret}) async {
    try {
      if (kIsWeb) {
        // For web, use OAuth flow
        await _client.auth.signInWithOAuth(
          supa.OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'my-scheme://login-callback', // Web handles redirect automatically if configured
        );
      } else {
        // For native, use google_sign_in plugin
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize(serverClientId: webClientId);
        final googleUser = await googleSignIn.authenticate();
        
        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw const UnknownAuthFailure('No ID Token found.');
        }

        await _client.auth.signInWithIdToken(
          provider: supa.OAuthProvider.google,
          idToken: idToken,
        );
      }
      final user = _client.auth.currentUser;
      if (user != null && user.userMetadata?['deleted'] == true) {
        // Undelete the account and let them sign in as a fresh user
        await _client.auth.updateUser(supa.UserAttributes(data: {'deleted': false}));
      }
    } catch (e) {
      if (e is UnknownAuthFailure) rethrow;
      throw _mapException(e);
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user != null) {
        try {
          await _client.rpc('delete_account');
        } catch (rpcE) {
          if (kDebugMode) debugPrint('[SupabaseAuthRepo] RPC delete_account warning: $rpcE');
          try {
            await _client.from('profiles').delete().eq('id', user.id);
            await _client.from('food_logs').delete().eq('user_id', user.id);
            await _client.from('weight_entries').delete().eq('user_id', user.id);
            await _client.from('burn_completions').delete().eq('user_id', user.id);
          } catch (_) {}
        }
        try {
          await _client.auth.updateUser(supa.UserAttributes(data: {'deleted': true}));
        } catch (_) {}
      }
      await signOut();
    } catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await _client.auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('[SupabaseAuthRepo] Remote signOut offline notice: $e');
      // DO NOT throw on offline sign-out — local sign-out must always proceed
    }
  }
}
