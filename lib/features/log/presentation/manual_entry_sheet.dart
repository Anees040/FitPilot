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
  /// Prefilled when the sheet is opened from somewhere that already knows the
  /// food — the protein guide's "Log it", for instance. The user still sets the
  /// portion, so the numbers are per 100 g and stay editable.
  final String? initialName;
  final int? initialKcal;
  final double? initialProteinG;

  const ManualEntrySheet({
    super.key,
    this.initialName,
    this.initialKcal,
    this.initialProteinG,
  });

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  final _nameController = TextEditingController();
  final _kcalController = TextEditingController();
  final _portionController = TextEditingController();
  final _proteinController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) _nameController.text = widget.initialName!;
    if (widget.initialKcal != null) {
      _kcalController.text = widget.initialKcal!.toString();
    }
    if (widget.initialProteinG != null) {
      _proteinController.text = _trim(widget.initialProteinG!);
    }
    // The guide's figures are per 100 g, so say so rather than leaving the
    // user to guess what the prefilled numbers refer to.
    if (widget.initialKcal != null) _portionController.text = '100g';
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _kcalController.dispose();
    _portionController.dispose();
    _proteinController.dispose();
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

    // Optional. Left blank means "unknown", which the day's protein row counts
    // separately rather than treating as zero.
    final proteinText = _proteinController.text.trim();
    final protein = proteinText.isEmpty ? null : double.tryParse(proteinText);
    if (proteinText.isNotEmpty && (protein == null || protein < 0 || protein > 300)) {
      setState(() => _errorText = 'Protein must be between 0 and 300 g');
      return;
    }

    final log = FoodLog(
      id: const Uuid().v4(),
      customName: displayName,
      quantity: 1,
      kcal: KcalRange.exact(kcal),
      source: LogSource.manual,
      loggedAt: DateTime.now(),
      proteinG: protein,
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
            label: 'PROTEIN IN GRAMS (OPTIONAL)',
            controller: _proteinController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
