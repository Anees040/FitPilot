/// Represents failures that can occur during authentication operations.
sealed class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
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

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure([super.message = 'An unknown error occurred.']);
}
