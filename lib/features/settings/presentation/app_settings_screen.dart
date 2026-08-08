import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/notification_prefs_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/data/services/data_export_service.dart';
import 'package:fitpilot/domain/entities/profile.dart';

/// App-wide settings that are not about the user's body.
///
/// Everything here writes through to the database immediately — there is no
/// save button, because a settings screen that can be left in an unsaved state
/// is a settings screen that silently loses changes.
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load settings.\n$e')),
        data: (profile) => _Body(profile: profile),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final Profile profile;

  const _Body({required this.profile});

  Future<void> _saveProfile(WidgetRef ref, Profile updated) async {
    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.save(updated);
    ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final notifPrefs = ref.watch(notificationPrefsProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Section(label: 'Units & display'),
        _ChoiceRow(
          icon: Icons.straighten_rounded,
          title: 'Weight unit',
          value: profile.unitKgLb == 'kg' ? 'Kilograms' : 'Pounds',
          options: const {'kg': 'Kilograms (kg)', 'lb': 'Pounds (lb)'},
          selected: profile.unitKgLb,
          onSelect: (v) =>
              _saveProfile(ref, profile.copyWith(unitKgLb: v)),
        ),
        _ChoiceRow(
          icon: Icons.calendar_today_rounded,
          title: 'Week starts on',
          value: profile.weekStartsMon ? 'Monday' : 'Sunday',
          options: const {'mon': 'Monday', 'sun': 'Sunday'},
          selected: profile.weekStartsMon ? 'mon' : 'sun',
          onSelect: (v) =>
              _saveProfile(ref, profile.copyWith(weekStartsMon: v == 'mon')),
        ),
        _SwitchRow(
          icon: Icons.vibration_rounded,
          title: 'Haptic feedback',
          subtitle: 'Small vibrations on key actions',
          value: profile.hapticsOn,
          onChanged: (v) async {
            if (v) HapticFeedback.selectionClick();
            await _saveProfile(ref, profile.copyWith(hapticsOn: v));
          },
        ),

        const SizedBox(height: 20),
        _Section(label: 'Notifications'),
        _NavRow(
          icon: Icons.notifications_active_rounded,
          title: 'Reminders',
          subtitle: notifPrefs == null
              ? 'Meal, burn, streak and weigh-in reminders'
              : notifPrefs.globalMute
              ? 'All muted'
              : '${notifPrefs.enabledCount} of 7 switched on',
          onTap: () => context.push('/settings/notifications'),
        ),

        const SizedBox(height: 20),
        _Section(label: 'Your data'),
        _NavRow(
          icon: Icons.download_rounded,
          title: 'Export my data',
          subtitle: 'Save your logs, weights and settings as a JSON file',
          onTap: () => _exportData(context, ref),
        ),
        _NavRow(
          icon: Icons.cloud_sync_rounded,
          title: 'Sync',
          subtitle: 'Your data is stored on this device first, then backed up',
          onTap: () => _showSyncInfo(context),
        ),

        const SizedBox(height: 20),
        _Section(label: 'About'),
        _NavRow(
          icon: Icons.info_outline_rounded,
          title: 'About FitPilot',
          subtitle: 'Version 1.0.0',
          onTap: () => _showAbout(context),
        ),
        _NavRow(
          icon: Icons.description_outlined,
          title: 'Open-source licences',
          subtitle: 'The libraries this app is built on',
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'FitPilot',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2026 Muhammad Anees',
          ),
        ),
        _NavRow(
          icon: Icons.photo_library_outlined,
          title: 'Image credits',
          subtitle: 'Photographers behind the food photos',
          onTap: () => context.push('/settings/credits'),
        ),

        const SizedBox(height: 24),
        Text(
          'FitPilot keeps your logs on this device. Food photos and machine '
          'scans are sent for analysis only when you ask for them, and are '
          'never stored on a server.',
          style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
        ),
      ],
    );
  }

  /// Writes the export and tells the user exactly where it landed.
  ///
  /// On web there is no filesystem, so the JSON goes to the clipboard instead —
  /// the feature works everywhere rather than being hidden on one platform.
  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = await ref.read(databaseProvider.future);
      final service = DataExportService(db);
      final counts = await service.summary();
      final total = counts.values.fold<int>(0, (a, b) => a + b);

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Export your data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$total rows across ${counts.length} tables:'),
              const SizedBox(height: 10),
              for (final entry in counts.entries)
                if (entry.value > 0)
                  Text(
                    '• ${entry.value} ${_friendlyTable(entry.key)}',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Export'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final path = await service.writeToFile();
      if (path == null) {
        final json = await service.buildJson();
        await Clipboard.setData(ClipboardData(text: json));
        messenger.showSnackBar(
          const SnackBar(content: Text('Export copied to the clipboard')),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved to $path'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Copy path',
            onPressed: () => Clipboard.setData(ClipboardData(text: path)),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, "Couldn't export your data.");
      }
    }
  }

  static String _friendlyTable(String table) => switch (table) {
    'profile' => 'profile',
    'food_logs' => 'food logs',
    'burn_completions' => 'completed burns',
    'weight_entries' => 'weight entries',
    'program_completions' => 'programme days',
    'saved_products' => 'saved products',
    'notification_prefs' => 'notification settings',
    _ => table,
  };

  void _showSyncInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How syncing works'),
        content: Text(
          'Everything you log is written to this device first, so the app works '
          'with no connection.\n\n'
          'When you are signed in and online, changes are pushed to your account '
          'in the background and pulled back on your other devices.\n\n'
          'Machine scans, coach chats and notifications stay on this device only.',
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'FitPilot',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 Muhammad Anees',
      children: [
        const SizedBox(height: 12),
        const Text(
          'Eat it. Burn it.\n\n'
          'Log what you eat, then work off the surplus with a plan built around '
          'the equipment you actually have.',
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String label;

  const _Section({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: Theme.of(context).textTheme.h2),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyStrong),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyStrong),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.caption),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A row that opens a small picker sheet. Used where a dropdown inside a
/// scrolling settings list would be fiddly to hit on a phone.
class _ChoiceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _pick(context),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: theme.textTheme.bodyStrong)),
            Text(
              value,
              style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(title, style: Theme.of(sheetContext).textTheme.h2),
            const SizedBox(height: 8),
            for (final entry in options.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == selected
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != selected) onSelect(chosen);
  }
}
