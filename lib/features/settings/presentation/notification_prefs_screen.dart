import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/notification_prefs_provider.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/data/notifications/notification_service.dart';

class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.text,
      ),
      body: prefsAsync.when(
        data: (prefs) => _buildBody(context, ref, prefs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, NotificationPreferences prefs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: Text('Mute All Notifications', style: AppTheme.body.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text('Temporarily disable all alerts', style: AppTheme.caption),
          value: prefs.globalMute,
          activeThumbColor: AppTheme.accent,
          onChanged: (val) async {
            if (val) {
              await ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(globalMute: true));
            } else {
              final granted = await ref.read(notificationServiceProvider).requestPermissions();
              if (granted) {
                await ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(globalMute: false));
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission denied by OS.')),
                  );
                }
              }
            }
          },
        ),
        const Divider(),
        SwitchListTile(
          title: Text('Meal Reminders', style: AppTheme.body),
          subtitle: Text('Remind me if I forget to log my meals', style: AppTheme.caption),
          value: prefs.mealRemindersEnabled,
          activeThumbColor: AppTheme.accent,
          onChanged: prefs.globalMute ? null : (val) {
            ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(mealRemindersEnabled: val));
          },
        ),
        if (prefs.mealRemindersEnabled)
          ...prefs.mealTimes.asMap().entries.map((entry) {
            final idx = entry.key;
            final timeStr = entry.value;
            return ListTile(
              title: Text('Meal ${idx + 1} Time', style: AppTheme.body),
              trailing: Text(timeStr, style: AppTheme.body.copyWith(color: AppTheme.accent)),
              onTap: prefs.globalMute ? null : () async {
                final parts = timeStr.split(':');
                final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                final newTime = await showTimePicker(context: context, initialTime: initialTime);
                if (newTime != null) {
                  final newTimes = List<String>.from(prefs.mealTimes);
                  newTimes[idx] = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
                  ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(mealTimes: newTimes));
                }
              },
            );
          }),
        const Divider(),
        SwitchListTile(
          title: Text('Streak Risk Alerts', style: AppTheme.body),
          subtitle: Text('Alert me 8 hours before my grace period expires', style: AppTheme.caption),
          value: prefs.streakRiskEnabled,
          activeThumbColor: AppTheme.accent,
          onChanged: prefs.globalMute ? null : (val) {
            ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(streakRiskEnabled: val));
          },
        ),
        SwitchListTile(
          title: Text('Milestone Celebrations', style: AppTheme.body),
          subtitle: Text('Celebrate when I hit a 7-day streak', style: AppTheme.caption),
          value: prefs.milestonesEnabled,
          activeThumbColor: AppTheme.accent,
          onChanged: prefs.globalMute ? null : (val) {
            ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(milestonesEnabled: val));
          },
        ),
      ],
    );
  }
}
