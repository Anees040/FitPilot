import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fitpilot/domain/entities/food_log.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';
import 'package:fitpilot/application/providers/today_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/confirm_snackbar.dart';

class ManualEntrySheet extends ConsumerStatefulWidget {
  const ManualEntrySheet({super.key});

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  final _nameController = TextEditingController();
  final _kcalController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _kcalController.dispose();
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

    setState(() => _errorText = null);

    final log = FoodLog(
      id: const Uuid().v4(),
      customName: name,
      quantity: 1,
      kcal: KcalRange.exact(kcal),
      source: LogSource.manual,
      loggedAt: DateTime.now(),
    );

    ref.read(todayProvider.notifier).addLog(log);
    Navigator.of(context).pop();
    confirmSnackbar(context, 'Added manual entry');
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
          const SizedBox(height: 24),
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
            errorText: _errorText,
            onSubmitted: (_) => _validateAndSubmit(),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Add',
            onPressed: _validateAndSubmit,
          ),
        ],
      ),
    );
  }
}
