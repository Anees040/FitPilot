import 'package:flutter/material.dart';

/// A horizontally scrollable row with a fade hint at the trailing edge.
class FadeScrollRow extends StatelessWidget {
  final List<Widget> children;

  const FadeScrollRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white,
          Colors.white,
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.85, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 32), // extra padding for fade
        child: Row(
          children: children,
        ),
      ),
    );
  }
}
