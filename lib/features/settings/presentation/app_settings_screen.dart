import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/notification_prefs_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/core/ui/profile_avatar.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/application/providers/protein_provider.dart';
import 'package:fitpilot/data/services/data_export_service.dart';
import 'package:fitpilot/features/log/presentation/widgets/protein_info_sheet.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _ProfileHeader(profile: profile),
        const SizedBox(height: 24),

        _SectionLabel('Units & display'),
        _SettingsGroup(
          children: [
            _ChoiceRow(
              icon: Icons.straighten_rounded,
              tint: _Tint.blue,
              title: 'Weight unit',
              value: profile.unitKgLb == 'kg' ? 'Kilograms' : 'Pounds',
              options: const {'kg': 'Kilograms (kg)', 'lb': 'Pounds (lb)'},
              selected: profile.unitKgLb,
              onSelect: (v) => _saveProfile(ref, profile.copyWith(unitKgLb: v)),
            ),
            _ChoiceRow(
              icon: Icons.calendar_today_rounded,
              tint: _Tint.blue,
              title: 'Week starts on',
              value: profile.weekStartsMon ? 'Monday' : 'Sunday',
              options: const {'mon': 'Monday', 'sun': 'Sunday'},
              selected: profile.weekStartsMon ? 'mon' : 'sun',
              onSelect: (v) =>
                  _saveProfile(ref, profile.copyWith(weekStartsMon: v == 'mon')),
            ),
            _SwitchRow(
              icon: Icons.vibration_rounded,
              tint: _Tint.blue,
              title: 'Haptic feedback',
              subtitle: 'Small vibrations on key actions',
              value: profile.hapticsOn,
              onChanged: (v) async {
                if (v) HapticFeedback.selectionClick();
                await _saveProfile(ref, profile.copyWith(hapticsOn: v));
              },
            ),
          ],
        ),

        const SizedBox(height: 22),
        _SectionLabel('Nutrition'),
        _SettingsGroup(
          children: [
            _ProteinGoalRow(profile: profile),
            _NavRow(
              icon: Icons.egg_alt_outlined,
              tint: _Tint.lime,
              title: 'Cheap protein guide',
              subtitle: 'Hit your target on daal, chana and eggs',
              onTap: () => context.push('/protein-guide'),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _SectionLabel('Notifications'),
        _SettingsGroup(
          children: [
            _NavRow(
              icon: Icons.notifications_active_rounded,
              tint: _Tint.accent,
              title: 'Reminders',
              subtitle: notifPrefs == null
                  ? 'Meal, burn, streak and weigh-in reminders'
                  : notifPrefs.globalMute
                  ? 'All muted'
                  : '${notifPrefs.enabledCount} of 7 switched on',
              // A settings row that reports its own state saves a tap just to
              // check whether anything is on.
              badge: notifPrefs != null && !notifPrefs.globalMute
                  ? '${notifPrefs.enabledCount}'
                  : null,
              onTap: () => context.push('/settings/notifications'),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _SectionLabel('Your data'),
        _SettingsGroup(
          children: [
            _NavRow(
              icon: Icons.download_rounded,
              tint: _Tint.green,
              title: 'Export my data',
              subtitle: 'Your logs and weights as a JSON file',
              onTap: () => _exportData(context, ref),
            ),
            _NavRow(
              icon: Icons.cloud_sync_rounded,
              tint: _Tint.green,
              title: 'How syncing works',
              subtitle: 'Device first, then backed up to your account',
              onTap: () => _showSyncInfo(context),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _SectionLabel('About'),
        _SettingsGroup(
          children: [
            _NavRow(
              icon: Icons.info_outline_rounded,
              tint: _Tint.neutral,
              title: 'About FitPilot',
              subtitle: 'Version 1.0.0',
              onTap: () => _showAbout(context),
            ),
            _NavRow(
              icon: Icons.photo_library_outlined,
              tint: _Tint.neutral,
              title: 'Photo credits',
              subtitle: 'Photographers behind the food photos',
              onTap: () => context.push('/settings/credits'),
            ),
            _NavRow(
              icon: Icons.description_outlined,
              tint: _Tint.neutral,
              title: 'Open-source licences',
              subtitle: 'The libraries this app is built on',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'FitPilot',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Muhammad Anees',
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: ext.textDisabled),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your logs stay on this device. Food photos and machine scans '
                'are sent for analysis only when you ask, and are never stored '
                'on a server.',
                style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
              ),
            ),
          ],
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

/// Protein goal with a stepper and a reset back to the recommendation.
///
/// The recommendation is 1.6 g/kg. Showing it alongside the override means a
/// user who has typed a number can always find their way back to a sane one.
/// Protein goal with a stepper and a reset back to the recommendation.
///
/// The recommendation is 1.6 g/kg. Showing it alongside the override means a
/// user who has typed a number can always find their way back to a sane one.
class _ProteinGoalRow extends ConsumerWidget {
  final Profile profile;

  const _ProteinGoalRow({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final recommended = ref.watch(recommendedProteinProvider);
    final target = ref.watch(proteinTargetProvider);
    final isOverridden = profile.proteinGoalG != null;

    Future<void> save(double? grams) async {
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.save(
        profile.copyWith(proteinGoalG: grams, clearProteinGoal: grams == null),
      );
      ref.invalidate(profileProvider);
    }

    if (target == null) {
      return _Row(
        icon: Icons.egg_alt_outlined,
        tint: _Tint.neutral,
        title: 'Daily protein goal',
        subtitle: 'Set your weight to get a target',
        onTap: () => context.push('/profile'),
        trailing: Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
      );
    }

    return Column(
      children: [
        _Row(
          icon: Icons.egg_alt_outlined,
          tint: _Tint.lime,
          title: 'Daily protein goal',
          subtitle: isOverridden && recommended != null
              ? 'Your own goal. We suggest ${recommended}g.'
              : '1.6 g per kg of bodyweight',
          // The (i) explains where the number comes from without stealing the
          // row's own tap target.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Lower',
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: target <= 40 ? null : () => save((target - 5).toDouble()),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${target}g',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyStrong.copyWith(color: ext.energy),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Raise',
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: target >= 250 ? null : () => save((target + 5).toDouble()),
              ),
            ],
          ),
          onTap: () => ProteinInfoSheet.show(context),
        ),
        if (isOverridden && recommended != null && target != recommended)
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => save(null),
                child: Text(
                  'Reset to ${recommended}g',
                  style: theme.textTheme.caption.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final IconData icon;
  final _Tint tint;
  final String title;
  final String value;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ChoiceRow({
    required this.icon,
    required this.tint,
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

    // Uses the shared row rather than its own card, so it sits inside a
    // _SettingsGroup with the same alignment as every other row.
    return _Row(
      icon: icon,
      tint: tint,
      title: title,
      onTap: () => _pick(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
        ],
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


/// Accent family for a row's icon tile.
///
/// Grouping settings by colour is what lets someone find "the green one about
/// my data" without reading every label. The row text stays monochrome so the
/// tile does that work alone.
enum _Tint { accent, lime, blue, green, neutral }

Color _tintColor(_Tint tint, ThemeData theme, AppColors ext) => switch (tint) {
  _Tint.accent => theme.colorScheme.primary,
  _Tint.lime => ext.energy,
  _Tint.blue => ext.highlight,
  _Tint.green => ext.success,
  _Tint.neutral => ext.textDisabled,
};

/// Card summarising who is signed in, so Settings opens with context rather
/// than a bare list of switches.
class _ProfileHeader extends ConsumerWidget {
  final Profile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final user = ref.watch(currentUserProvider);
    final name = profile.name?.trim();
    final email = user?.email ?? '';

    return AppCard(
      variant: AppCardVariant.hero,
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/profile'),
      child: Row(
        children: [
          ProfileAvatar(
            avatarUrl: profile.avatarUrl,
            name: profile.name,
            radius: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (name == null || name.isEmpty) ? 'Your profile' : name,
                  style: theme.textTheme.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email.isNotEmpty ? email : 'Guest account, not backed up',
                  style: theme.textTheme.caption.copyWith(
                    color: ext.textDisabled,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.overline.copyWith(
          color: ext.textDisabled,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Related rows in one card, separated by inset hairlines.
///
/// Replaces one card per row: a column of separate cards reads as a list of
/// unrelated things, and the gaps between them cost more vertical space than
/// the content does.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppColors>()!;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              // Inset to the text, not the card edge, so it reads as a
              // separator between rows rather than a border around one.
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: Divider(height: 1, thickness: 1, color: ext.hairline),
              ),
          ],
        ],
      ),
    );
  }
}

/// The tinted square that fronts every row.
class _RowIcon extends StatelessWidget {
  final IconData icon;
  final _Tint tint;

  const _RowIcon({required this.icon, required this.tint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final color = _tintColor(tint, theme, ext);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Shared row scaffold: icon, title, optional subtitle, optional trailing.
class _Row extends StatelessWidget {
  final IconData icon;
  final _Tint tint;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.tint,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            _RowIcon(icon: icon, tint: tint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.body),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final _Tint tint;
  final String title;
  final String subtitle;

  /// Optional count pill, for a row that can report its own state.
  final String? badge;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return _Row(
      icon: icon,
      tint: tint,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: theme.textTheme.overline.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Icon(Icons.chevron_right_rounded, color: ext.textDisabled),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final _Tint tint;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: icon,
      tint: tint,
      title: title,
      subtitle: subtitle,
      // Tapping the row toggles it, so the switch is not the only target.
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
