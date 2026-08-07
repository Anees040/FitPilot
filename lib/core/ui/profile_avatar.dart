import 'package:flutter/material.dart';

class ProfileAvatar extends StatefulWidget {
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
    final bool hasValidUrl = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    final bool showImage = hasValidUrl && !_hasError;
    final initials = _getInitials();

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      backgroundImage: showImage ? NetworkImage(widget.avatarUrl!) : null,
      onBackgroundImageError: showImage
          ? (exception, stackTrace) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                });
              }
            }
          : null,
      child: showImage
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
