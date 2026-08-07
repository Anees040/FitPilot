import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/buttons.dart';

/// Shown once, right after the final day of a program is marked complete.
///
/// The totals are passed in rather than re-read, because finishing clears the
/// active-program pointer — by the time this builds there is no "current"
/// program left to query.
class ProgramCompleteScreen extends ConsumerWidget {
  final String programId;
  final int sessions;
  final int kcal;

  const ProgramCompleteScreen({
    super.key,
    required this.programId,
    required this.sessions,
    required this.kcal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    final programs = ref.watch(programsProvider).valueOrNull;
    String name = 'Your program';
    if (programs != null) {
      for (final p in programs) {
        if (p.program.id == programId) name = p.program.name;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: ext.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events,
                  size: 60,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$name complete!',
                style: theme.textTheme.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'You finished every day of the plan. That consistency is the '
                'whole game.',
                style: theme.textTheme.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: '$sessions',
                      label: sessions == 1 ? 'day done' : 'days done',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      value: '$kcal',
                      label: 'kcal burned',
                      color: ext.energy,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Choose next program',
                onPressed: () => context.go('/programs'),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Done',
                onPressed: () => context.go('/today'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      variant: AppCardVariant.raised,
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.display.copyWith(fontSize: 32, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.caption),
        ],
      ),
    );
  }
}
