import 'package:fitpilot/domain/entities/auth_user.dart';
import 'package:fitpilot/domain/entities/profile.dart';

/// Copies what an identity provider knows about the user into their profile.
///
/// Google returns a display name and a photo in the sign-in payload, but
/// nothing was reading them, so signing in with Google left the profile blank —
/// Today greeted the user as "Pilot" and the avatar stayed a generic icon.
///
/// The rule is fill-the-gaps, never overwrite: a name or photo the user set
/// themselves outranks whatever Google has on file, and re-signing in must not
/// silently undo their edit.
class ProfileIdentitySync {
  const ProfileIdentitySync._();

  /// Keys Supabase surfaces for a Google identity. Providers disagree on
  /// spelling, so each is tried in order of how specific it is.
  static const _nameKeys = ['full_name', 'name', 'preferred_username'];
  static const _avatarKeys = ['avatar_url', 'picture'];

  /// Returns [profile] with any missing identity fields filled from [user],
  /// or null when there is nothing to change.
  ///
  /// Returning null rather than an identical profile lets the caller skip a
  /// pointless database write on every auth state change.
  static Profile? merge({required Profile profile, required AuthUser? user}) {
    if (user == null) return null;

    final name = _firstNonEmpty(user.metadata, _nameKeys);
    final avatar = _firstNonEmpty(user.metadata, _avatarKeys);

    final needsName = _isBlank(profile.name) && name != null;

    // A locally-picked avatar is a file path; a provider avatar is a URL.
    // Only fill an empty slot, so a photo the user chose is never replaced by
    // their Google picture on the next sign-in.
    final needsAvatar = _isBlank(profile.avatarUrl) && avatar != null;

    if (!needsName && !needsAvatar) return null;

    return profile.copyWith(
      name: needsName ? name : null,
      avatarUrl: needsAvatar ? avatar : null,
    );
  }

  /// Display name for a user with no profile name yet.
  ///
  /// Falls back to the part of the email before the @, so a password-only
  /// signup still gets something friendlier than "Pilot".
  static String? displayNameFor(AuthUser? user) {
    if (user == null) return null;
    final fromMetadata = _firstNonEmpty(user.metadata, _nameKeys);
    if (fromMetadata != null) return fromMetadata;

    final email = user.email.trim();
    if (email.isEmpty || !email.contains('@')) return null;
    final local = email.split('@').first.trim();
    if (local.isEmpty) return null;

    // "muhammad.anees" -> "Muhammad Anees"
    final words = local
        .split(RegExp(r'[._\-+]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .toList();
    return words.isEmpty ? null : words.join(' ');
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static String? _firstNonEmpty(Map<String, dynamic> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
