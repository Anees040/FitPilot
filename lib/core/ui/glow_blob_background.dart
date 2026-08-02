import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class GlowBlobBackground extends StatefulWidget {
  final Widget child;

  const GlowBlobBackground({super.key, required this.child});

  @override
  State<GlowBlobBackground> createState() => _GlowBlobBackgroundState();
}

class _GlowBlobBackgroundState extends State<GlowBlobBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isReducedMotion = MediaQuery.of(context).disableAnimations;

    if (isReducedMotion) {
      return Container(
        color: theme.scaffoldBackgroundColor,
        child: widget.child,
      );
    }

    return Stack(
      children: [
        Container(color: theme.scaffoldBackgroundColor),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _GlowBlobPainter(
                progress: _controller.value,
                color1: theme.colorScheme.primary.withValues(alpha: 0.15),
                color2: ext.energy.withValues(alpha: 0.1),
              ),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _GlowBlobPainter extends CustomPainter {
  final double progress;
  final Color color1;
  final Color color2;

  _GlowBlobPainter({
    required this.progress,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Blob 1 orbits
    final angle1 = progress * 2 * math.pi;
    final dx1 = math.cos(angle1) * 100;
    final dy1 = math.sin(angle1) * 200;

    // Blob 2 orbits opposite
    final angle2 = (1.0 - progress) * 2 * math.pi;
    final dx2 = math.cos(angle2) * 150;
    final dy2 = math.sin(angle2) * 150;

    final paint1 = Paint()
      ..color = color1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
      
    final paint2 = Paint()
      ..color = color2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    canvas.drawCircle(Offset(cx + dx1, cy * 0.5 + dy1), 150, paint1);
    canvas.drawCircle(Offset(cx + dx2, cy * 1.2 + dy2), 200, paint2);
  }

  @override
  bool shouldRepaint(covariant _GlowBlobPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
