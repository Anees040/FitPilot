import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/network_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: isOnline
          ? const SizedBox(width: double.infinity, height: 0)
          : Container(
              width: double.infinity,
              color: ext.surfaceRaised, // surface theme per instructions
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 16,
                      color: ext.error, // or text theme color
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Offline - changes will sync when you're back",
                        style: theme.textTheme.caption.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
