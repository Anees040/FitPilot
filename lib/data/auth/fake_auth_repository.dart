import 'dart:async';
import 'package:fitpilot/domain/entities/auth_user.dart';
import 'package:fitpilot/domain/entities/auth_failure.dart';
import 'package:fitpilot/domain/repositories/auth_repository.dart';
import 'package:uuid/uuid.dart';

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  bool shouldThrowNetworkError = false;
  bool shouldThrowRateLimit = false;
  bool shouldFailSignIn = false;

  final Map<String, String> _users = {};
  final Map<String, AuthUser> _userRecords = {};

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  void _emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  void _checkGlobalErrors() {
    if (shouldThrowNetworkError) throw const NetworkUnavailableFailure();
    if (shouldThrowRateLimit) throw const RateLimitedFailure();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _checkGlobalErrors();

    if (shouldFailSignIn || _users[email] != password) {
      throw const InvalidCredentialsFailure();
    }

    final record = _userRecords[email];
    if (record != null && !record.emailConfirmed) {
      throw const UnverifiedEmailFailure();
    }

    _emit(record);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _checkGlobalErrors();

    if (_users.containsKey(email)) {
      throw const EmailAlreadyRegisteredFailure();
    }

    _users[email] = password;
    _userRecords[email] = AuthUser(
      id: const Uuid().v4(),
      email: email,
      emailConfirmed: false,
    );
  }

  @override
  Future<void> verifyOtp({required String email, required String token}) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _checkGlobalErrors();

    if (token != '123456') {
      throw const InvalidCredentialsFailure('Invalid OTP code.');
    }

    final record = _userRecords[email];
    if (record != null) {
      final updated = AuthUser(
        id: record.id,
        email: record.email,
        emailConfirmed: true,
      );
      _userRecords[email] = updated;
      _emit(updated);
    }
  }

  @override
  Future<void> resendOtp({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _checkGlobalErrors();
    // Fake: does nothing — OTP is always '123456'
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _checkGlobalErrors();
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 10));
    _checkGlobalErrors();
    _emit(null);
  }
}
