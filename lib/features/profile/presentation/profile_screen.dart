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
import 'package:fitpilot/core/ui/app_bottom_sheet.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/select_chip.dart';
import 'package:fitpilot/core/ui/confirm_snackbar.dart';
import 'package:fitpilot/features/settings/presentation/notification_prefs_screen.dart' as fitpilot_settings;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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
            _initForm(profile);
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

          _buildSectionTitle('VITALS', theme),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildTextField('WEIGHT (KG)', _weightCtrl, _validateWeight)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('TARGET WT (OPT)', _goalWeightCtrl, _validateGoalWeight)),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('GENDER', style: theme.textTheme.overline),
                ),
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('LIFESTYLE', theme),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('PREFERENCES', theme),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.palette, color: theme.colorScheme.primary),
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
                          final newP = p.copyWith(themeMode: v);
                          final repo = await ref.read(profileRepositoryProvider.future);
                          await repo.save(newP);
                          ref.invalidate(profileProvider);
                        }
                      }
                    },
                  ),
                ),
                Divider(color: theme.dividerColor, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.fitness_center, color: theme.colorScheme.primary),
                  title: Text('Manage Equipment', style: theme.textTheme.bodyStrong),
                  trailing: Icon(Icons.chevron_right, color: theme.textTheme.caption.color),
                  onTap: _showEquipmentSheet,
                ),
                Divider(color: theme.dividerColor, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notifications_active, color: theme.colorScheme.primary),
                  title: Text('Notifications', style: theme.textTheme.bodyStrong),
                  trailing: Icon(Icons.chevron_right, color: theme.textTheme.caption.color),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const fitpilot_settings.NotificationPrefsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          PrimaryButton(
            label: 'Save Profile',
            onPressed: _save,
            isLoading: _isSaving,
          ),
          const SizedBox(height: 32),

          _buildAuthSection(context, theme),
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
          _buildSectionTitle('ACCOUNT', theme),
          AppCard(
            child: Column(
              children: [
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
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('ACCOUNT', theme),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Signed in as: ${authUser.email}', style: theme.textTheme.bodyStrong),
              const SizedBox(height: 8),
              _buildSyncStatus(context, theme),
              const SizedBox(height: 24),
              TertiaryButton(
                label: 'Sign Out',
                onPressed: () async {
                  try {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      confirmSnackbar(context, 'Signed out successfully.');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      confirmSnackbar(context, 'Error signing out.');
                    }
                  }
                },
                color: ext.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
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
      // We rely on the form key for validation UI, so AppTextField needs a validator or we just let Form handle it.
      // Wait, AppTextField doesn't have a validator property out of the box in our F3 UI. Let's use it without for now
      // and do manual validation on save. Wait, AppTextField handles errorText.
      // For simplicity, we can just use onChanged to clear errors, but we need to track them.
      // Since AppTextField is stateless, we will manage errors manually if needed, or modify AppTextField.
      // Actually, I can just not show inline errors and let the top level error handle it, or modify AppTextField to take an errorText.
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
    // Validate manually since AppTextField doesn't have validator
    final wErr = _validateWeight(_weightCtrl.text);
    final hErr = _validateHeight(_heightCtrl.text);
    final aErr = _validateAge(_ageCtrl.text);
    final tErr = _validateTolerance(_toleranceCtrl.text);
    
    if (wErr != null || hErr != null || aErr != null || tErr != null) {
      confirmSnackbar(context, 'Please fix errors before saving.');
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
      confirmSnackbar(context, 'Profile saved successfully!');
    }
  }
}
