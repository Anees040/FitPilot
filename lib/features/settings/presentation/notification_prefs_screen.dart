import 'package:flutter/material.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/notification_prefs_provider.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/data/notifications/notification_service.dart';

class NotificationPrefsScreen extends ConsumerWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
          title: Text('Mute All Notifications', style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text('Temporarily disable all alerts', style: Theme.of(context).textTheme.bodySmall!),
          value: prefs.globalMute,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: (val) async {
            if (val) {
              await ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(globalMute: true));
            } else {
              final granted = await ref.read(notificationServiceProvider).requestPermissions();
              if (granted) {
                await ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(globalMute: false));
              } else {
                if (context.mounted) {
                  AppSnackbar.warning(context, 'Permission denied by OS.');
                }
              }
            }
          },
        ),
        const Divider(),
        SwitchListTile(
          title: Text('Meal Reminders', style: Theme.of(context).textTheme.bodyLarge!),
          subtitle: Text('Remind me if I forget to log my meals', style: Theme.of(context).textTheme.bodySmall!),
          value: prefs.mealRemindersEnabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: prefs.globalMute ? null : (val) {
            ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(mealRemindersEnabled: val));
          },
        ),
        if (prefs.mealRemindersEnabled)
          ...prefs.mealTimes.asMap().entries.map((entry) {
            final idx = entry.key;
            final timeStr = entry.value;
            return ListTile(
              title: Text('Meal ${idx + 1} Time', style: Theme.of(context).textTheme.bodyLarge!),
              trailing: Text(timeStr, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.primary)),
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
          title: Text('Streak Risk Alerts', style: Theme.of(context).textTheme.bodyLarge!),
          subtitle: Text('Alert me 8 hours before my grace period expires', style: Theme.of(context).textTheme.bodySmall!),
          value: prefs.streakRiskEnabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: prefs.globalMute ? null : (val) {
            ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(streakRiskEnabled: val));
          },
        ),
        SwitchListTile(
          title: Text('Milestone Celebrations', style: Theme.of(context).textTheme.bodyLarge!),
          subtitle: Text('Celebrate when I hit a 7-day streak', style: Theme.of(context).textTheme.bodySmall!),
          value: prefs.milestonesEnabled,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: prefs.globalMute ? null : (val) {
            ref.read(notificationPrefsProvider.notifier).updatePrefs(prefs.copyWith(milestonesEnabled: val));
          },
        ),
      ],
    );
  }
}
