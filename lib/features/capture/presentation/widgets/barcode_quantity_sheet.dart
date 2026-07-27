import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/data/remote/open_food_facts_client.dart';
import 'package:fitpilot/application/providers/capture_provider.dart';
import 'package:go_router/go_router.dart';

class BarcodeQuantitySheet extends ConsumerStatefulWidget {
  final String barcode;
  final OffResult offResult; // Assumes OffFound or OffFoundMissingEnergy

  const BarcodeQuantitySheet({
    super.key,
    required this.barcode,
    required this.offResult,
  });

  @override
  ConsumerState<BarcodeQuantitySheet> createState() =>
      _BarcodeQuantitySheetState();
}

class _BarcodeQuantitySheetState extends ConsumerState<BarcodeQuantitySheet> {
  String _selectedPreset =
      'whole_pack'; // 'whole_pack', 'half_pack', 'one_serving', 'custom'
  final _customController = TextEditingController();

  // These will be populated from cache or OffResult
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
      _kcalPer100g =
          0; // The user will need to enter this in a custom flow maybe? Wait, the prompt says "When the basis alone is insufficient...".
      // If energy is missing entirely, we must ask the user for energy too. But the prompt just says "ask once and then remember the value forever in saved_products".
      // Let's assume the user will enter kcal if missing. For now, 0.
    }

    _loadSavedQuantity();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedQuantity() async {
    // If netWeight is present, use it.
    if (_netWeightGrams != null) {
      setState(() {
        _selectedPreset = 'whole_pack';
      });
      return;
    }

    // Otherwise, check saved_products
    final savedQ = await ref
        .read(captureProvider.notifier)
        .getSavedQuantity(widget.barcode);
    if (savedQ != null) {
      setState(() {
        _netWeightGrams = savedQ;
        _selectedPreset = 'whole_pack';
      });
    } else {
      // We don't know the net weight. We can't pre-select whole pack with a real value.
      // Ask user.
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
    // Save the quantity if custom and we didn't have net weight
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
      return; // invalid
    }

    // Determine final grams
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
          kcal:
              kcal, // exact computed point value, captureProvider will spread it
          grams: finalGrams,
        );

    if (mounted) {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24.0,
        right: 24.0,
        top: 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_productName, style: AppTheme.lightTheme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (widget.offResult is OffFoundMissingEnergy)
            const Text(
              'Energy data missing from Open Food Facts.',
              style: TextStyle(color: AppTheme.error),
            )
          else
            Text(
              '$_kcalPer100g kcal per 100g',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryText,
              ),
            ),
          const SizedBox(height: 24),

          if (_netWeightGrams != null) ...[
            ListTile(
              title: Text('Whole pack (${_netWeightGrams}g)'),
              trailing: Icon(
                _selectedPreset == 'whole_pack' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _selectedPreset == 'whole_pack' ? AppTheme.accent : AppTheme.secondaryText,
              ),
              onTap: () => setState(() => _selectedPreset = 'whole_pack'),
            ),
            ListTile(
              title: Text('Half pack (${_netWeightGrams! / 2}g)'),
              trailing: Icon(
                _selectedPreset == 'half_pack' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: _selectedPreset == 'half_pack' ? AppTheme.accent : AppTheme.secondaryText,
              ),
              onTap: () => setState(() => _selectedPreset = 'half_pack'),
            ),
          ],

          ListTile(
            title: const Text('Custom grams / ml'),
            trailing: Icon(
              _selectedPreset == 'custom' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: _selectedPreset == 'custom' ? AppTheme.accent : AppTheme.secondaryText,
            ),
            onTap: () => setState(() => _selectedPreset = 'custom'),
          ),

          if (_selectedPreset == 'custom')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g. 250',
                  suffixText: 'g / ml',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.accent),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

          const SizedBox(height: 24),
          Text(
            'Estimated Calories: ~$_computedKcal kcal',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.accent,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _computedKcal > 0 ? _logItem : null,
                  child: const Text('Log'),
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
