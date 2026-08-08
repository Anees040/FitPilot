import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitpilot/application/providers/notification_prefs_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/data/notifications/notification_service.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';

/// Per-category notification settings, quiet hours and reminder times.
///
/// Every control writes straight through to the database and re-syncs the OS
/// schedule, so what the user sees here is what actually fires.
class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: prefsAsync.when(
        data: (prefs) => _Body(prefs: prefs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final NotificationPreferences prefs;

  const _Body({required this.prefs});

  /// Saves and re-syncs. Asking for OS permission the first time something is
  /// switched on is what stops silently-dead reminders.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences next, {
    bool needsPermission = false,
  }) async {
    if (needsPermission) {
      final granted = await ref
          .read(notificationServiceProvider)
          .requestPermissions();
      if (!granted) {
        if (context.mounted) {
          AppSnackbar.warning(
            context,
            'Notifications are blocked for FitPilot in your system settings.',
          );
        }
        return;
      }
    }
    await ref.read(notificationPrefsProvider.notifier).updatePrefs(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final muted = prefs.globalMute;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Mute everything', style: theme.textTheme.bodyStrong),
            subtitle: Text(
              muted
                  ? 'All reminders are paused'
                  : 'Pause every reminder without losing your settings',
              style: theme.textTheme.caption,
            ),
            value: muted,
            onChanged: (value) => _save(
              context,
              ref,
              prefs.copyWith(globalMute: value),
              needsPermission: !value,
            ),
          ),
        ),
        const SizedBox(height: 20),

        _SectionLabel(text: 'What to send', dimmed: muted),
        const SizedBox(height: 8),
        _ToggleCard(
          enabled: !muted,
          icon: Icons.restaurant_rounded,
          title: 'Meal reminders',
          subtitle: 'A nudge at your meal times when nothing is logged',
          value: prefs.mealRemindersEnabled,
          onChanged: (v) => _save(
            context,
            ref,
            prefs.copyWith(mealRemindersEnabled: v),
            needsPermission: v,
          ),
        ),
        _ToggleCard(
          enabled: !muted,
          icon: Icons.local_fire_department_rounded,
          title: 'Burn reminders',
          subtitle: 'An evening prompt when a surplus is still open',
          value: prefs.burnRemindersEnabled,
          onChanged: (v) => _save(
            context,
            ref,
            prefs.copyWith(burnRemindersEnabled: v),
            needsPermission: v,
          ),
        ),
        _ToggleCard(
          enabled: !muted,
          icon: Icons.whatshot_rounded,
          title: 'Streak at risk',
          subtitle: 'Warns you before a streak lapses',
          value: prefs.streakRiskEnabled,
          onChanged: (v) => _save(
            context,
            ref,
            prefs.copyWith(streakRiskEnabled: v),
            needsPermission: v,
          ),
        ),
        _ToggleCard(
          enabled: !muted,
          icon: Icons.emoji_events_rounded,
          title: 'Milestones',
          subtitle: 'Celebrates each full week on plan',
          value: prefs.milestonesEnabled,
          onChanged: (v) => _save(
            context,
            ref,
            prefs.copyWith(milestonesEnabled: v),
            needsPermission: v,
          ),
        ),
        _ToggleCard(
          enabled: !muted,
          icon: Icons.fitness_center_rounded,
          title: 'Programme days',
          subtitle: "Reminds you when today's session is waiting",
          value: prefs.programRemindersEnabled,
          onChanged: (v) => _save(
            context,
            ref,
            prefs.copyWith(programRemindersEnabled: v),
            needsPermission: v,
          ),
        ),
        _ToggleCard(
          enabled: !muted,
          icon: Icons.water_drop_rounded,
          title: 'Water',
          subtitle: 'One mid-afternoon prompt, never more',
          value: prefs.waterRemindersEnabled,
          onChanged: (v) => _save(
            context,
            ref,
            prefs.copyWith(waterRemindersEnabled: v),
            needsPermission: v,
          ),
        ),

        const SizedBox(height: 20),
        _SectionLabel(text: 'Weekly weigh-in', dimmed: muted),
        const SizedBox(height: 8),
        _ToggleCard(
          enabled: !muted,
          icon: Icons.monitor_weight_rounded,
          title: 'Weigh-in reminder',
          subtitle: 'Same day each week keeps the trend readable',
          value: prefs.weighInEnabled,
          onChanged: (v) => _save(
            context,
            ref,
            prefs.copyWith(weighInEnabled: v),
            needsPermission: v,
          ),
        ),
        if (prefs.weighInEnabled && !muted) ...[
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Day', style: theme.textTheme.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      _DayChip(
                        label: _dayLabel(day),
                        selected: prefs.weighInDay == day,
                        onTap: () => _save(
                          context,
                          ref,
                          prefs.copyWith(weighInDay: day),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _TimeRow(
                  label: 'Time',
                  value: prefs.weighInTime,
                  onPick: (value) =>
                      _save(context, ref, prefs.copyWith(weighInTime: value)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        _SectionLabel(text: 'Quiet hours', dimmed: muted),
        const SizedBox(height: 8),
        _ToggleCard(
          enabled: !muted,
          icon: Icons.bedtime_rounded,
          title: 'Do not disturb',
          subtitle: 'Nothing is delivered inside this window',
          value: prefs.quietHoursEnabled,
          onChanged: (v) =>
              _save(context, ref, prefs.copyWith(quietHoursEnabled: v)),
        ),
        if (prefs.quietHoursEnabled && !muted) ...[
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TimeRow(
                  label: 'From',
                  value: prefs.quietFrom,
                  onPick: (value) =>
                      _save(context, ref, prefs.copyWith(quietFrom: value)),
                ),
                Divider(color: ext.hairline, height: 24),
                _TimeRow(
                  label: 'Until',
                  value: prefs.quietTo,
                  onPick: (value) =>
                      _save(context, ref, prefs.copyWith(quietTo: value)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        _SectionLabel(text: 'Meal times', dimmed: muted),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var i = 0; i < prefs.mealTimes.length; i++) ...[
                if (i > 0) Divider(color: ext.hairline, height: 24),
                _TimeRow(
                  label: _mealLabel(i),
                  value: prefs.mealTimes[i],
                  onPick: (value) {
                    final times = List<String>.from(prefs.mealTimes);
                    times[i] = value;
                    _save(context, ref, prefs.copyWith(mealTimes: times));
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Reminders are generated on this device from your own data. Nothing '
          'about your meals or weight leaves the app to produce them.',
          style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
        ),
      ],
    );
  }

  static String _dayLabel(int weekday) => switch (weekday) {
    1 => 'Mon',
    2 => 'Tue',
    3 => 'Wed',
    4 => 'Thu',
    5 => 'Fri',
    6 => 'Sat',
    _ => 'Sun',
  };

  static String _mealLabel(int index) => switch (index) {
    0 => 'Breakfast',
    1 => 'Lunch',
    2 => 'Dinner',
    _ => 'Meal ${index + 1}',
  };
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool dimmed;

  const _SectionLabel({required this.text, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: theme.textTheme.h2.copyWith(
          color: dimmed ? ext.textDisabled : null,
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: enabled ? theme.colorScheme.primary : ext.textDisabled,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyStrong.copyWith(
                      color: enabled ? null : ext.textDisabled,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.caption),
                ],
              ),
            ),
            Switch(
              value: value && enabled,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.16)
              : ext.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : ext.hairline,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.caption.copyWith(
            color: selected ? theme.colorScheme.primary : null,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onPick;

  const _TimeRow({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.body)),
        TextButton(
          onPressed: () async {
            final parts = value.split(':');
            final initial = TimeOfDay(
              hour: int.tryParse(parts.first) ?? 8,
              minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
            );
            final picked = await showTimePicker(
              context: context,
              initialTime: initial,
            );
            if (picked == null) return;
            onPick(
              '${picked.hour.toString().padLeft(2, '0')}:'
              '${picked.minute.toString().padLeft(2, '0')}',
            );
          },
          child: Text(
            value,
            style: theme.textTheme.bodyStrong.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
