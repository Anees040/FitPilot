import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitpilot/application/providers/capture_provider.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/core/ui/app_snackbar.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/buttons.dart';
import 'package:fitpilot/data/remote/open_food_facts_client.dart';

/// Shown when a scanned barcode is in no online database.
///
/// Open Food Facts has very thin coverage of Pakistani and other local brands,
/// so "not found" is the common case here, not the exception. Rather than
/// dead-ending, the user teaches the app the product once: it is saved to the
/// local catalog keyed by that barcode, so every later scan of the same item
/// resolves instantly and works offline.
class UnknownBarcodeSheet extends ConsumerStatefulWidget {
  final String barcode;

  /// Prefilled when the user reached here by scanning the nutrition label, so
  /// OCR results carry straight into the form.
  final String? initialName;
  final int? initialKcalPer100g;

  /// Invoked when the user wants to read the product's label with the camera
  /// instead of typing the numbers.
  final VoidCallback? onScanLabel;

  const UnknownBarcodeSheet({
    super.key,
    required this.barcode,
    this.initialName,
    this.initialKcalPer100g,
    this.onScanLabel,
  });

  @override
  ConsumerState<UnknownBarcodeSheet> createState() => _UnknownBarcodeSheetState();
}

class _UnknownBarcodeSheetState extends ConsumerState<UnknownBarcodeSheet> {
  late final TextEditingController _name;
  late final TextEditingController _kcal;
  late final TextEditingController _serving;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
    _kcal = TextEditingController(
      text: widget.initialKcalPer100g?.toString() ?? '',
    );
    _serving = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _serving.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final name = _name.text.trim();
    final kcal = int.parse(_kcal.text.trim());
    final serving = double.tryParse(_serving.text.trim());

    try {
      await ref.read(captureProvider.notifier).saveUnknownProduct(
        barcode: widget.barcode,
        name: name,
        kcalPer100g: kcal,
        netWeightGrams: serving,
      );
      if (!mounted) return;

      // Hand the freshly-taught product back so the caller can go straight to
      // the quantity step, exactly as if the lookup had succeeded.
      Navigator.of(context).pop(
        OffFound(
          productName: name,
          kcalPer100g: kcal,
          netWeightGrams: serving,
          isLocal: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, "Couldn't save that product. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_box_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('New product', style: theme.textTheme.h2),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'This barcode is not in the global food database — a lot of local '
                'brands never are. Add it once and FitPilot will remember it, even offline.',
                style: theme.textTheme.caption,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ext.surfaceRaised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ext.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 15, color: ext.textDisabled),
                    const SizedBox(width: 6),
                    Text(widget.barcode, style: theme.textTheme.caption),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (widget.onScanLabel != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: 'Read the Nutrition Facts label',
                    onPressed: _saving ? null : widget.onScanLabel,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'or type it in',
                    style: theme.textTheme.caption.copyWith(color: ext.textDisabled),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AppTextField(
                controller: _name,
                label: 'Product name (e.g. Lays Masala 40 g)',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _kcal,
                label: 'Calories per 100 g',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null) return 'Enter the kcal per 100 g';
                  if (n <= 0 || n > 900) return 'Must be between 1 and 900';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _serving,
                label: 'Pack size in grams (optional)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  final n = double.tryParse(text);
                  if (n == null || n <= 0) return 'Enter a valid weight';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Save and log it',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
