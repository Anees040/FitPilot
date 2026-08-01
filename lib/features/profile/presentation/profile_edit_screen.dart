import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/profile_edit_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/engines/target_calculator.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/collapsible_group.dart';
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/select_chip.dart';

import 'package:fitpilot/features/settings/presentation/notification_prefs_screen.dart' as fitpilot_settings;

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _weightCtrl;
  late TextEditingController _goalWeightCtrl;
  late TextEditingController _heightCtrl;
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
    _weightCtrl.dispose();
    _goalWeightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _toleranceCtrl.dispose();
    _overrideCtrl.dispose();
    super.dispose();
  }

  void _initForm(Profile profile) {
    if (_initialized) return;
    _weightCtrl = TextEditingController(text: profile.weightKg.toString());
    _goalWeightCtrl = TextEditingController(text: profile.goalWeightKg?.toString() ?? '');
    _heightCtrl = TextEditingController(text: profile.heightCm.toString());
    _ageCtrl = TextEditingController(text: profile.age.toString());
    _toleranceCtrl = TextEditingController(text: profile.allowanceKcal.toString());
    _overrideCtrl = TextEditingController(text: profile.targetOverride?.toString() ?? '');

    _gender = profile.gender;
    _activityLevel = profile.activityLevel;
    _goal = profile.goal;
    _equipment = Set.from(profile.equipment);

    _weightCtrl.addListener(() => setState(() {}));
    _heightCtrl.addListener(() => setState(() {}));
    _ageCtrl.addListener(() => setState(() {}));
    _toleranceCtrl.addListener(() => setState(() {}));
    _overrideCtrl.addListener(() => setState(() {}));

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: theme.textTheme.h1),
        centerTitle: false,
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            if (!_initialized) {
              _initForm(profile);
            } else if (!_isSaving) {
              final weightStr = profile.weightKg.toString();
              if (_weightCtrl.text != weightStr) {
                _weightCtrl.text = weightStr;
              }
            }
            return _buildForm(context, profile);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, Profile profile) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildComputedTargetDisplay(theme),
          const SizedBox(height: 24),

          CollapsibleGroup(
            title: 'Account',
            icon: Icons.person_outline,
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildSectionTitle('VITALS', theme),
                Row(
                  children: [
                    Expanded(child: _buildTextField('WEIGHT', _weightCtrl, _validateWeight)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('TARGET WT', _goalWeightCtrl, _validateGoalWeight)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField('HEIGHT (CM)', _heightCtrl, _validateHeight)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('AGE', _ageCtrl, _validateAge)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('GENDER', style: theme.textTheme.overline),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Gender.values.map((g) {
                    final label = g.name[0].toUpperCase() + g.name.substring(1);
                    return SelectChip(
                      label: label,
                      isSelected: _gender == g,
                      onSelected: () => setState(() => _gender = g),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                
                _buildSectionTitle('LIFESTYLE', theme),
                Text('ACTIVITY LEVEL', style: theme.textTheme.overline),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ActivityLevel.values.map((a) {
                    final label = a.name[0].toUpperCase() + a.name.substring(1);
                    return SelectChip(
                      label: label,
                      isSelected: _activityLevel == a,
                      onSelected: () => setState(() => _activityLevel = a),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('GOAL', style: theme.textTheme.overline),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Goal.values.map((g) {
                    final label = g.name[0].toUpperCase() + g.name.substring(1);
                    return SelectChip(
                      label: label,
                      isSelected: _goal == g,
                      onSelected: () => setState(() => _goal = g),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildTextField('CHEAT TOLERANCE (KCAL)', _toleranceCtrl, _validateTolerance),
                const SizedBox(height: 16),
                _buildTextField('TARGET OVERRIDE (OPT)', _overrideCtrl, _validateOverride),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Manage Equipment', style: theme.textTheme.bodyStrong),
                  trailing: Icon(Icons.chevron_right, color: theme.textTheme.caption.color),
                  onTap: _showEquipmentSheet,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Save Account Settings',
                  onPressed: _save,
                  isLoading: _isSaving,
                ),
                const SizedBox(height: 16),
                _buildAuthSection(context, theme),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CollapsibleGroup(
            title: 'Display',
            icon: Icons.palette_outlined,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Theme', style: theme.textTheme.bodyStrong),
                  trailing: DropdownButton<ThemeModePref>(
                    value: ref.watch(profileProvider).valueOrNull?.themeMode ?? ThemeModePref.system,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: ThemeModePref.system, child: Text('System')),
                      DropdownMenuItem(value: ThemeModePref.light, child: Text('Light')),
                      DropdownMenuItem(value: ThemeModePref.dark, child: Text('Dark')),
                    ],
                    onChanged: (v) async {
                      if (v != null) {
                        final p = ref.read(profileProvider).valueOrNull;
                        if (p != null) {
                          await ref.read(profileRepositoryProvider.future).then((r) => r.save(p.copyWith(themeMode: v)));
                          ref.invalidate(profileProvider);
                        }
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Unit', style: theme.textTheme.bodyStrong),
                  trailing: DropdownButton<String>(
                    value: ref.watch(profileProvider).valueOrNull?.unitKgLb ?? 'kg',
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                      DropdownMenuItem(value: 'lb', child: Text('Pounds (lb)')),
                    ],
                    onChanged: (v) async {
                      if (v != null) {
                        final p = ref.read(profileProvider).valueOrNull;
                        if (p != null) {
                          await ref.read(profileRepositoryProvider.future).then((r) => r.save(p.copyWith(unitKgLb: v)));
                          ref.invalidate(profileProvider);
                        }
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Week Starts On', style: theme.textTheme.bodyStrong),
                  trailing: DropdownButton<bool>(
                    value: ref.watch(profileProvider).valueOrNull?.weekStartsMon ?? true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Monday')),
                      DropdownMenuItem(value: false, child: Text('Sunday')),
                    ],
                    onChanged: (v) async {
                      if (v != null) {
                        final p = ref.read(profileProvider).valueOrNull;
                        if (p != null) {
                          await ref.read(profileRepositoryProvider.future).then((r) => r.save(p.copyWith(weekStartsMon: v)));
                          ref.invalidate(profileProvider);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CollapsibleGroup(
            title: 'App',
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
                    value: ref.watch(profileProvider).valueOrNull?.planCategoryPref ?? 'recommended',
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
                        final p = ref.read(profileProvider).valueOrNull;
                        if (p != null) {
                          await ref.read(profileRepositoryProvider.future).then((r) => r.save(p.copyWith(planCategoryPref: v)));
                          ref.invalidate(profileProvider);
                        }
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Plan Pace', style: theme.textTheme.bodyStrong),
                  trailing: DropdownButton<String>(
                    value: ref.watch(profileProvider).valueOrNull?.planPacePref ?? 'any',
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'any', child: Text('Any pace')),
                      DropdownMenuItem(value: 'quick', child: Text('Quick burn')),
                      DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                      DropdownMenuItem(value: 'easy', child: Text('Easy pace')),
                    ],
                    onChanged: (v) async {
                      if (v != null) {
                        final p = ref.read(profileProvider).valueOrNull;
                        if (p != null) {
                          await ref.read(profileRepositoryProvider.future).then((r) => r.save(p.copyWith(planPacePref: v)));
                          ref.invalidate(profileProvider);
                        }
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Haptics', style: theme.textTheme.bodyStrong),
                  trailing: Switch(
                    value: ref.watch(profileProvider).valueOrNull?.hapticsOn ?? true,
                    onChanged: (v) async {
                      final p = ref.read(profileProvider).valueOrNull;
                      if (p != null) {
                        await ref.read(profileRepositoryProvider.future).then((r) => r.save(p.copyWith(hapticsOn: v)));
                        ref.invalidate(profileProvider);
                      }
                    },
                    activeThumbColor: theme.colorScheme.primary,
                  ),
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
                        Text('''Media assets sourced from SVGRepo and Giphy/Tenor.
All rights belong to their respective creators.

Fonts by Google Fonts (Inter).'''),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAuthSection(BuildContext context, ThemeData theme) {
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
        _buildSyncStatus(context, theme),
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

  Widget _buildSyncStatus(BuildContext context, ThemeData theme) {
    final syncAsync = ref.watch(syncStatusProvider);
    if (!syncAsync.hasValue) return const SizedBox.shrink();

    final status = syncAsync.value!;
    String message;
    if (status.state == SyncState.syncing) {
      message = 'Syncing...';
    } else if (status.state == SyncState.error) {
      message = 'Sync error. Check connection.';
    } else if (status.pendingCount > 0) {
      message = '${status.pendingCount} changes waiting for network';
    } else {
      message = 'All changes saved';
    }

    return Text(
      message,
      style: theme.textTheme.caption,
    );
  }

  Widget _buildComputedTargetDisplay(ThemeData theme) {
    final weight = double.tryParse(_weightCtrl.text) ?? 70.0;
    final height = int.tryParse(_heightCtrl.text) ?? 170;
    final age = int.tryParse(_ageCtrl.text) ?? 25;
    final tolerance = int.tryParse(_toleranceCtrl.text) ?? 300;
    final overrideStr = _overrideCtrl.text.trim();
    final overrideKcal = overrideStr.isEmpty ? null : int.tryParse(overrideStr);

    const calc = TargetCalculator();
    final bmr = calc.bmr(
      weightKg: weight,
      heightCm: height.toDouble(),
      age: age,
      gender: _gender,
    );
    final tdee = calc.tdee(bmr, _activityLevel);
    final computedTarget = calc.dailyTarget(
      tdeeValue: tdee,
      goal: _goal,
      gender: _gender,
    );

    final finalTarget = overrideKcal ?? computedTarget;

    String explanation;
    if (overrideKcal != null) {
      explanation =
          'You have set a manual target of $overrideKcal kcal. You also have a $tolerance kcal cheat tolerance for when you exceed your target.';
    } else {
      final goalStr = _goal == Goal.lose
          ? 'lose weight'
          : _goal == Goal.build
          ? 'build muscle'
          : 'maintain';
      explanation =
          'Your body burns about ${tdee.round()} kcal a day at your activity level. Your goal is to $goalStr, so your target is $computedTarget kcal. You also have a $tolerance kcal cheat tolerance for when you exceed your target.';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DAILY TARGET', style: theme.textTheme.overline),
          const SizedBox(height: 8),
          Text('$finalTarget kcal', style: theme.textTheme.h1.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Text(explanation, style: theme.textTheme.caption),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: theme.textTheme.overline),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    String? Function(String?) validator,
  ) {
    return AppTextField(
      label: label,
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  String? _validateWeight(String? v) {
    final val = double.tryParse(v ?? '');
    if (val == null || val < 25 || val > 300) return '25–300 kg';
    return null;
  }
  String? _validateGoalWeight(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final val = double.tryParse(v);
    if (val == null || val < 25 || val > 300) return '25–300 kg';
    return null;
  }
  String? _validateHeight(String? v) {
    final val = int.tryParse(v ?? '');
    if (val == null || val < 100 || val > 250) return '100–250 cm';
    return null;
  }
  String? _validateAge(String? v) {
    final val = int.tryParse(v ?? '');
    if (val == null || val < 13 || val > 100) return '13–100 yrs';
    return null;
  }
  String? _validateTolerance(String? v) {
    final val = int.tryParse(v ?? '');
    if (val == null || val < 0 || val > 2000) return '0–2000 kcal';
    return null;
  }
  String? _validateOverride(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final val = int.tryParse(v);
    if (val == null || val < 1000 || val > 5000) return '1000–5000 kcal';
    return null;
  }

  void _showEquipmentSheet() {
    final theme = Theme.of(context);
    Set<String> tempEquipment = Set.from(_equipment);

    AppBottomSheet.show(
      context,
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Manage Equipment', style: theme.textTheme.h2, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Dumbbells', 'Barbell', 'Kettlebell', 'Pull-up bar', 'Jump rope'].map((eq) {
                    final isSelected = tempEquipment.contains(eq);
                    return SelectChip(
                      label: eq,
                      isSelected: isSelected,
                      onSelected: () {
                        setSheetState(() {
                          if (isSelected) {
                            tempEquipment.remove(eq);
                          } else {
                            tempEquipment.add(eq);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Apply',
                  onPressed: () {
                    setState(() => _equipment = tempEquipment);
                    Navigator.of(context).pop();
                    _save();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final wErr = _validateWeight(_weightCtrl.text);
    final hErr = _validateHeight(_heightCtrl.text);
    final aErr = _validateAge(_ageCtrl.text);
    final tErr = _validateTolerance(_toleranceCtrl.text);
    
    if (wErr != null || hErr != null || aErr != null || tErr != null) {
      AppSnackbar.error(context, 'Please fix errors before saving.');
      return;
    }

    setState(() => _isSaving = true);
    final goalWeightStr = _goalWeightCtrl.text.trim();
    final goalWeightKg = goalWeightStr.isEmpty ? null : double.parse(goalWeightStr);

    await ref
        .read(profileEditProvider.notifier)
        .updateProfile(
          weightKg: double.parse(_weightCtrl.text),
          goalWeightKg: goalWeightKg,
          heightCm: int.parse(_heightCtrl.text),
          age: int.parse(_ageCtrl.text),
          gender: _gender,
          goal: _goal,
          activityLevel: _activityLevel,
          allowanceKcal: int.tryParse(_toleranceCtrl.text),
          targetOverride: _overrideCtrl.text.isEmpty ? null : int.tryParse(_overrideCtrl.text),
          clearOverride: _overrideCtrl.text.isEmpty,
          equipment: _equipment.toList(),
        );

    setState(() => _isSaving = false);
    if (mounted) {
      AppSnackbar.success(context, 'Profile saved successfully!');
    }
  }
}
