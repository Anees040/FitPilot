import 'package:flutter/material.dart';

import 'package:fitpilot/core/theme/app_theme.dart';

/// Explains where the protein target comes from.
///
/// Shown from the (i) icon next to the goal. Deliberately gives the whole
/// range rather than only the app's default, so a user who is sedentary or
/// training hard can judge whether the number suits them — and ends with an
/// explicit "not medical advice" line.
class ProteinInfoSheet extends StatelessWidget {
  const ProteinInfoSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ProteinInfoSheet(),
    );
  }

  static const _bands = [
    ('0.8 g per kg', 'Sedentary — the minimum to avoid deficiency'),
    ('1.2 – 1.6 g per kg', 'Active — training a few times a week'),
    ('1.6 – 2.2 g per kg', 'Building muscle or eating in a deficit'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.egg_alt_outlined, color: ext.energy),
                const SizedBox(width: 10),
                Text('How much protein?', style: theme.textTheme.h2),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'FitPilot suggests 1.6 g per kg of your bodyweight — the '
              'muscle-building figure, and the one worth aiming at while you '
              'are losing fat.',
              style: theme.textTheme.body,
            ),
            const SizedBox(height: 18),
            for (final (amount, who) in _bands)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: ext.energy,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(amount, style: theme.textTheme.bodyStrong),
                          Text(who, style: theme.textTheme.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'General fitness guidance, not medical advice.',
              style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
