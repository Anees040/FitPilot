import 'package:equatable/equatable.dart';

/// Represents an authenticated user in the domain layer.
class AuthUser extends Equatable {
  final String id;
  final String email;
  final bool emailConfirmed;

  const AuthUser({
    required this.id,
    required this.email,
    required this.emailConfirmed,
  });

  @override
  List<Object?> get props => [id, email, emailConfirmed];
}
