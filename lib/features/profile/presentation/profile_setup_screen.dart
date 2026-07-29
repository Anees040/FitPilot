import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/application/providers/profile_edit_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/app_card.dart';
import 'package:fitpilot/core/ui/select_chip.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  int _step = 0; // 0: Basics, 1: Activity, 2: Goal

  // Step 1
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  Gender? _gender;

  // Step 2
  ActivityLevel _activityLevel = ActivityLevel.light;
  final Set<String> _equipment = {};

  // Step 3
  Goal _goal = Goal.maintain;
  double _allowance = 300;

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0) {
      final weight = double.tryParse(_weightCtrl.text);
      final height = int.tryParse(_heightCtrl.text);
      final age = int.tryParse(_ageCtrl.text);

      if (weight == null || weight < 25 || weight > 300) {
        setState(() => _error = 'Weight must be 25-300 kg');
        return;
      }
      if (height == null || height < 100 || height > 250) {
        setState(() => _error = 'Height must be 100-250 cm');
        return;
      }
      if (age == null || age < 13 || age > 100) {
        setState(() => _error = 'Age must be 13-100');
        return;
      }
    }
    
    setState(() => _error = null);
    
    if (_step < 2) {
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
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final profile = Profile(
        weightKg: double.parse(_weightCtrl.text),
        heightCm: int.parse(_heightCtrl.text),
        age: int.parse(_ageCtrl.text),
        gender: _gender ?? Gender.unspecified,
        activityLevel: _activityLevel,
        goal: _goal,
        allowanceKcal: _allowance.toInt(),
        equipment: _equipment.toList(),
        updatedAt: DateTime.now(),
      );

      await ref.read(profileEditProvider.notifier).updateProfile(
        weightKg: profile.weightKg,
        heightCm: profile.heightCm,
        age: profile.age,
        gender: profile.gender,
        activityLevel: profile.activityLevel,
        goal: profile.goal,
        allowanceKcal: profile.allowanceKcal,
        equipment: profile.equipment,
      );

      if (mounted) {
        context.go('/today');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _computedTarget {
    final weight = double.tryParse(_weightCtrl.text) ?? 70.0;
    final height = int.tryParse(_heightCtrl.text) ?? 170;
    final age = int.tryParse(_ageCtrl.text) ?? 30;
    
    try {
      final profile = Profile(
        weightKg: weight,
        heightCm: height,
        age: age,
        gender: _gender ?? Gender.unspecified,
        activityLevel: _activityLevel,
        goal: _goal,
        allowanceKcal: _allowance.toInt(),
        updatedAt: DateTime.now(),
      );
      return profile.effectiveDailyTarget;
    } catch (_) {
      return 2000;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _step ? theme.colorScheme.primary : ext.hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(context, theme, ext),
                  _buildStep2(context, theme, ext),
                  _buildStep3(context, theme, ext),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(BuildContext context, ThemeData theme, AppColors ext) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Body basics', style: theme.textTheme.h1),
          const SizedBox(height: 8),
          Text(
            'Let\'s calibrate your starting point.',
            style: theme.textTheme.body,
          ),
          const SizedBox(height: 32),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'WEIGHT (KG)',
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppTextField(
                    label: 'HEIGHT (CM)',
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: AppTextField(
              label: 'AGE',
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GENDER (OPTIONAL)', style: theme.textTheme.overline),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Gender.values.where((g) => g != Gender.unspecified).map((g) {
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.caption.copyWith(color: ext.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Next',
            onPressed: _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(BuildContext context, ThemeData theme, AppColors ext) {
    final eqOptions = ['Dumbbells', 'Barbell', 'Kettlebell', 'Pull-up bar', 'Jump rope'];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Activity & Gear', style: theme.textTheme.h1),
          const SizedBox(height: 8),
          Text(
            'Tell us how you move.',
            style: theme.textTheme.body,
          ),
          const SizedBox(height: 32),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACTIVITY LEVEL', style: theme.textTheme.overline),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ActivityLevel.values.map((level) {
                    final label = level.name[0].toUpperCase() + level.name.substring(1);
                    return SelectChip(
                      label: label,
                      isSelected: _activityLevel == level,
                      onSelected: () => setState(() => _activityLevel = level),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EQUIPMENT YOU HAVE', style: theme.textTheme.overline),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: eqOptions.map((e) {
                    final isSelected = _equipment.contains(e);
                    return SelectChip(
                      label: e,
                      isSelected: isSelected,
                      onSelected: () {
                        setState(() {
                          if (isSelected) {
                            _equipment.remove(e);
                          } else {
                            _equipment.add(e);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Next',
            onPressed: _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(BuildContext context, ThemeData theme, AppColors ext) {
    final target = _computedTarget;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your Target', style: theme.textTheme.h1),
          const SizedBox(height: 8),
          Text(
            'We computed your daily baseline.',
            style: theme.textTheme.body,
          ),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ext.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('DAILY TARGET', style: theme.textTheme.overline.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                Text('$target kcal', style: theme.textTheme.display.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 16),
                Text(
                  'Based on your body metrics and activity level, this is how much you should eat to reach your goal.',
                  style: theme.textTheme.caption.copyWith(color: theme.colorScheme.primary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR GOAL', style: theme.textTheme.overline),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Goal.values.map((goal) {
                    final label = goal.name[0].toUpperCase() + goal.name.substring(1);
                    return SelectChip(
                      label: label,
                      isSelected: _goal == goal,
                      onSelected: () => setState(() => _goal = goal),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY CHEAT ALLOWANCE', style: theme.textTheme.overline),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0', style: theme.textTheme.caption),
                    Text('${_allowance.toInt()} kcal', style: theme.textTheme.h2.copyWith(color: theme.colorScheme.primary)),
                    Text('1000', style: theme.textTheme.caption),
                  ],
                ),
                Slider(
                  value: _allowance,
                  min: 0,
                  max: 1000,
                  divisions: 20,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => setState(() => _allowance = val),
                ),
                Text(
                  'Extra calories you\'re allowed before triggering a burn plan.',
                  style: theme.textTheme.caption,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Start tracking',
            onPressed: _nextStep, // which submits on step 3
            isLoading: _isLoading,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
