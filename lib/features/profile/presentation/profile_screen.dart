import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/application/providers/app_reset.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/collapsible_group.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/states.dart';
import 'package:fitpilot/core/ui/select_chip.dart';
import 'package:fitpilot/features/settings/presentation/notification_prefs_screen.dart' as fitpilot_settings;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageFocusNode = FocusNode();

  late TextEditingController _goalWeightCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _toleranceCtrl;
  late TextEditingController _overrideCtrl;

  Gender _gender = Gender.unspecified;
  ActivityLevel _activityLevel = ActivityLevel.light;
  Goal _goal = Goal.maintain;
  Set<String> _equipment = {};

  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _goalWeightCtrl.dispose();
    _ageCtrl.dispose();
    _toleranceCtrl.dispose();
    _overrideCtrl.dispose();
    _ageFocusNode.dispose();
    super.dispose();
  }

  int? _lastProfileHash;

  void _initForm(Profile profile) {
    if (_initialized && _lastProfileHash == profile.hashCode) return;

    if (!_initialized) {
      _goalWeightCtrl = TextEditingController(text: profile.goalWeightKg?.toString() ?? '');
      _ageCtrl = TextEditingController(text: profile.age.toString());
      _toleranceCtrl = TextEditingController(text: profile.allowanceKcal.toString());
      _overrideCtrl = TextEditingController(text: profile.targetOverride?.toString() ?? '');

      _ageCtrl.addListener(() => setState(() {}));
      _toleranceCtrl.addListener(() => setState(() {}));
      _overrideCtrl.addListener(() => setState(() {}));
    } else {
      _goalWeightCtrl.text = profile.goalWeightKg?.toString() ?? '';
      _ageCtrl.text = profile.age.toString();
      _toleranceCtrl.text = profile.allowanceKcal.toString();
      _overrideCtrl.text = profile.targetOverride?.toString() ?? '';
    }

    _gender = profile.gender;
    _activityLevel = profile.activityLevel;
    _goal = profile.goal;
    _equipment = Set.from(profile.equipment);
    _lastProfileHash = profile.hashCode;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile & Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            _initForm(profile);
            if (!_isSaving && !_ageFocusNode.hasFocus) {
              final ageStr = profile.age.toString();
              if (_ageCtrl.text != ageStr) {
                _ageCtrl.text = ageStr;
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderAvatar(theme, ext, profile),
                const SizedBox(height: 24),
                _buildComputedTargetDisplay(theme, profile),
                const SizedBox(height: 24),

                CollapsibleGroup(
                  title: 'Account Settings',
                  icon: Icons.person_outline,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle('BODY', theme),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('AGE', _ageCtrl, _validateInt, focusNode: _ageFocusNode)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('GOAL WT (OPT)', _goalWeightCtrl, _validateOptDouble)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<Gender>(
                                initialValue: _gender,
                                decoration: const InputDecoration(labelText: 'GENDER'),
                                items: Gender.values.map((g) => DropdownMenuItem(value: g, child: Text(g.name[0].toUpperCase() + g.name.substring(1)))).toList(),
                                onChanged: (g) { if (g != null) setState(() => _gender = g); },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<Goal>(
                                initialValue: _goal,
                                decoration: const InputDecoration(labelText: 'GOAL'),
                                items: Goal.values.map((g) => DropdownMenuItem(value: g, child: Text(g.name[0].toUpperCase() + g.name.substring(1)))).toList(),
                                onChanged: (g) { if (g != null) setState(() => _goal = g); },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ActivityLevel>(
                          initialValue: _activityLevel,
                          decoration: const InputDecoration(labelText: 'ACTIVITY LEVEL'),
                          items: ActivityLevel.values.map((a) => DropdownMenuItem(value: a, child: Text(a.name[0].toUpperCase() + a.name.substring(1)))).toList(),
                          onChanged: (a) { if (a != null) setState(() => _activityLevel = a); },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField('WIGGLE ROOM (KCAL)', _toleranceCtrl, _validateTolerance),
                        const SizedBox(height: 16),
                        _buildTextField('TARGET OVERRIDE (OPT)', _overrideCtrl, _validateOverride),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Manage Equipment', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          trailing: Icon(Icons.chevron_right, color: theme.textTheme.bodySmall?.color),
                          onTap: _showEquipmentSheet,
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Save Account Settings',
                          onPressed: _save,
                          isLoading: _isSaving,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                CollapsibleGroup(
                  title: 'Preferences',
                  icon: Icons.tune,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Theme Mode', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<ThemeModePref>(
                          value: profile.themeMode,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: ThemeModePref.system, child: Text('System')),
                            DropdownMenuItem(value: ThemeModePref.light, child: Text('Light')),
                            DropdownMenuItem(value: ThemeModePref.dark, child: Text('Dark')),
                          ],
                          onChanged: (v) {
                            if (v != null) _updateProfile(profile.copyWith(themeMode: v));
                          },
                        ),
                      ),
                      Divider(color: theme.dividerColor, height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Theme Color', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<String>(
                          value: const ['orange', 'blue', 'purple', 'green', 'red'].contains(profile.themeColor) ? profile.themeColor : 'orange',
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'orange', child: Text('Orange')),
                            DropdownMenuItem(value: 'blue', child: Text('Blue')),
                            DropdownMenuItem(value: 'purple', child: Text('Purple')),
                            DropdownMenuItem(value: 'green', child: Text('Green')),
                            DropdownMenuItem(value: 'red', child: Text('Red')),
                          ],
                          onChanged: (v) => _updateProfile(profile.copyWith(themeColor: v)),
                        ),
                      ),
                      Divider(color: theme.dividerColor, height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Plan Category', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<String>(
                          value: const ['recommended', 'cardio', 'strength', 'fun', 'core'].contains(profile.planCategoryPref) ? profile.planCategoryPref : 'recommended',
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'recommended', child: Text('Recommended')),
                            DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                            DropdownMenuItem(value: 'strength', child: Text('Strength')),
                            DropdownMenuItem(value: 'fun', child: Text('Fun')),
                            DropdownMenuItem(value: 'core', child: Text('Core')),
                          ],
                          onChanged: (v) => _updateProfile(profile.copyWith(planCategoryPref: v)),
                        ),
                      ),
                      Divider(color: theme.dividerColor, height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Plan Pace', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<String>(
                          value: const ['any', 'easy', 'moderate', 'quick'].contains(profile.planPacePref) ? profile.planPacePref : 'any',
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'any', child: Text('Any Pace')),
                            DropdownMenuItem(value: 'easy', child: Text('Easy')),
                            DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                            DropdownMenuItem(value: 'quick', child: Text('Quick')),
                          ],
                          onChanged: (v) => _updateProfile(profile.copyWith(planPacePref: v)),
                        ),
                      ),
                      Divider(color: theme.dividerColor, height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Notifications', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: Icon(Icons.chevron_right, color: theme.textTheme.bodySmall?.color),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const fitpilot_settings.NotificationPrefsScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                CollapsibleGroup(
                  title: 'App Settings',
                  icon: Icons.settings,
                  child: Column(
                    children: [

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Unit', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<String>(
                          value: const ['kg', 'lb'].contains(profile.unitKgLb) ? profile.unitKgLb : 'kg',
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                            DropdownMenuItem(value: 'lb', child: Text('Pounds (lb)')),
                          ],
                          onChanged: (v) => _updateProfile(profile.copyWith(unitKgLb: v)),
                        ),
                      ),
                      Divider(color: theme.dividerColor, height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Week Starts On', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<bool>(
                          value: profile.weekStartsMon,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('Monday')),
                            DropdownMenuItem(value: false, child: Text('Sunday')),
                          ],
                          onChanged: (v) => _updateProfile(profile.copyWith(weekStartsMon: v)),
                        ),
                      ),
                      Divider(color: theme.dividerColor, height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Haptics', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        value: profile.hapticsOn,
                        activeThumbColor: theme.colorScheme.primary,
                        onChanged: (v) => _updateProfile(profile.copyWith(hapticsOn: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildAuthSection(context, theme),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => EmptyState(
            illustration: 'target',
            message: e.toString(),
            buttonLabel: 'Retry',
            onAction: () => ref.invalidate(profileProvider),
          ),
        ),
      ),
    );
  }

  void _updateProfile(Profile newProfile) async {
    await ref.read(profileRepositoryProvider.future).then((r) => r.save(newProfile));
    ref.invalidate(profileProvider);
  }

  Widget _buildHeaderAvatar(ThemeData theme, AppColors ext, Profile profile) {
    final session = ref.watch(currentUserProvider);
    final hasName = profile.name != null && profile.name!.isNotEmpty;
    
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(color: ext.hairline, width: 2),
          ),
          child: Center(
            child: Text(
              hasName ? profile.name![0].toUpperCase() : 'U',
              style: theme.textTheme.displayMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          hasName ? profile.name! : 'User Profile',
          style: theme.textTheme.h2.copyWith(fontSize: 24),
        ),
        if (session != null) ...[
          const SizedBox(height: 4),
          Text(
            session.email,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ],
    );
  }



  Widget _buildComputedTargetDisplay(ThemeData theme, Profile profile) {
    final ext = theme.extension<AppColors>()!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_fire_department_rounded, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY CALORIE BASELINE',
                      style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total Daily Energy Expenditure (TDEE)',
                      style: theme.textTheme.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${profile.tdee}',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'kcal / day',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ext.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ext.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your first ${profile.allowanceKcal} kcal each day are "wiggle room" before burn plans trigger.',
                    style: theme.textTheme.caption.copyWith(height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.labelSmall),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: theme.dividerColor)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String? Function(String?) validator, {FocusNode? focusNode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        AppTextField(
          label: "",
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildAuthSection(BuildContext context, ThemeData theme) {
    final session = ref.watch(currentUserProvider);
    final ext = theme.extension<AppColors>()!;
    final currentProfile = ref.watch(profileProvider).value;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ext.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ext.hairline),
            ),
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final avatarUrl = session.metadata['avatar_url'] as String?;
                    if (avatarUrl != null && avatarUrl.isNotEmpty) {
                      return CircleAvatar(
                        backgroundImage: NetworkImage(avatarUrl),
                      );
                    }
                    return CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: theme.colorScheme.primary),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentProfile?.name ?? 'Signed in', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                      Text(
                        session.email,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                ),
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out? Your progress will be securely saved in the cloud.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    
                    ref.read(syncTriggerManagerProvider)?.pause();
                    final db = await ref.read(databaseProvider.future);
                    await AppDatabase.clearUserData(db);
                    await ref.read(authRepositoryProvider).signOut();
                    resetApplicationState(ref);
                    if (context.mounted) {
                      context.go('/welcome');
                    }
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final syncState = ref.watch(syncStatusProvider).valueOrNull;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    (syncState?.state == SyncState.syncing) ? Icons.sync : ((syncState?.error != null) ? Icons.sync_problem : Icons.cloud_done),
                    size: 14,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (syncState?.state == SyncState.syncing) 
                        ? 'Syncing...' 
                        : ((syncState?.error != null) ? 'Sync Failed' : 'Synced'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'Change Password',
            onPressed: () => context.push('/change-password'),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Delete Account',
            onPressed: _showDeleteAccountDialog,
            // We can style it red if desired, but default secondary is okay
          ),
        ] else ...[
          PrimaryButton(
            label: 'Sign In / Create Account',
            onPressed: () => context.push('/auth?hideGuest=true'),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to sync your data across devices.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  void _showDeleteAccountDialog() {
    bool loading = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Account'),
              content: const Text(
                'Are you sure you want to delete your account? This action cannot be undone and will permanently erase all your data.',
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                    onPressed: loading ? null : () async {
                      setDialogState(() => loading = true);
                      try {
                        ref.read(syncTriggerManagerProvider)?.pause();
                        final db = await ref.read(databaseProvider.future);
                        await AppDatabase.clearUserData(db);
                        try {
                          await ref.read(authRepositoryProvider).deleteAccount();
                        } catch (_) {
                          await ref.read(authRepositoryProvider).signOut();
                        }
                        resetApplicationState(ref);
                        if (context.mounted) {
                          Navigator.pop(context);
                          AppSnackbar.success(context, 'Account deleted successfully.');
                          context.go('/welcome');
                        }
                      } catch (e) {
                        setDialogState(() => loading = false);
                        if (context.mounted) {
                          AppSnackbar.error(context, e.toString());
                        }
                      }
                    },
                  child: loading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Delete Permanently', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEquipmentSheet() {
    AppBottomSheet.show(
      context,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final opts = ['dumbbells', 'kettlebell', 'pullup_bar', 'bench', 'resistance_bands'];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Equipment Available', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: opts.map((e) {
                  final label = e.replaceAll('_', ' ');
                  final isSelected = _equipment.contains(e);
                  return SelectChip(
                    label: label,
                    isSelected: isSelected,
                    onSelected: () {
                      setModalState(() {
                        if (isSelected) {
                          _equipment.remove(e);
                        } else {
                          _equipment.add(e);
                        }
                      });
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.pop(context),
              )
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      final currentProfile = await repo.get();
      if (currentProfile == null) throw Exception('Profile not found');

      final overrideVal = _overrideCtrl.text.trim();

      final updated = currentProfile.copyWith(
        goalWeightKg: _goalWeightCtrl.text.isEmpty ? null : double.parse(_goalWeightCtrl.text),
        age: int.parse(_ageCtrl.text),
        gender: _gender,
        goal: _goal,
        activityLevel: _activityLevel,
        allowanceKcal: int.parse(_toleranceCtrl.text),
        targetOverride: overrideVal.isEmpty ? null : int.parse(overrideVal),
        clearOverride: overrideVal.isEmpty,
        equipment: _equipment.toList(),
      );

      await repo.save(updated);
      ref.invalidate(profileProvider);
      
      if (mounted) {
        AppSnackbar.success(context, 'Account details saved');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateOptDouble(String? v) {
    if (v == null || v.isEmpty) return null;
    final d = double.tryParse(v);
    if (d == null) return 'Invalid number';
    if (d < 25 || d > 300) return '25-300 kg only';
    return null;
  }

  String? _validateInt(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final i = int.tryParse(v);
    if (i == null) return 'Invalid number';
    if (i < 13 || i > 250) return 'Out of bounds';
    return null;
  }

  String? _validateTolerance(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final i = int.tryParse(v);
    if (i == null) return 'Invalid number';
    if (i < 0 || i > 2000) return '0-2000 only';
    return null;
  }

  String? _validateOverride(String? v) {
    if (v == null || v.isEmpty) return null;
    final i = int.tryParse(v);
    if (i == null) return 'Invalid number';
    if (i < 1000 || i > 5000) return '1000-5000 only';
    return null;
  }
}
