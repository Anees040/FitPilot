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

  String _getInitials() {
    if (widget.name == null || widget.name!.trim().isEmpty) return '?';
    final parts = widget.name!.trim().split(' ');
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
      child: !showImage 
          ? Text(
              _getInitials(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: widget.radius * 0.8,
              ),
            )
          : null,
    );
  }
}
