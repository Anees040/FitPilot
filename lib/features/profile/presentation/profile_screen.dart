import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/engines/target_calculator.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/collapsible_group.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/buttons.dart';

import 'package:fitpilot/features/settings/presentation/notification_prefs_screen.dart' as fitpilot_settings;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile & Settings', style: theme.textTheme.h1),
        centerTitle: false,
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => _buildBody(context, ref, profile),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Profile profile) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildComputedTargetDisplay(theme, profile),
        const SizedBox(height: 24),
        
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person, color: theme.colorScheme.primary),
          title: Text('Edit Profile', style: theme.textTheme.bodyStrong),
          trailing: Icon(Icons.chevron_right, color: theme.textTheme.caption.color),
          onTap: () => context.push('/profile/edit'),
        ),
        Divider(color: theme.dividerColor, height: 1),
        
        CollapsibleGroup(
          title: 'Display & Unit',
          icon: Icons.palette_outlined,
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Theme', style: theme.textTheme.bodyStrong),
                trailing: DropdownButton<ThemeModePref>(
                  value: profile.themeMode,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: ThemeModePref.system, child: Text('System')),
                    DropdownMenuItem(value: ThemeModePref.light, child: Text('Light')),
                    DropdownMenuItem(value: ThemeModePref.dark, child: Text('Dark')),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await ref.read(profileRepositoryProvider.future).then((r) => r.save(profile.copyWith(themeMode: v)));
                      ref.invalidate(profileProvider);
                    }
                  },
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Unit', style: theme.textTheme.bodyStrong),
                trailing: DropdownButton<String>(
                  value: profile.unitKgLb,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                    DropdownMenuItem(value: 'lb', child: Text('Pounds (lb)')),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await ref.read(profileRepositoryProvider.future).then((r) => r.save(profile.copyWith(unitKgLb: v)));
                      ref.invalidate(profileProvider);
                    }
                  },
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Week Starts On', style: theme.textTheme.bodyStrong),
                trailing: DropdownButton<bool>(
                  value: profile.weekStartsMon,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Monday')),
                    DropdownMenuItem(value: false, child: Text('Sunday')),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await ref.read(profileRepositoryProvider.future).then((r) => r.save(profile.copyWith(weekStartsMon: v)));
                      ref.invalidate(profileProvider);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        CollapsibleGroup(
          title: 'App Settings',
          icon: Icons.settings_outlined,
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Notifications', style: theme.textTheme.bodyStrong),
                trailing: Icon(Icons.chevron_right, color: theme.textTheme.caption.color),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const fitpilot_settings.NotificationPrefsScreen()),
                  );
                },
              ),
              Divider(color: theme.dividerColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Plan Category', style: theme.textTheme.bodyStrong),
                trailing: DropdownButton<String>(
                  value: profile.planCategoryPref,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'recommended', child: Text('Recommended')),
                    DropdownMenuItem(value: 'gym', child: Text('Gym')),
                    DropdownMenuItem(value: 'indoor', child: Text('Indoor')),
                    DropdownMenuItem(value: 'outdoor', child: Text('Outdoor')),
                    DropdownMenuItem(value: 'calisthenics', child: Text('Calisthenics')),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await ref.read(profileRepositoryProvider.future).then((r) => r.save(profile.copyWith(planCategoryPref: v)));
                      ref.invalidate(profileProvider);
                    }
                  },
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Plan Pace', style: theme.textTheme.bodyStrong),
                trailing: DropdownButton<String>(
                  value: profile.planPacePref,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'any', child: Text('Any pace')),
                    DropdownMenuItem(value: 'quick', child: Text('Quick burn')),
                    DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                    DropdownMenuItem(value: 'easy', child: Text('Easy pace')),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      await ref.read(profileRepositoryProvider.future).then((r) => r.save(profile.copyWith(planPacePref: v)));
                      ref.invalidate(profileProvider);
                    }
                  },
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Haptics', style: theme.textTheme.bodyStrong),
                trailing: Switch(
                  value: profile.hapticsOn,
                  onChanged: (v) async {
                    await ref.read(profileRepositoryProvider.future).then((r) => r.save(profile.copyWith(hapticsOn: v)));
                    ref.invalidate(profileProvider);
                  },
                  activeThumbColor: theme.colorScheme.primary,
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Export Data', style: theme.textTheme.bodyStrong),
                trailing: Icon(Icons.download, color: theme.colorScheme.primary),
                onTap: () {
                  debugPrint('Exporting data...');
                  AppSnackbar.success(context, 'Data exported to console');
                },
              ),
              Divider(color: theme.dividerColor, height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('About & Attributions', style: theme.textTheme.bodyStrong),
                trailing: Icon(Icons.chevron_right, color: theme.textTheme.caption.color),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'FitPilot',
                    applicationVersion: '1.0.0',
                    children: const [
                      SizedBox(height: 16),
                      Text('Media assets sourced from SVGRepo and Giphy/Tenor.\nAll rights belong to their respective creators.\n\nFonts by Google Fonts (Inter).'),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildAuthSection(context, ref, theme),
      ],
    );
  }

  Widget _buildComputedTargetDisplay(ThemeData theme, Profile profile) {
    const calc = TargetCalculator();
    final bmr = calc.bmr(weightKg: profile.weightKg, heightCm: profile.heightCm.toDouble(), age: profile.age, gender: profile.gender).round();
    final tdee = calc.tdee(bmr.toDouble(), profile.activityLevel).round();
    final daily = calc.dailyTarget(tdeeValue: tdee.toDouble(), goal: profile.goal, gender: profile.gender);
    final isCustom = profile.targetOverride != null;
    final effective = isCustom ? profile.targetOverride! : daily;
    final ext = theme.extension<AppColors>()!;

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('BMR', bmr.toString(), theme),
              _buildStat('TDEE', tdee.toString(), theme),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 16),
          Text('DAILY TARGET', style: theme.textTheme.overline),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                effective.toString(),
                style: theme.textTheme.display.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text('kcal', style: theme.textTheme.body),
              ),
            ],
          ),
          if (isCustom)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('(Custom Override)', style: theme.textTheme.caption.copyWith(color: ext.warning)),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String val, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.overline),
        const SizedBox(height: 4),
        Text(val, style: theme.textTheme.h2),
      ],
    );
  }

  Widget _buildAuthSection(BuildContext context, WidgetRef ref, ThemeData theme) {
    final ext = theme.extension<AppColors>()!;
    final authUser = ref.watch(currentUserProvider);

    if (authUser == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: theme.dividerColor),
          const SizedBox(height: 16),
          Text(
            'Sign in to sync your progress across devices.',
            style: theme.textTheme.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'Sign in / Create Account',
            onPressed: () => context.push('/signin'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: theme.dividerColor),
        const SizedBox(height: 16),
        Text('Signed in as: ${authUser.email}', style: theme.textTheme.bodyStrong),
        const SizedBox(height: 8),
        _buildSyncStatus(context, ref, theme),
        const SizedBox(height: 16),
        TertiaryButton(
          label: 'Sign Out',
          onPressed: () async {
            try {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) {
                AppSnackbar.success(context, 'Signed out successfully.');
              }
            } catch (e) {
              if (context.mounted) {
                AppSnackbar.error(context, 'Error signing out.');
              }
            }
          },
          color: ext.error,
        ),
      ],
    );
  }

  Widget _buildSyncStatus(BuildContext context, WidgetRef ref, ThemeData theme) {
    final ext = theme.extension<AppColors>()!;
    final statusAsync = ref.watch(syncStatusProvider);

    return statusAsync.when(
      data: (status) {
        String msg = 'Syncing...';
        Color c = theme.colorScheme.primary;
        if (status.error != null) {
          msg = 'Sync error: ${status.error}';
          c = ext.error;
        } else if (status.state != SyncState.syncing) {
          if (status.lastSuccessfulSync != null) {
            msg = 'Last synced: ${status.lastSuccessfulSync!.toLocal().toString().split('.')[0]}';
          } else {
            msg = 'Ready to sync';
          }
          c = ext.success;
        }

        return Row(
          children: [
            Icon(Icons.sync, size: 16, color: c),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: theme.textTheme.caption.copyWith(color: c))),
          ],
        );
      },
      loading: () => Text('Sync initializing...', style: theme.textTheme.caption),
      error: (e, st) => Text('Sync unavailable', style: theme.textTheme.caption.copyWith(color: ext.error)),
    );
  }
}
