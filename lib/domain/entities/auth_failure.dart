/// Represents failures that can occur during authentication operations.
///
/// Every variant carries a message written for the user, not for a log. The UI
/// shows [message] directly, so anything added here must read as a sentence
/// someone would want to see on a login screen.
sealed class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  /// Without this, `toString()` returns "Instance of 'UnknownAuthFailure'".
  /// That string used to reach the login screen whenever a failure was
  /// accidentally wrapped twice, so the override is a safety net rather than a
  /// convenience.
  @override
  String toString() => message;
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([
    super.message = 'Invalid email or password.',
  ]);
}

class EmailAlreadyRegisteredFailure extends AuthFailure {
  const EmailAlreadyRegisteredFailure([
    super.message = 'Email is already registered.',
  ]);
}

class UnverifiedEmailFailure extends AuthFailure {
  const UnverifiedEmailFailure([
    super.message = 'Email address is not verified.',
  ]);
}

class NetworkUnavailableFailure extends AuthFailure {
  const NetworkUnavailableFailure([
    super.message = 'Network is unavailable. Please check your connection.',
  ]);
}

class RateLimitedFailure extends AuthFailure {
  const RateLimitedFailure([
    super.message = 'Too many requests. Please try again later.',
  ]);
}

/// The account existed but has been deleted.
///
/// Its own type rather than an UnknownAuthFailure with a custom string: the
/// login screen needs to offer "create a new account" here, which it cannot do
/// if the reason is only distinguishable by matching on message text.
class AccountDeletedFailure extends AuthFailure {
  const AccountDeletedFailure([
    super.message =
        'This account was deleted. You can sign up again with the same email.',
  ]);
}

/// The email is registered, but with a different sign-in method.
///
/// Someone who signed up with Google and later types a password gets told what
/// to do, instead of "invalid credentials" — which sounds like they mistyped.
class WrongSignInMethodFailure extends AuthFailure {
  const WrongSignInMethodFailure([
    super.message =
        'This email is registered with Google. Use "Continue with Google" to sign in.',
  ]);
}

/// No account exists for this email yet.
class AccountNotFoundFailure extends AuthFailure {
  const AccountNotFoundFailure([
    super.message = 'No account found for that email. Create one to get started.',
  ]);
}

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure([super.message = 'An unknown error occurred.']);
}
