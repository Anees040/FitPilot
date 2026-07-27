import '../entities/auth_user.dart';

/// Abstract interface for authentication operations.
abstract class AuthRepository {
  /// Emits the current user state whenever it changes.
  Stream<AuthUser?> get authStateChanges;

  /// Gets the currently authenticated user synchronously.
  AuthUser? get currentUser;

  /// Signs in a user with email and password.
  Future<void> signIn({required String email, required String password});

  /// Signs up a new user. Might require OTP verification.
  Future<void> signUp({required String email, required String password});

  /// Verifies a 6-digit OTP code sent to the email.
  Future<void> verifyOtp({required String email, required String token});

  /// Sends a password reset link to the email.
  Future<void> sendPasswordReset({required String email});

  /// Signs the current user out.
  Future<void> signOut();
}
