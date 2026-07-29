import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/profile_edit_provider.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/engines/target_calculator.dart';
import 'package:go_router/go_router.dart';
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
    _toleranceCtrl = TextEditingController(
      text: profile.allowanceKcal.toString(),
    );
    _overrideCtrl = TextEditingController(
      text: profile.targetKcalOverride?.toString() ?? '',
    );

    _gender = profile.gender;
    _activityLevel = profile.activityLevel;
    _goal = profile.goal;
    _equipment = Set.from(profile.equipment);

    // Add listeners to trigger rebuilds for the dynamic target text
    _weightCtrl.addListener(() => setState(() {}));
    _heightCtrl.addListener(() => setState(() {}));
    _ageCtrl.addListener(() => setState(() {}));
    _toleranceCtrl.addListener(() => setState(() {}));
    _overrideCtrl.addListener(() => setState(() {}));

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text('Profile', style: AppTheme.title),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            _initForm(profile);
            return _buildForm(context, profile);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, Profile profile) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildComputedTargetDisplay(),
          const SizedBox(height: 24),
          _buildSectionTitle('Vitals'),
          Row(
            children: [
              Expanded(
                child: _buildTextField('Weight (kg)', _weightCtrl, (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val < 25 || val > 300) return '25–300 kg';
                  return null;
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('Goal Wt (optional)', _goalWeightCtrl, (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = double.tryParse(v);
                  if (val == null || val < 25 || val > 300) return '25–300 kg';
                  return null;
                }),
              ),
            ],
          ),
          _buildTextField('Height (cm)', _heightCtrl, (v) {
            final val = int.tryParse(v ?? '');
            if (val == null || val < 100 || val > 250) {
              return 'Must be 100–250 cm';
            }
            return null;
          }),
          _buildTextField('Age', _ageCtrl, (v) {
            final val = int.tryParse(v ?? '');
            if (val == null || val < 13 || val > 100) return 'Must be 13–100';
            return null;
          }),
          const SizedBox(height: 16),
          _buildDropdown<Gender>('Gender', _gender, Gender.values, (v) {
            setState(() => _gender = v!);
          }),
          const SizedBox(height: 24),
          _buildSectionTitle('Lifestyle & Goals'),
          _buildDropdown<ActivityLevel>(
            'Activity Level',
            _activityLevel,
            ActivityLevel.values,
            (v) {
              setState(() => _activityLevel = v!);
            },
          ),
          const SizedBox(height: 16),
          _buildDropdown<Goal>('Goal', _goal, Goal.values, (v) {
            setState(() => _goal = v!);
          }),
          _buildTextField('Cheat Tolerance (kcal)', _toleranceCtrl, (v) {
            final val = int.tryParse(v ?? '');
            if (val == null || val < 0 || val > 2000) {
              return 'Must be 0–2000 kcal';
            }
            return null;
          }),
          _buildTextField('Manual Target Override (optional)', _overrideCtrl, (
            v,
          ) {
            if (v == null || v.trim().isEmpty) return null;
            final val = int.tryParse(v);
            if (val == null || val < 1000 || val > 5000) {
              return 'Must be 1000–5000 kcal';
            }
            return null;
          }),
          const SizedBox(height: 24),
          _buildSectionTitle('Available Equipment'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['rope', 'cycle', 'gym', 'pool'].map((eq) {
              final isSelected = _equipment.contains(eq);
              return ChoiceChip(
                label: Text(
                  eq,
                  style: AppTheme.caption.copyWith(
                    color: isSelected ? AppTheme.surface : AppTheme.text,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.accent,
                backgroundColor: AppTheme.bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: const BorderSide(color: AppTheme.hairline),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _equipment.add(eq);
                    } else {
                      _equipment.remove(eq);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Settings'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notifications_active, color: AppTheme.accent),
            title: Text('Notifications', style: AppTheme.body),
            trailing: Icon(Icons.chevron_right, color: AppTheme.secondaryText),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => fitpilot_settings.NotificationPrefsScreen()),
              );
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.surface,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Save Profile',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 32),
          _buildAuthSection(context),
        ],
      ),
    );
  }

  Widget _buildAuthSection(BuildContext context) {
    final authUser = ref.watch(currentUserProvider);

    if (authUser == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle('Account'),
          Text(
            'Sign in to sync your progress across devices.',
            style: AppTheme.body.copyWith(color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/signin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.accent,
              side: const BorderSide(color: AppTheme.hairline),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Sign in / Create Account',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Account'),
        Text('Signed in as: ${authUser.email}', style: AppTheme.body),
        _buildSyncStatus(context),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            try {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Signed out successfully.'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error signing out.'),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.hairline),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Sign Out',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSyncStatus(BuildContext context) {
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

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        message,
        style: AppTheme.caption.copyWith(color: AppTheme.secondaryText),
      ),
    );
  }

  Widget _buildComputedTargetDisplay() {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Target: $finalTarget kcal', style: AppTheme.title),
          const SizedBox(height: 8),
          Text(explanation, style: AppTheme.body),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: AppTheme.title),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    String? Function(String?) validator,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTheme.body.copyWith(color: AppTheme.secondaryText),
          fillColor: AppTheme.surface,
          filled: true,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.accent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.hairline),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.error),
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T value,
    List<T> items,
    void Function(T?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTheme.body.copyWith(color: AppTheme.secondaryText),
          fillColor: AppTheme.surface,
          filled: true,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.accent),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.hairline),
          ),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e.toString().split('.').last, style: AppTheme.body),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final overrideStr = _overrideCtrl.text.trim();
    final overrideKcal = overrideStr.isEmpty ? null : int.parse(overrideStr);
    
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
          allowanceKcal: int.parse(_toleranceCtrl.text),
          targetKcalOverride: overrideKcal,
          clearOverride: overrideKcal == null,
          equipment: _equipment.toList(),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
