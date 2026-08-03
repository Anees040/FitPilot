import 'dart:math';
import 'package:flutter/material.dart';

class SemicircleProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color activeColor;
  final Color backgroundColor;
  final double strokeWidth;
  final Widget? child;
  final double radius;

  const SemicircleProgress({
    super.key,
    required this.progress,
    required this.activeColor,
    required this.backgroundColor,
    this.strokeWidth = 16.0,
    this.child,
    this.radius = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius + strokeWidth,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomPaint(
            size: Size(radius * 2, radius + strokeWidth / 2),
            painter: _SemicirclePainter(
              progress: progress,
              activeColor: activeColor,
              backgroundColor: backgroundColor,
              strokeWidth: strokeWidth,
            ),
          ),
          if (child != null)
            Positioned(
              bottom: 0,
              child: child!,
            ),
        ],
      ),
    );
  }
}

class _SemicirclePainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color backgroundColor;
  final double strokeWidth;

  _SemicirclePainter({
    required this.progress,
    required this.activeColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - strokeWidth / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background arc (180 degrees)
    canvas.drawArc(rect, pi, pi, false, bgPaint);

    // Draw active arc
    final sweepAngle = pi * progress.clamp(0.0, 1.0);
    if (sweepAngle > 0) {
      canvas.drawArc(rect, pi, sweepAngle, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SemicirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
