import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/exercise_media.dart';
import 'package:fitpilot/domain/entities/burn_option.dart';

/// Shortest and longest session the stepper allows, in minutes.
const int kMinBurnMinutes = 5;
const int kMaxBurnMinutes = 240;
const int kBurnMinuteStep = 5;

/// Converts a duration to kcal for [option] at [weightKg].
///
/// Uses the app-wide MET formula (kcal/min = MET × 3.5 × weight ÷ 200) when the
/// option carries a MET; otherwise scales the suggestion proportionally, which
/// is the best available estimate for composite activities.
int kcalForBurnMinutes(BurnOption option, double weightKg, int minutes) {
  if (minutes <= 0) return 0;
  final met = option.met;
  if (met != null && met > 0) {
    return (met * 3.5 * weightKg / 200 * minutes).round();
  }
  if (option.minutes <= 0) return option.kcal;
  return (option.kcal * minutes / option.minutes).round();
}

/// Logs an activity for the duration the user actually did.
///
/// Replaces the old one-tap "Mark done", which credited the full surplus no
/// matter how long the session really was — and could be tapped repeatedly.
class BurnLogSheet extends ConsumerStatefulWidget {
  final BurnOption option;

  /// True when the day's surplus is already cleared and this is a bonus
  /// session, which only changes the copy — the maths is identical.
  final bool isExtraCredit;

  const BurnLogSheet({
    super.key,
    required this.option,
    this.isExtraCredit = false,
  });

  static Future<void> show(
    BuildContext context, {
    required BurnOption option,
    bool isExtraCredit = false,
  }) {
    return AppBottomSheet.show(
      context,
      child: AppBottomSheet(
        child: BurnLogSheet(option: option, isExtraCredit: isExtraCredit),
      ),
    );
  }

  @override
  ConsumerState<BurnLogSheet> createState() => _BurnLogSheetState();
}

class _BurnLogSheetState extends ConsumerState<BurnLogSheet> {
  late int _minutes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final suggested = widget.option.sessions > 1
        ? widget.option.minutesPerSession
        : widget.option.minutes;
    _minutes = _snap(suggested);
  }

  int _snap(int value) {
    if (value <= kMinBurnMinutes) return kMinBurnMinutes;
    if (value >= kMaxBurnMinutes) return kMaxBurnMinutes;
    return (value / kBurnMinuteStep).round() * kBurnMinuteStep;
  }

  void _step(int delta) {
    final next = (_minutes + delta).clamp(kMinBurnMinutes, kMaxBurnMinutes);
    if (next == _minutes) return;
    HapticFeedback.selectionClick();
    setState(() => _minutes = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final option = widget.option;
    final weightKg = ref.watch(profileProvider).valueOrNull?.weightKg ?? 70.0;
    final kcal = kcalForBurnMinutes(option, weightKg, _minutes);

    final suggestedLabel = option.sessions > 1
        ? 'Suggested: ${option.sessions} × ${option.minutesPerSession} min '
            '→ ${option.kcal} kcal'
        : 'Suggested: ${option.minutes} min → ${option.kcal} kcal';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (option.mediaAsset != null) ...[
              SizedBox(
                width: 56,
                height: 56,
                child: ExerciseMedia.asset(
                  mediaAsset: option.mediaAsset!,
                  borderRadius: 12,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.activity,
                    style: theme.textTheme.h2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isExtraCredit
                        ? 'Bonus session — counts toward Progress'
                        : suggestedLabel,
                    style: theme.textTheme.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        AppCard(
          color: ext.surfaceRaised,
          child: Column(
            children: [
              Text('HOW LONG DID YOU GO?', style: theme.textTheme.overline),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    onPressed:
                        _minutes > kMinBurnMinutes ? () => _step(-kBurnMinuteStep) : null,
                  ),
                  SizedBox(
                    width: 132,
                    child: Column(
                      children: [
                        Text(
                          '$_minutes',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.display.copyWith(
                            fontSize: 40,
                            height: 1.0,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text('minutes', style: theme.textTheme.caption),
                      ],
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onPressed:
                        _minutes < kMaxBurnMinutes ? () => _step(kBurnMinuteStep) : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: ext.energy.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department, size: 18, color: ext.energy),
                    const SizedBox(width: 8),
                    Text(
                      '≈ $kcal kcal burned',
                      style: theme.textTheme.bodyStrong.copyWith(color: ext.energy),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Log this workout',
          isLoading: _isSaving,
          onPressed: _isSaving ? null : () => _log(kcal),
        ),
        if (option.exerciseId != null) ...[
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'See full details',
            onPressed: _isSaving
                ? null
                : () {
                    Navigator.of(context).pop();
                    context.push('/exercises/${option.exerciseId}');
                  },
          ),
        ],
      ],
    );
  }

  Future<void> _log(int kcal) async {
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    try {
      HapticFeedback.heavyImpact();
      await ref
          .read(burnPlanProvider.notifier)
          .logBurn(widget.option, minutes: _minutes, kcal: kcal);

      if (!mounted) return;
      navigator.pop();

      final newState = ref.read(burnPlanProvider).valueOrNull;
      if (!context.mounted) return;

      if (newState != null && newState.kcalToBurnOrEat > 0) {
        AppSnackbar.success(
          context,
          '+$kcal kcal burned — ${newState.kcalToBurnOrEat} to go',
        );
      } else {
        AppSnackbar.success(context, '+$kcal kcal burned. Nice work! 🔥');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, 'Could not log that workout.\n$e');
    }
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final enabled = onPressed != null;
    final color = enabled ? theme.colorScheme.primary : ext.textDisabled;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}
