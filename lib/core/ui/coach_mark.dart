import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:fitpilot/core/theme/app_theme.dart';

/// FitPilot's coach mark: a flame inside a ring of orbiting sparks.
///
/// Drawn rather than shipped as an asset so it stays crisp at any size, picks
/// its colours up from the theme, and can animate while the coach is thinking.
/// The flame is the app's own "burn it" idea; the sparks read as intelligence
/// without borrowing another product's robot-face vocabulary.
class CoachMark extends StatelessWidget {
  final double size;

  /// Draws the filled ember disc behind the flame. Off for a bare glyph in an
  /// app bar, on for an avatar.
  final bool filled;

  /// Rotation of the spark ring, 0..1. Animate for a "thinking" state.
  final double spin;

  const CoachMark({
    super.key,
    this.size = 32,
    this.filled = true,
    this.spin = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _CoachMarkPainter(
          flame: theme.colorScheme.primary,
          spark: ext.energy,
          disc: filled ? theme.colorScheme.primary : null,
          deep: filled ? ext.accentDeep : null,
          onDisc: theme.colorScheme.onPrimary,
          spin: spin,
        ),
      ),
    );
  }
}

/// The coach mark with its sparks slowly turning — used while a reply is in
/// flight, so the wait has a focal point that is not a bare spinner.
class ThinkingCoachMark extends StatefulWidget {
  final double size;

  const ThinkingCoachMark({super.key, this.size = 28});

  @override
  State<ThinkingCoachMark> createState() => _ThinkingCoachMarkState();
}

class _ThinkingCoachMarkState extends State<ThinkingCoachMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          CoachMark(size: widget.size, spin: _controller.value),
    );
  }
}

class _CoachMarkPainter extends CustomPainter {
  final Color flame;
  final Color spark;

  /// Null for a transparent background.
  final Color? disc;

  /// Darker end of the disc gradient. Comes from the theme's accentDeep rather
  /// than a hand-blended black, so the mark follows a theme change.
  final Color? deep;
  final Color onDisc;
  final double spin;

  const _CoachMarkPainter({
    required this.flame,
    required this.spark,
    required this.disc,
    required this.deep,
    required this.onDisc,
    required this.spin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (disc != null) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [disc!, deep ?? disc!],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final flameColor = disc != null ? onDisc : flame;

    // The flame: a teardrop with a curled base, so it reads as fire rather
    // than as a generic droplet.
    final h = size.height;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.50, h * 0.20)
      ..cubicTo(w * 0.70, h * 0.38, w * 0.72, h * 0.50, w * 0.66, h * 0.60)
      ..cubicTo(w * 0.62, h * 0.68, w * 0.56, h * 0.72, w * 0.50, h * 0.74)
      ..cubicTo(w * 0.42, h * 0.72, w * 0.35, h * 0.66, w * 0.33, h * 0.57)
      ..cubicTo(w * 0.31, h * 0.46, w * 0.38, h * 0.34, w * 0.50, h * 0.20)
      ..close();
    canvas.drawPath(path, Paint()..color = flameColor);

    // Inner curl, punched out so it works on any background.
    final inner = Path()
      ..moveTo(w * 0.50, h * 0.40)
      ..cubicTo(w * 0.58, h * 0.50, w * 0.58, h * 0.58, w * 0.50, h * 0.64)
      ..cubicTo(w * 0.44, h * 0.58, w * 0.44, h * 0.50, w * 0.50, h * 0.40)
      ..close();
    canvas.drawPath(
      inner,
      Paint()..color = disc != null ? disc!.withValues(alpha: 0.55) : spark,
    );

    // Three sparks on a ring, unevenly spaced so it looks deliberate rather
    // than mechanical.
    final sparkPaint = Paint()..color = disc != null ? onDisc : spark;
    const offsets = [0.0, 0.38, 0.72];
    for (var i = 0; i < offsets.length; i++) {
      final t = (spin + offsets[i]) % 1.0;
      final angle = t * 2 * math.pi;
      final ringRadius = radius * 0.82;
      final dot = Offset(
        center.dx + math.cos(angle) * ringRadius,
        center.dy + math.sin(angle) * ringRadius,
      );
      canvas.drawCircle(dot, radius * (i == 0 ? 0.10 : 0.07), sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_CoachMarkPainter old) =>
      old.spin != spin ||
      old.flame != flame ||
      old.spark != spark ||
      old.disc != disc ||
      old.deep != deep;
}
