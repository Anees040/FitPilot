import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/data/remote/open_food_facts_client.dart';
import 'package:fitpilot/application/providers/capture_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';

class BarcodeQuantitySheet extends ConsumerStatefulWidget {
  final String barcode;
  final OffResult offResult; // Assumes OffFound or OffFoundMissingEnergy

  /// The user's own photo of this meal, saved by the AI scan flow. Null for
  /// barcode and label scans, which show the product or dish art instead.
  final String? photoPath;

  const BarcodeQuantitySheet({
    super.key,
    required this.barcode,
    required this.offResult,
    this.photoPath,
  });

  @override
  ConsumerState<BarcodeQuantitySheet> createState() =>
      _BarcodeQuantitySheetState();
}

class _BarcodeQuantitySheetState extends ConsumerState<BarcodeQuantitySheet> {
  String _selectedPreset = 'whole_pack'; // 'whole_pack', 'half_pack', 'custom'
  final _customController = TextEditingController();

  double? _netWeightGrams;
  late int _kcalPer100g;
  late String _productName;

  @override
  void initState() {
    super.initState();

    if (widget.offResult is OffFound) {
      final found = widget.offResult as OffFound;
      _productName = found.productName;
      _kcalPer100g = found.kcalPer100g;
      _netWeightGrams = found.netWeightGrams;
    } else if (widget.offResult is OffFoundMissingEnergy) {
      _productName = (widget.offResult as OffFoundMissingEnergy).productName;
      _kcalPer100g = 0;
    } else {
      _productName = 'Unknown Product';
      _kcalPer100g = 0;
    }

    _loadSavedQuantity();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedQuantity() async {
    if (_netWeightGrams != null) {
      setState(() {
        _selectedPreset = 'whole_pack';
      });
      return;
    }

    final savedQ = await ref
        .read(captureProvider.notifier)
        .getSavedQuantity(widget.barcode);
    if (savedQ != null) {
      setState(() {
        _netWeightGrams = savedQ;
        _selectedPreset = 'whole_pack';
      });
    } else {
      setState(() {
        _selectedPreset = 'custom';
      });
    }
  }

  int get _computedKcal {
    if (_selectedPreset == 'whole_pack' && _netWeightGrams != null) {
      return (_kcalPer100g * (_netWeightGrams! / 100)).round();
    } else if (_selectedPreset == 'half_pack' && _netWeightGrams != null) {
      return (_kcalPer100g * ((_netWeightGrams! / 2) / 100)).round();
    } else if (_selectedPreset == 'custom') {
      final customGrams = double.tryParse(_customController.text) ?? 0.0;
      return (_kcalPer100g * (customGrams / 100)).round();
    }
    return 0;
  }

  Future<void> _logItem() async {
    if (_selectedPreset == 'custom' && _netWeightGrams == null) {
      final customGrams = double.tryParse(_customController.text);
      if (customGrams != null && customGrams > 0) {
        await ref
            .read(captureProvider.notifier)
            .saveQuantity(widget.barcode, customGrams);
      }
    }

    final kcal = _computedKcal;
    if (kcal <= 0 && widget.offResult is! OffFoundMissingEnergy) {
      return; 
    }

    double finalGrams = 0;
    if (_selectedPreset == 'whole_pack') {
      finalGrams = _netWeightGrams ?? 0;
    } else if (_selectedPreset == 'half_pack') {
      finalGrams = (_netWeightGrams ?? 0) / 2;
    } else if (_selectedPreset == 'custom') {
      finalGrams = double.tryParse(_customController.text) ?? 0;
    }

    await ref
        .read(captureProvider.notifier)
        .logScannedItem(
          barcode: widget.barcode,
          name: _productName,
          kcal: kcal,
          grams: finalGrams,
          photoPath: widget.photoPath,
        );

    if (mounted) {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24.0,
        right: 24.0,
        top: 8.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_productName, style: theme.textTheme.h2),
          const SizedBox(height: 4),
          Text(
            widget.offResult is OffFound && (widget.offResult as OffFound).isLocal
                ? 'Saved on this device'
                : 'from Open Food Facts',
            style: theme.textTheme.caption.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          if (widget.offResult is OffFoundMissingEnergy)
            Text(
              'Energy data missing from Open Food Facts.',
              style: theme.textTheme.caption.copyWith(color: ext.error),
            )
          else
            Text(
              '$_kcalPer100g kcal per 100g',
              style: theme.textTheme.caption,
            ),
          const SizedBox(height: 24),

          if (_netWeightGrams != null) ...[
            Text('AMOUNT', style: theme.textTheme.overline),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surface,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPreset,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'whole_pack',
                      child: Text('Whole pack (${_netWeightGrams}g)', style: theme.textTheme.bodyStrong),
                    ),
                    DropdownMenuItem(
                      value: 'half_pack',
                      child: Text('Half pack (${_netWeightGrams! / 2}g)', style: theme.textTheme.bodyStrong),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('Custom grams / ml', style: theme.textTheme.bodyStrong),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPreset = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text('AMOUNT', style: theme.textTheme.overline),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surface,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'custom',
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('Custom grams / ml', style: theme.textTheme.bodyStrong),
                    ),
                  ],
                  onChanged: null,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_selectedPreset == 'custom')
            AppTextField(
              label: 'GRAMS / ML',
              controller: _customController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),

          const SizedBox(height: 32),
          Text(
            '~$_computedKcal kcal',
            style: theme.textTheme.display.copyWith(color: theme.colorScheme.primary),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryButton(
                  label: 'Log',
                  onPressed: _computedKcal > 0 ? _logItem : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
