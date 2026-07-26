import 'package:flutter/material.dart';
import 'package:fitpilot/core/theme/app_theme.dart';

class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > 1;
    final canIncrease = value < 20;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onPressed: canDecrease ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 48,
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.titleLarge,
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          onPressed: canIncrease ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(
            color: onPressed != null
                ? AppTheme.accent
                : AppTheme.secondaryText.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onPressed != null
              ? AppTheme.accent
              : AppTheme.secondaryText.withOpacity(0.5),
        ),
      ),
    );
  }
}
