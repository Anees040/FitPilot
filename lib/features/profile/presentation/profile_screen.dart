import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/data/sync/sync_service.dart';
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
        title: Text('Profile & Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                            Expanded(child: _buildTextField('WEIGHT (KG)', _weightCtrl, _validateDouble)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('GOAL WT (OPT)', _goalWeightCtrl, _validateOptDouble)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTextField('HEIGHT (CM)', _heightCtrl, _validateInt)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField('AGE', _ageCtrl, _validateInt)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('GENDER', style: theme.textTheme.labelSmall),
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
                        Text('ACTIVITY LEVEL', style: theme.textTheme.labelSmall),
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
                        Text('GOAL', style: theme.textTheme.labelSmall),
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
                        title: Text('Plan Category', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<String>(
                          value: profile.planCategoryPref,
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
                          value: profile.planPacePref,
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
                        title: Text('Theme Mode', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<ThemeModePref>(
                          value: profile.themeMode,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: ThemeModePref.system, child: Text('System')),
                            DropdownMenuItem(value: ThemeModePref.light, child: Text('Light')),
                            DropdownMenuItem(value: ThemeModePref.dark, child: Text('Dark')),
                          ],
                          onChanged: (v) => _updateProfile(profile.copyWith(themeMode: v)),
                        ),
                      ),
                      Divider(color: theme.dividerColor, height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Theme Color', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<String>(
                          value: profile.themeColor,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'orange', child: Text('Orange')),
                            DropdownMenuItem(value: 'purple', child: Text('Purple')),
                            DropdownMenuItem(value: 'green', child: Text('Green')),
                            DropdownMenuItem(value: 'blue', child: Text('Blue')),
                          ],
                          onChanged: (v) => _updateProfile(profile.copyWith(themeColor: v)),
                        ),
                      ),
                      Divider(color: theme.dividerColor, height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Unit', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        trailing: DropdownButton<String>(
                          value: profile.unitKgLb,
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

  Widget _buildComputedTargetDisplay(ThemeData theme, Profile profile) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DAILY TARGET', style: theme.textTheme.labelSmall),
              if (profile.targetOverride != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'OVERRIDE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'kcal',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '+  kcal cheat allowance',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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

  Widget _buildTextField(String label, TextEditingController controller, String? Function(String?) validator) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        AppTextField(
          label: "",
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildAuthSection(BuildContext context, ThemeData theme) {
    final session = ref.watch(currentUserProvider);
    final ext = theme.extension<AppColors>()!;
    
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
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                      Text(
                        session.email,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
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
        ] else ...[
          PrimaryButton(
            label: 'Sign In / Create Account',
            onPressed: () => context.push('/auth'),
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
        weightKg: double.parse(_weightCtrl.text),
        goalWeightKg: _goalWeightCtrl.text.isEmpty ? null : double.parse(_goalWeightCtrl.text),
        heightCm: int.parse(_heightCtrl.text),
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

  String? _validateDouble(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final d = double.tryParse(v);
    if (d == null) return 'Invalid number';
    if (d < 25 || d > 300) return '25-300 kg only';
    return null;
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
