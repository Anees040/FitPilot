import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_card.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onAction;
  final String illustration;

  const EmptyState({
    super.key,
    required this.message,
    required this.buttonLabel,
    required this.onAction,
    required this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // If we had SVG we'd use flutter_svg, but for now we might use an icon or an Image.
          // Spec says "line-art illustration 160 dp". If the image isn't available we fallback gracefully.
          SizedBox(
            width: 160,
            height: 160,
            child: illustration.isNotEmpty
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset('assets/illustrations/$illustration.png', errorBuilder: (context, error, stackTrace) => Icon(Icons.inbox, size: 80, color: theme.colorScheme.onSurface.withValues(alpha: 0.2))),
                  )
                : Icon(Icons.inbox, size: 80, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: buttonLabel,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String reason;
  final VoidCallback onRetry;

  const ErrorState({
    super.key,
    required this.reason,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: ext.error),
          const SizedBox(height: 16),
          Text(
            reason,
            style: theme.textTheme.body.copyWith(color: ext.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SecondaryButton(
            label: 'Retry',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class SkeletonList extends StatefulWidget {
  final int count;
  const SkeletonList({super.key, this.count = 3});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.7),
          child: child,
        );
      },
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.count,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final theme = Theme.of(context);
          final ext = theme.extension<AppColors>()!;
          return AppCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ext.hairline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 16, width: 120, color: ext.hairline),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 80, color: ext.hairline),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
