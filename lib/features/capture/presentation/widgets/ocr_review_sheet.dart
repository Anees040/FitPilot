import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitpilot/core/theme/app_theme.dart';
import 'package:fitpilot/data/ocr/nutrition_label_parser.dart';
import 'package:fitpilot/application/providers/capture_provider.dart';
import 'package:fitpilot/core/ui/app_text_field.dart';
import 'package:fitpilot/core/ui/buttons.dart';

class OcrReviewSheet extends ConsumerStatefulWidget {
  final NutritionLabelResult result;

  const OcrReviewSheet({super.key, required this.result});

  @override
  ConsumerState<OcrReviewSheet> createState() => _OcrReviewSheetState();
}

class _OcrReviewSheetState extends ConsumerState<OcrReviewSheet> {
  late TextEditingController _kcalController;
  late TextEditingController _servingController;
  late NutritionBasis _basis;

  @override
  void initState() {
    super.initState();
    _kcalController = TextEditingController(
      text: widget.result.kcal?.value.toString() ?? '',
    );
    _servingController = TextEditingController(
      text: widget.result.servingSizeGrams?.value.toString() ?? '',
    );
    _basis = widget.result.basis?.value ?? NutritionBasis.per100g;
  }

  @override
  void dispose() {
    _kcalController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  Future<void> _logItem() async {
    final kcal = int.tryParse(_kcalController.text);
    if (kcal == null || kcal <= 0) return;

    final serving = double.tryParse(_servingController.text) ?? 100.0;

    await ref
        .read(captureProvider.notifier)
        .logScannedItem(
          barcode: null,
          name: 'Scanned Label',
          kcal: kcal,
          grams: _basis == NutritionBasis.per100g ? 100 : serving,
        );

    if (mounted) {
      context.go('/today');
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required double? confidence,
  }) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColors>()!;
    final isLowConfidence = confidence != null && confidence < 0.8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: label.toUpperCase(),
                controller: controller,
                keyboardType: TextInputType.number,
                // AppTextField doesn't have fillColor exposed directly for warnings,
                // but we can add a warning message below if needed.
              ),
            ),
            if (isLowConfidence)
              Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 24,
                  color: ext.warning,
                ),
              ),
          ],
        ),
        if (isLowConfidence)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Please verify this value',
              style: theme.textTheme.caption.copyWith(color: ext.warning),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
          Text(
            'Verify Label',
            style: theme.textTheme.h2,
          ),
          const SizedBox(height: 24),
          _buildField(
            label: 'Energy (kcal)',
            controller: _kcalController,
            confidence: widget.result.kcal?.confidence,
          ),
          const SizedBox(height: 16),
          Text('BASIS', style: theme.textTheme.overline),
          const SizedBox(height: 8),
          DropdownButtonFormField<NutritionBasis>(
            initialValue: _basis,
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
            ),
            items: const [
              DropdownMenuItem(
                value: NutritionBasis.per100g,
                child: Text('Per 100g'),
              ),
              DropdownMenuItem(
                value: NutritionBasis.per100ml,
                child: Text('Per 100ml'),
              ),
              DropdownMenuItem(
                value: NutritionBasis.perServing,
                child: Text('Per Serving'),
              ),
              DropdownMenuItem(
                value: NutritionBasis.perPiece,
                child: Text('Per Piece'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _basis = val);
            },
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Serving Size (g/ml)',
            controller: _servingController,
            confidence: widget.result.servingSizeGrams?.confidence,
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
                  onPressed: _logItem,
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
