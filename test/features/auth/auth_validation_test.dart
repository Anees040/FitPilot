import 'package:flutter_test/flutter_test.dart';

// Validator helpers (extracted from sign_in_screen & sign_up_screen logic)
// These are pure functions, no Flutter widget needed.

/// Returns an error string or null if valid.
String? validateEmail(String email) {
  if (email.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}

/// Returns an error string or null if valid.
String? validateLoginPassword(String password) {
  if (password.isEmpty) return 'Enter your password';
  return null;
}

/// Returns the set of met requirements.
({bool hasLength, bool hasLetter, bool hasNumber}) checkPasswordRequirements(
    String password) {
  return (
    hasLength: password.length >= 8,
    hasLetter: RegExp(r'[a-zA-Z]').hasMatch(password),
    hasNumber: RegExp(r'[0-9]').hasMatch(password),
  );
}

void main() {
  group('Email validator', () {
    test('empty email returns error', () {
      expect(validateEmail(''), 'Enter your email');
    });

    test('missing @ returns error', () {
      expect(validateEmail('notemail'), 'Enter a valid email address');
    });

    test('missing domain returns error', () {
      expect(validateEmail('user@'), 'Enter a valid email address');
    });

    test('valid email returns null', () {
      expect(validateEmail('user@example.com'), isNull);
    });

    test('valid email with subdomain returns null', () {
      expect(validateEmail('user@mail.example.co.uk'), isNull);
    });
  });

  group('Login password validator', () {
    test('empty password returns error', () {
      expect(validateLoginPassword(''), 'Enter your password');
    });

    test('non-empty password returns null', () {
      expect(validateLoginPassword('anyPass'), isNull);
    });
  });

  group('Password requirements checker', () {
    test('empty password fails all', () {
      final req = checkPasswordRequirements('');
      expect(req.hasLength, isFalse);
      expect(req.hasLetter, isFalse);
      expect(req.hasNumber, isFalse);
    });

    test('short password fails length', () {
      final req = checkPasswordRequirements('Ab1');
      expect(req.hasLength, isFalse);
      expect(req.hasLetter, isTrue);
      expect(req.hasNumber, isTrue);
    });

    test('no number fails number', () {
      final req = checkPasswordRequirements('abcdefgh');
      expect(req.hasLength, isTrue);
      expect(req.hasLetter, isTrue);
      expect(req.hasNumber, isFalse);
    });

    test('no letter fails letter', () {
      final req = checkPasswordRequirements('12345678');
      expect(req.hasLength, isTrue);
      expect(req.hasLetter, isFalse);
      expect(req.hasNumber, isTrue);
    });

    test('valid password meets all', () {
      final req = checkPasswordRequirements('MyPass123');
      expect(req.hasLength, isTrue);
      expect(req.hasLetter, isTrue);
      expect(req.hasNumber, isTrue);
    });
  });
}
