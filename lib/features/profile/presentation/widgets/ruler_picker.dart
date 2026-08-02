import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RulerPicker extends StatefulWidget {
  final double minValue;
  final double maxValue;
  final double initialValue;
  final ValueChanged<double> onChanged;
  
  /// The value difference between each minor tick mark.
  final double step;
  
  /// The interval between major ticks.
  final double majorTickInterval;
  
  /// Builder for the large central value display.
  final Widget Function(BuildContext context, double value) valueBuilder;
  
  /// Formatter for the label under major ticks.
  final String Function(double value) tickFormatter;

  const RulerPicker({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.initialValue,
    required this.onChanged,
    required this.step,
    required this.majorTickInterval,
    required this.valueBuilder,
    required this.tickFormatter,
  });

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> with SingleTickerProviderStateMixin {
  late double _value;
  late AnimationController _animController;
  Animation<double>? _animation;
  
  final double _tickSpacing = 12.0;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(widget.minValue, widget.maxValue);
    _animController = AnimationController(vsync: this);
    _animController.addListener(() {
      if (_animation != null) {
        _updateValue(_animation!.value, notify: true);
      }
    });
  }
  
  @override
  void didUpdateWidget(RulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent completely replaces the initialValue (like unit toggle), jump to it instantly.
    if (oldWidget.initialValue != widget.initialValue) {
      _animController.stop();
      _updateValue(widget.initialValue.clamp(widget.minValue, widget.maxValue), notify: false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
  
  double get _pixelsPerUnit => _tickSpacing / widget.step;

  void _updateValue(double newValue, {bool notify = true}) {
    double clampedValue = newValue.clamp(widget.minValue, widget.maxValue);
    
    // Check for major tick crossing to play haptics
    if (_value != clampedValue) {
      
      // If we crossed a major tick boundary (epsilon went from high to low to high)
      // A simple way is to check if rounding to major tick changes.
      int oldMajor = (_value / widget.majorTickInterval).round();
      int newMajor = (clampedValue / widget.majorTickInterval).round();
      if (oldMajor != newMajor) {
         HapticFeedback.selectionClick();
      }
      
      setState(() {
        _value = clampedValue;
      });
      if (notify) {
        widget.onChanged(_value);
      }
    }
  }

  void _onPanDown(DragDownDetails details) {
    _animController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    double deltaValue = -details.delta.dx / _pixelsPerUnit;
    _updateValue(_value + deltaValue, notify: true);
  }

  void _onPanEnd(DragEndDetails details) {
    double velocity = -details.velocity.pixelsPerSecond.dx / _pixelsPerUnit;
    
    // Estimated stop position with simple friction
    double estimatedTarget = _value + (velocity * 0.15); 
    
    // Snap to nearest step
    double snappedTarget = (estimatedTarget / widget.step).round() * widget.step;
    snappedTarget = snappedTarget.clamp(widget.minValue, widget.maxValue);
    
    double distance = (snappedTarget - _value).abs();
    if (distance == 0) return;
    
    // Calculate duration based on distance & velocity
    int durationMs = 200;
    if (velocity.abs() > 0) {
      durationMs = (distance / velocity.abs() * 1000).round();
      durationMs = durationMs.clamp(100, 400); // keep it feeling responsive
    }
    
    _animation = Tween<double>(begin: _value, end: snappedTarget).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    
    _animController.duration = Duration(milliseconds: durationMs);
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Snap value for the large display so it rounds cleanly to step precision
    // to avoid floating point artifacts like 55.000000001
    double displayValue = (_value / widget.step).round() * widget.step;
    // ensure exactly zero if very close
    if (displayValue.abs() < 1e-10) displayValue = 0.0;
    
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Value display
        widget.valueBuilder(context, displayValue),
        const SizedBox(height: 24),
        // Ruler
        GestureDetector(
          onHorizontalDragDown: _onPanDown,
          onHorizontalDragUpdate: _onPanUpdate,
          onHorizontalDragEnd: _onPanEnd,
          onHorizontalDragCancel: () => _animController.stop(),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 60,
            width: double.infinity,
            child: CustomPaint(
              painter: _RulerPainter(
                value: _value,
                minValue: widget.minValue,
                maxValue: widget.maxValue,
                step: widget.step,
                majorTickInterval: widget.majorTickInterval,
                tickSpacing: _tickSpacing,
                tickFormatter: widget.tickFormatter,
                primaryColor: theme.colorScheme.primary,
                onSurfaceColor: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final double step;
  final double majorTickInterval;
  final double tickSpacing;
  final String Function(double) tickFormatter;
  final Color primaryColor;
  final Color onSurfaceColor;

  _RulerPainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.step,
    required this.majorTickInterval,
    required this.tickSpacing,
    required this.tickFormatter,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double pixelsPerUnit = tickSpacing / step;
    final double centerOffset = size.width / 2;
    
    final double leftValue = value - (centerOffset / pixelsPerUnit);
    final double rightValue = value + (centerOffset / pixelsPerUnit);
    
    // Expand bounds slightly to ensure smooth entering/exiting of ticks
    final int firstTickIndex = ((leftValue - step) / step).floor();
    final int lastTickIndex = ((rightValue + step) / step).ceil();
    
    final Paint tickPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.2)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
      
    final TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    for (int i = firstTickIndex; i <= lastTickIndex; i++) {
      double tickValue = i * step;
      // Precision fix for floating point math
      tickValue = (tickValue / step).round() * step;
      
      if (tickValue < minValue || tickValue > maxValue) continue;
      
      double x = centerOffset + ((tickValue - value) * pixelsPerUnit);
      
      // Determine tick size
      final epsilon = step / 2;
      final isMajorTick = (tickValue % majorTickInterval).abs() < epsilon;
                       
      final isMediumTick = !isMajorTick && (tickValue % (majorTickInterval / 2)).abs() < epsilon;
      
      double tickHeight = isMajorTick ? 24 : (isMediumTick ? 16 : 8);
      
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - tickHeight),
        tickPaint,
      );
      
      if (isMajorTick) {
        textPainter.text = TextSpan(
          text: tickFormatter(tickValue),
          style: TextStyle(
            fontSize: 12,
            color: onSurfaceColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        );
        textPainter.layout();
        // Draw text centered above the tick, avoiding HTML-like constrained wrapping
        canvas.drawText(
          textPainter,
          Offset(x - (textPainter.width / 2), size.height - tickHeight - textPainter.height - 4),
        );
      }
    }
    
    // Draw center indicator
    final centerPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(
      Offset(centerOffset, size.height - 40),
      Offset(centerOffset, size.height),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) {
    return oldDelegate.value != value || 
           oldDelegate.step != step || 
           oldDelegate.majorTickInterval != majorTickInterval ||
           oldDelegate.primaryColor != primaryColor;
  }
}

extension CanvasExtension on Canvas {
  void drawText(TextPainter textPainter, Offset offset) {
    textPainter.paint(this, offset);
  }
}
