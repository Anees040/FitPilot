import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';

class ManualEntrySheet extends ConsumerStatefulWidget {
  const ManualEntrySheet({super.key});

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  final _nameController = TextEditingController();
  final _kcalController = TextEditingController();
  final _portionController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _kcalController.dispose();
    _portionController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Please enter a name');
      return;
    }

    final kcalStr = _kcalController.text.trim();
    final kcal = int.tryParse(kcalStr);
    if (kcal == null || kcal < 1 || kcal > 5000) {
      setState(() => _errorText = 'Calories must be between 1 and 5000');
      return;
    }

    final portionBasis = _portionController.text.trim();
    final displayName = portionBasis.isNotEmpty ? '$name ($portionBasis)' : name;

    setState(() => _errorText = null);

    final log = FoodLog(
      id: const Uuid().v4(),
      customName: displayName,
      quantity: 1,
      kcal: KcalRange.exact(kcal),
      source: LogSource.manual,
      loggedAt: DateTime.now(),
    );

    ref.read(todayProvider.notifier).addLog(log);
    Navigator.pop(context);
    AppSnackbar.success(context, 'Meal logged');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 8.0,
        bottom: 24.0 + bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Manually',
            style: theme.textTheme.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Manual entries are saved privately to your daily personal log.',
            style: theme.textTheme.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'FOOD NAME',
            controller: _nameController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'CALORIES (KCAL)',
            controller: _kcalController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'PORTION / WEIGHT BASIS (OPTIONAL, e.g. 100g, 1 plate)',
            controller: _portionController,
            errorText: _errorText,
            onSubmitted: (_) => _validateAndSubmit(),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Add Meal',
            onPressed: _validateAndSubmit,
          ),
        ],
      ),
    );
  }
}
