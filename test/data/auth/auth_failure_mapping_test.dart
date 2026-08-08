import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/entities/auth_failure.dart';

/// Guards the bug that put "Instance of 'UnknownAuthFailure'" on the login
/// screen: a failure thrown inside a try block was caught by that same block
/// and re-wrapped with `e.toString()`.
void main() {
  group('AuthFailure.toString', () {
    test('reads as the user-facing message, never as a Dart type name', () {
      // The exact regression: toString() with no override yields
      // "Instance of 'UnknownAuthFailure'".
      for (final failure in const <AuthFailure>[
        InvalidCredentialsFailure(),
        EmailAlreadyRegisteredFailure(),
        UnverifiedEmailFailure(),
        NetworkUnavailableFailure(),
        RateLimitedFailure(),
        AccountDeletedFailure(),
        WrongSignInMethodFailure(),
        AccountNotFoundFailure(),
        UnknownAuthFailure(),
      ]) {
        expect(
          failure.toString(),
          isNot(contains('Instance of')),
          reason: '${failure.runtimeType} would print its type to the user',
        );
        expect(failure.toString(), failure.message);
      }
    });

    test('every message is a sentence a user could act on', () {
      for (final failure in const <AuthFailure>[
        InvalidCredentialsFailure(),
        EmailAlreadyRegisteredFailure(),
        AccountDeletedFailure(),
        WrongSignInMethodFailure(),
        AccountNotFoundFailure(),
      ]) {
        final message = failure.message;
        expect(message, isNotEmpty);
        expect(message.endsWith('.'), isTrue, reason: message);
        // Developer-facing noise that has leaked to users before.
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('AuthApi')));
        expect(message, isNot(contains('null')));
      }
    });
  });

  group('distinct types for distinct causes', () {
    test('a deleted account is its own type, not a stringly-typed unknown', () {
      // The login screen offers "sign up again" for this case, which it can
      // only do by matching the type.
      const failure = AccountDeletedFailure();
      expect(failure, isA<AuthFailure>());
      expect(failure, isNot(isA<UnknownAuthFailure>()));
      expect(failure.message.toLowerCase(), contains('deleted'));
      expect(failure.message.toLowerCase(), contains('sign up'));
    });

    test('a Google-only account is distinguishable from a wrong password', () {
      const wrongMethod = WrongSignInMethodFailure();
      expect(wrongMethod, isNot(isA<InvalidCredentialsFailure>()));
      expect(wrongMethod.message, contains('Google'));
    });

    test('a missing account is distinguishable from a wrong password', () {
      // Supabase reports both as "invalid login credentials" by default, so
      // conflating them tells the user to check a password that never existed.
      expect(const AccountNotFoundFailure(), isNot(isA<InvalidCredentialsFailure>()));
    });
  });
}
