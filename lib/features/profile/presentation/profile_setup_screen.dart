import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/features/profile/presentation/widgets/ruler_picker.dart';

enum LocalGoal { lose, build, maintain, improve }

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  int _step = 0;

  bool _isLoadingProfile = true;

  // Step 1: Details
  double _weightKg = 70.0;
  bool _isWeightKg = true; // true = kg, false = lbs

  int _heightCm = 170;
  bool _isHeightCm = true; // true = cm, false = ft/in

  int _age = 25;
  Gender _gender = Gender.male;

  // Step 2: Activity Level
  ActivityLevel _activityLevel = ActivityLevel.light;

  // Step 3: Goal
  LocalGoal _goal = LocalGoal.lose;

  // Step 4: Equipment
  final Set<String> _equipment = {};

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingProfile();
  }

  Future<void> _checkExistingProfile() async {
    final profile = await ref.read(profileRepositoryProvider.future).then((r) => r.get());
    
    if (mounted) {
      if (profile != null && profile.gender != Gender.unspecified) {
        context.go('/today');
        return;
      }
      
      if (profile != null) {
        _weightKg = profile.weightKg;
        _heightCm = profile.heightCm;
        _age = profile.age;
        if (profile.gender != Gender.unspecified) _gender = profile.gender;
        _activityLevel = profile.activityLevel;
        
        if (profile.goal == Goal.lose) {
          _goal = LocalGoal.lose;
        } else if (profile.goal == Goal.maintain) {
          _goal = LocalGoal.maintain;
        } else {
          _goal = LocalGoal.build; // default mapping for existing
        }
        
        _equipment.addAll(profile.equipment);
      }
      
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < 4) { // 5 steps total
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    } else {
      context.go('/welcome?initialIndex=3');
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    
    try {
      final repoFuture = ref.read(profileRepositoryProvider.future);
      final progressNotifier = ref.read(progressProvider.notifier);

      final repo = await repoFuture;
      if (!mounted) return;
      
      final existingProfile = await repo.get();
      if (!mounted) return;
      
      Goal mappedGoal = Goal.lose;
      if (_goal == LocalGoal.build) mappedGoal = Goal.build;
      if (_goal == LocalGoal.maintain) mappedGoal = Goal.maintain;
      if (_goal == LocalGoal.improve) mappedGoal = Goal.build;
      
      final profile = Profile(
        name: existingProfile?.name,
        weightKg: _weightKg,
        heightCm: _heightCm,
        age: _age,
        gender: _gender,
        goal: mappedGoal,
        activityLevel: _activityLevel,
        allowanceKcal: Profile.defaultAllowanceKcal,
        equipment: _equipment.toList(),
        themeMode: ThemeModePref.system,
        themeColor: 'orange',
        planCategoryPref: 'recommended',
        planPacePref: 'any',
        unitKgLb: _isWeightKg ? 'kg' : 'lb',
        weekStartsMon: true,
        hapticsOn: true,
        onboardingComplete: true,
        updatedAt: DateTime.now(),
      );

      await repo.save(profile);
      if (!mounted) return;
      
      // Log the initial weight
      await progressNotifier.addWeight(_weightKg);

      ref.invalidate(profileProvider);

      if (mounted) context.go('/today');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _prevStep();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: _prevStep,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDetailsStep(theme),
                  _buildActivityStep(theme),
                  _buildGoalStep(theme),
                  _buildEquipmentStep(theme),
                  _buildSummaryStep(theme),
                ],
              ),
            ),
            _buildBottomNav(theme),
          ],
        ),
      ),
    ));
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: PrimaryButton(
                onPressed: _isSaving ? null : _nextStep,
                label: _step == 4 ? 'Complete Setup' : 'Next',
                isLoading: _isSaving,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / 5,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Step ${_step + 1} of 5',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 1: Details ---
  Widget _buildDetailsStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Let\'s build your profile',
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us personalize your experience',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Your Details',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          icon: Icons.monitor_weight_outlined,
          iconColor: theme.colorScheme.primary,
          label: 'Weight',
          value: _isWeightKg 
              ? '${_weightKg.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} kg'
              : '${(_weightKg * 2.20462).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} lbs',
          onTap: () => _showWeightPicker(theme),
          theme: theme,
        ),
        _buildDetailCard(
          icon: Icons.height,
          iconColor: theme.colorScheme.secondary,
          label: 'Height',
          value: _isHeightCm
              ? '$_heightCm cm'
              : '${(_heightCm / 30.48).floor()} ft ${((_heightCm / 2.54) % 12).round()} in',
          onTap: () => _showHeightPicker(theme),
          theme: theme,
        ),
        _buildBMICard(theme),
        _buildDetailCard(
          icon: Icons.cake_outlined,
          iconColor: theme.colorScheme.tertiary,
          label: 'Age',
          value: '$_age years',
          onTap: () => _showAgePicker(theme),
          theme: theme,
        ),
        _buildDetailCard(
          icon: Icons.male,
          iconColor: theme.colorScheme.primary,
          label: 'Gender',
          value: _gender == Gender.unspecified ? 'Prefer not to say' : _gender.name.substring(0, 1).toUpperCase() + _gender.name.substring(1),
          onTap: () => _showGenderPicker(theme),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildBMICard(ThemeData theme) {
    final bmi = _weightKg / ((_heightCm / 100) * (_heightCm / 100));
    final ext = theme.extension<AppColors>()!;
    
    String status = 'Unknown';
    Color statusColor = ext.hairline;

    if (bmi < 18.5) {
      statusColor = ext.warning;
      status = 'Underweight';
    } else if (bmi < 25) {
      statusColor = ext.success;
      status = 'Normal';
    } else if (bmi < 30) {
      statusColor = ext.warning;
      status = 'Overweight';
    } else if (bmi < 35) {
      statusColor = ext.error;
      status = 'Obese I';
    } else {
      statusColor = ext.error;
      status = 'Obese II+';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.extension<AppColors>()?.surfaceRaised ?? theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.monitor_heart_outlined, color: statusColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BMI', 
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    )
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        bmi.toStringAsFixed(1),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: theme.extension<AppColors>()?.surfaceRaised ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label, 
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        )
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWeightPicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Weight', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        _buildUnitToggle(
                          label: 'kg',
                          isSelected: _isWeightKg,
                          onTap: () {
                            setModalState(() => _isWeightKg = true);
                            setState(() => _isWeightKg = true);
                          },
                        ),
                        _buildUnitToggle(
                          label: 'lbs',
                          isSelected: !_isWeightKg,
                          onTap: () {
                            setModalState(() => _isWeightKg = false);
                            setState(() => _isWeightKg = false);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isWeightKg)
                    RulerPicker(
                      key: const ValueKey('kg'),
                      minValue: 30,
                      maxValue: 200,
                      initialValue: _weightKg,
                      step: 0.1,
                      majorTickInterval: 1.0,
                      valueBuilder: (context, val) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(val.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text('kg', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                      tickFormatter: (val) => val.toInt().toString(),
                      onChanged: (val) {
                        setState(() => _weightKg = val);
                      },
                    )
                  else
                    RulerPicker(
                      key: const ValueKey('lbs'),
                      minValue: 66,
                      maxValue: 440,
                      initialValue: (_weightKg * 2.20462).roundToDouble(),
                      step: 1,
                      majorTickInterval: 10,
                      valueBuilder: (context, val) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(val.toInt().toString(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text('lbs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                      tickFormatter: (val) => val.toInt().toString(),
                      onChanged: (val) {
                        setState(() => _weightKg = val / 2.20462);
                      },
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            foregroundColor: theme.colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHeightPicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Height', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    width: 200,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        _buildUnitToggle(
                          label: 'cm',
                          isSelected: _isHeightCm,
                          onTap: () {
                            setModalState(() => _isHeightCm = true);
                            setState(() => _isHeightCm = true);
                          },
                        ),
                        _buildUnitToggle(
                          label: 'ft',
                          isSelected: !_isHeightCm,
                          onTap: () {
                            setModalState(() => _isHeightCm = false);
                            setState(() => _isHeightCm = false);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isHeightCm)
                    RulerPicker(
                      key: const ValueKey('cm'),
                      minValue: 100,
                      maxValue: 250,
                      initialValue: _heightCm.toDouble(),
                      step: 1,
                      majorTickInterval: 10,
                      valueBuilder: (context, val) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(val.toInt().toString(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text('cm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                      tickFormatter: (val) => val.toInt().toString(),
                      onChanged: (val) {
                        setState(() => _heightCm = val.round());
                      },
                    )
                  else
                    RulerPicker(
                      key: const ValueKey('ft'),
                      minValue: 40,
                      maxValue: 98,
                      initialValue: (_heightCm / 2.54).roundToDouble(),
                      step: 1, // inches
                      majorTickInterval: 12, // 12 inches in a foot
                      valueBuilder: (context, val) {
                        int ft = (val / 12).floor();
                        int inches = (val % 12).round();
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$ft', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text('ft', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                            const SizedBox(width: 8),
                            Text('$inches', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text('in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        );
                      },
                      tickFormatter: (val) {
                        int ft = (val / 12).floor();
                        return '$ft';
                      },
                      onChanged: (val) {
                        setState(() => _heightCm = (val * 2.54).round());
                      },
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            foregroundColor: theme.colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnitToggle({required String label, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAgePicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Age', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              RulerPicker(
                minValue: 13,
                maxValue: 100,
                initialValue: _age.toDouble(),
                step: 1,
                majorTickInterval: 5,
                valueBuilder: (context, val) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(val.toInt().toString(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Text('years', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
                tickFormatter: (val) => val.toInt().toString(),
                onChanged: (val) {
                  setState(() => _age = val.round());
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGenderPicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gender', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildGenderOption('Male', Gender.male),
              const SizedBox(height: 12),
              _buildGenderOption('Female', Gender.female),
              const SizedBox(height: 12),
              _buildGenderOption('Prefer not to say', Gender.unspecified),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenderOption(String label, Gender value) {
    final theme = Theme.of(context);
    final isSelected = _gender == value;
    return InkWell(
      onTap: () {
        setState(() => _gender = value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Activity Level ---
  Widget _buildActivityStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your Activity Level',
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'How active are you on a typical day?',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        _buildActivityCard(
          title: 'Sedentary',
          subtitle: 'Little or no exercise, desk job',
          icon: Icons.chair_alt,
          value: ActivityLevel.sedentary,
        ),
        const SizedBox(height: 16),
        _buildActivityCard(
          title: 'Lightly Active',
          subtitle: 'Light exercise or sports 1-3 days a week',
          icon: Icons.directions_walk,
          value: ActivityLevel.light,
        ),
        const SizedBox(height: 16),
        _buildActivityCard(
          title: 'Moderately Active',
          subtitle: 'Moderate exercise 3-5 days a week',
          icon: Icons.directions_run,
          value: ActivityLevel.moderate,
        ),
        const SizedBox(height: 16),
        _buildActivityCard(
          title: 'Very Active',
          subtitle: 'Hard exercise 6-7 days a week',
          icon: Icons.fitness_center,
          value: ActivityLevel.active,
        ),
      ],
    );
  }

  Widget _buildActivityCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required ActivityLevel value,
  }) {
    final theme = Theme.of(context);
    final isSelected = _activityLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _activityLevel = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.1), blurRadius: 10)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                child: Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary),
              ),
          ],
        ),
      ),
    );
  }

  // --- Step 3: Goal ---
  Widget _buildGoalStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'What\'s your goal?',
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your primary fitness goal',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        _buildGoalCard(
          title: 'Lose Fat',
          subtitle: 'Reduce body fat and get lean',
          imagePath: 'assets/illustrations/goal_lose_fat.png',
          value: LocalGoal.lose,
        ),
        const SizedBox(height: 16),
        _buildGoalCard(
          title: 'Gain Muscle',
          subtitle: 'Build strength and muscle mass',
          imagePath: 'assets/illustrations/goal_gain_muscle.png',
          value: LocalGoal.build,
        ),
        const SizedBox(height: 16),
        _buildGoalCard(
          title: 'Maintain',
          subtitle: 'Stay fit and maintain your weight',
          imagePath: 'assets/illustrations/goal_maintain.png',
          value: LocalGoal.maintain,
        ),
        const SizedBox(height: 16),
        _buildGoalCard(
          title: 'Improve Fitness', 
          subtitle: 'Boost stamina and overall health',
          imagePath: 'assets/illustrations/goal_improve_fitness.png',
          value: LocalGoal.improve,
        ),
      ],
    );
  }

  Widget _buildGoalCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required LocalGoal value,
  }) {
    final theme = Theme.of(context);
    final isSelected = _goal == value;
    return GestureDetector(
      onTap: () => setState(() => _goal = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.1), blurRadius: 10)]
              : null,
        ),
        child: Row(
          children: [
            Image.asset(imagePath, width: 60, height: 60, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 60)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                child: Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary),
              ),
          ],
        ),
      ),
    );
  }

  // --- Step 4: Equipment ---
  Widget _buildEquipmentStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your Equipment',
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Select equipment you have access to',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildEquipCard('Gym', 'assets/illustrations/equip_gym.png', 'gym'),
            _buildEquipCard('Rope', 'assets/illustrations/equip_rope.png', 'rope'),
            _buildEquipCard('Cycle', 'assets/illustrations/equip_cycle.png', 'cycle'),
            _buildEquipCard('Pool', 'assets/illustrations/equip_pool.png', 'pool'),
          ],
        ),
        const SizedBox(height: 24),
        _buildNoneEquipmentCard(),
      ],
    );
  }

  Widget _buildEquipCard(String label, String imagePath, String value) {
    final theme = Theme.of(context);
    final isSelected = _equipment.contains(value);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _equipment.remove(value);
          } else {
            _equipment.remove('none'); 
            _equipment.add(value);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(imagePath, width: 40, height: 40, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.fitness_center, size: 40)),
                  const SizedBox(height: 12),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoneEquipmentCard() {
    final theme = Theme.of(context);
    final isSelected = _equipment.contains('none') || _equipment.isEmpty;
    return GestureDetector(
      onTap: () {
        setState(() {
          _equipment.clear();
          _equipment.add('none');
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.not_interested, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('None of these', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('I don\'t have any equipment', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  // --- Step 5: Summary ---
  Widget _buildSummaryStep(ThemeData theme) {
    final heightStr = _isHeightCm
        ? '$_heightCm cm'
        : '${(_heightCm / 30.48).floor()} ft ${((_heightCm / 2.54) % 12).round()} in';
    final weightStr = _isWeightKg 
        ? '${_weightKg.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} kg'
        : '${(_weightKg * 2.20462).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} lbs';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Image.asset(
            'assets/illustrations/burn_smart.png',
            height: 180,
            errorBuilder: (c, e, s) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline, size: 80, color: theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'You\'re all set!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ve personalized your experience based on your profile.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildSummaryChip(theme, Icons.monitor_weight_outlined, weightStr),
            _buildSummaryChip(theme, Icons.height, heightStr),
            _buildSummaryChip(theme, Icons.cake_outlined, '$_age yrs'),
            _buildSummaryChip(
              theme,
              Icons.male,
              _gender == Gender.unspecified ? 'Prefer not to say' : _gender.name.substring(0, 1).toUpperCase() + _gender.name.substring(1),
            ),
            _buildSummaryChip(theme, Icons.directions_run, _activityLevel.name.toUpperCase()),
            _buildSummaryChip(theme, Icons.flag, _goal.name.toUpperCase()),
          ],
        ),
        const SizedBox(height: 16),
        if (_equipment.isNotEmpty && !_equipment.contains('none'))
          Center(
            child: _buildSummaryChip(theme, Icons.fitness_center, _equipment.join(', ').toUpperCase()),
          )
        else
          Center(
            child: _buildSummaryChip(theme, Icons.fitness_center, 'NO EQUIPMENT'),
          ),
      ],
    );
  }

  Widget _buildSummaryChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
