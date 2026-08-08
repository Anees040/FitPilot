import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The user's avatar, from either a remote URL or a local file.
///
/// Google sign-in supplies an https URL; a photo the user picks themselves is
/// written into the app sandbox and stored as a plain filesystem path. Both end
/// up in the same profile field, so this widget decides which loader to use
/// rather than making every caller care.
class ProfileAvatar extends StatefulWidget {
  /// An https URL or an absolute file path.
  final String? avatarUrl;
  final String? name;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.radius = 18.0,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _hasError = false;

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _hasError = false;
    }
  }

  /// Initials for the name, or null when there is no usable name — the caller
  /// falls back to a person icon rather than showing a bare "?".
  String? _getInitials() {
    final name = widget.name?.trim();
    if (name == null || name.isEmpty) return null;
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = widget.avatarUrl?.trim();
    final hasSource = source != null && source.isNotEmpty;
    final showImage = hasSource && !_hasError;
    final initials = _getInitials();

    // A picked photo is a file path, not a URL. NetworkImage on a path throws,
    // which is why a locally chosen avatar used to silently fall back to
    // initials.
    ImageProvider? provider;
    if (showImage) {
      final isRemote = source.startsWith('http://') || source.startsWith('https://');
      if (isRemote) {
        provider = NetworkImage(source);
      } else if (!kIsWeb) {
        provider = FileImage(File(source));
      }
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      backgroundImage: provider,
      onBackgroundImageError: provider != null
          ? (exception, stackTrace) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                });
              }
            }
          : null,
      child: provider != null
          ? null
          : (initials != null
              ? Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: widget.radius * 0.8,
                  ),
                )
              : Icon(Icons.person, size: widget.radius)),
    );
  }
}
