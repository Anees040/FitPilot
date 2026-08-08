import 'package:flutter_test/flutter_test.dart';

import 'package:fitpilot/domain/engines/profile_identity_sync.dart';
import 'package:fitpilot/domain/entities/auth_user.dart';
import 'package:fitpilot/domain/entities/profile.dart';

AuthUser _user({
  String email = 'someone@example.com',
  Map<String, dynamic> metadata = const {},
}) => AuthUser(
  id: 'u1',
  email: email,
  emailConfirmed: true,
  metadata: metadata,
);

Profile _profile({String? name, String? avatarUrl}) => Profile(
  name: name,
  avatarUrl: avatarUrl,
  weightKg: 70,
  heightCm: 175,
  age: 25,
  gender: Gender.male,
  goal: Goal.maintain,
  activityLevel: ActivityLevel.light,
  allowanceKcal: 300,
  equipment: const [],
  updatedAt: DateTime(2026, 8, 9),
);

void main() {
  group('merge', () {
    test('fills an empty name and photo from a Google sign-in', () {
      // The bug this guards: nothing read the provider payload, so signing in
      // with Google left the profile blank and Today greeted the user "Pilot".
      final merged = ProfileIdentitySync.merge(
        profile: _profile(),
        user: _user(
          metadata: const {
            'full_name': 'Muhammad Anees',
            'avatar_url': 'https://lh3.googleusercontent.com/a/abc',
          },
        ),
      );

      expect(merged, isNotNull);
      expect(merged!.name, 'Muhammad Anees');
      expect(merged.avatarUrl, 'https://lh3.googleusercontent.com/a/abc');
    });

    test("never overwrites a name the user set themselves", () {
      final merged = ProfileIdentitySync.merge(
        profile: _profile(name: 'Anees'),
        user: _user(metadata: const {'full_name': 'Muhammad Anees'}),
      );

      // Only the photo was missing, so only the photo may change.
      expect(merged, isNull);
    });

    test('never replaces a photo the user picked', () {
      // A local path means the user chose it; re-signing in must not swap it
      // back to the Google picture.
      final merged = ProfileIdentitySync.merge(
        profile: _profile(
          name: 'Anees',
          avatarUrl: '/data/user/0/com.fitpilot/files/profile_avatar.jpg',
        ),
        user: _user(
          metadata: const {
            'full_name': 'Muhammad Anees',
            'avatar_url': 'https://lh3.googleusercontent.com/a/abc',
          },
        ),
      );

      expect(merged, isNull);
    });

    test('fills only the missing half', () {
      final merged = ProfileIdentitySync.merge(
        profile: _profile(name: 'Anees'),
        user: _user(
          metadata: const {
            'full_name': 'Muhammad Anees',
            'avatar_url': 'https://example.com/a.jpg',
          },
        ),
      );

      expect(merged!.name, 'Anees', reason: 'their own name survives');
      expect(merged.avatarUrl, 'https://example.com/a.jpg');
    });

    test('accepts the alternative key spellings providers use', () {
      final merged = ProfileIdentitySync.merge(
        profile: _profile(),
        // Supabase surfaces 'name' and 'picture' for some providers.
        user: _user(metadata: const {'name': 'Ali', 'picture': 'https://x/y.png'}),
      );

      expect(merged!.name, 'Ali');
      expect(merged.avatarUrl, 'https://x/y.png');
    });

    test('a signed-out user changes nothing', () {
      expect(
        ProfileIdentitySync.merge(profile: _profile(), user: null),
        isNull,
      );
    });

    test('empty metadata strings are treated as absent', () {
      final merged = ProfileIdentitySync.merge(
        profile: _profile(),
        user: _user(metadata: const {'full_name': '   ', 'avatar_url': ''}),
      );

      expect(merged, isNull, reason: 'blank values must not overwrite anything');
    });

    test('returns null when there is nothing to add, avoiding a needless write',
        () {
      final merged = ProfileIdentitySync.merge(
        profile: _profile(name: 'Anees', avatarUrl: 'https://x/y.png'),
        user: _user(metadata: const {'full_name': 'Other'}),
      );

      expect(merged, isNull);
    });
  });

  group('displayNameFor', () {
    test('prefers the provider name', () {
      expect(
        ProfileIdentitySync.displayNameFor(
          _user(metadata: const {'full_name': 'Muhammad Anees'}),
        ),
        'Muhammad Anees',
      );
    });

    test('derives something friendly from an email when there is no name', () {
      // Better than "Pilot" for a password-only signup.
      expect(
        ProfileIdentitySync.displayNameFor(_user(email: 'muhammad.anees@x.com')),
        'Muhammad Anees',
      );
    });

    test('handles underscores and hyphens in the local part', () {
      expect(
        ProfileIdentitySync.displayNameFor(_user(email: 'ali_raza-khan@x.com')),
        'Ali Raza Khan',
      );
    });

    test('gives up rather than inventing a name', () {
      expect(ProfileIdentitySync.displayNameFor(_user(email: '')), isNull);
      expect(ProfileIdentitySync.displayNameFor(null), isNull);
    });
  });
}
