import 'package:flutter/material.dart';

/// Horizontal swipe between the shell's tabs, with resistance at both ends.
///
/// Wraps the branch container rather than replacing it. That is deliberate:
/// `StatefulShellRoute.indexedStack` keeps every branch mounted, which is what
/// preserves each tab's own navigation stack and scroll position. Rebuilding the
/// shell around a `PageView` would hand that job to a lazy viewport, which
/// disposes off-screen children — so a tab would forget where it was every time
/// the user swiped past it. This keeps the IndexedStack and animates its content
/// instead.
///
/// The gesture: content follows the finger, commits past a quarter of the width
/// (or on a flick), and springs back otherwise. At the first and last tab the
/// travel is damped to a fraction of the drag and springs back — the same "there
/// is nothing past this" cue WhatsApp and Instagram give at the ends of their
/// tab strips.
class SwipeTabSwitcher extends StatefulWidget {
  const SwipeTabSwitcher({
    required this.child,
    required this.index,
    required this.count,
    required this.onSwitch,
    super.key,
  });

  /// The branch container — an IndexedStack showing the current tab.
  final Widget child;

  /// Index of the tab currently on screen.
  final int index;

  /// How many tabs there are.
  final int count;

  /// Called with the tab to move to. The caller drives `goBranch`.
  final ValueChanged<int> onSwitch;

  @override
  State<SwipeTabSwitcher> createState() => _SwipeTabSwitcherState();
}

class _SwipeTabSwitcherState extends State<SwipeTabSwitcher>
    with SingleTickerProviderStateMixin {
  /// Drives both the spring-back and the settle after a commit.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(_onSettleTick);

  /// Current horizontal displacement of the content, in logical pixels.
  double _offset = 0;

  /// Where the settle animation started, so it can interpolate to zero.
  double _settleFrom = 0;

  bool _dragging = false;

  /// Fraction of the width the finger must travel to commit a switch.
  static const _commitFraction = 0.25;

  /// Velocity, in px/s, that commits a switch regardless of distance.
  static const _flickVelocity = 620;

  /// How much of the drag survives at the first/last tab. Low enough to feel
  /// like a wall, high enough that the screen visibly acknowledges the gesture.
  static const _edgeDamping = 0.26;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    setState(() {
      _offset = _settleFrom * (1 - Curves.easeOutCubic.transform(_settle.value));
    });
  }

  void _springTo(double from) {
    _settleFrom = from;
    _settle.forward(from: 0);
  }

  bool _canGo(int delta) {
    final target = widget.index + delta;
    return target >= 0 && target < widget.count;
  }

  void _onDragStart(DragStartDetails _) {
    _settle.stop();
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final width = context.size?.width ?? 1;
    // A positive delta drags rightwards, which reveals the tab to the *left*.
    final wantsPrevious = details.primaryDelta! > 0;
    final blocked = wantsPrevious ? !_canGo(-1) : !_canGo(1);

    setState(() {
      final next = _offset + details.primaryDelta!;
      if (blocked && (wantsPrevious ? next > 0 : next < 0)) {
        // Rubber band: past the end, only a fraction of the drag lands, and it
        // is capped so the content cannot be pulled off screen.
        final damped = next * _edgeDamping;
        _offset = damped.clamp(-width * 0.12, width * 0.12);
      } else {
        _offset = next.clamp(-width, width);
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final width = context.size?.width ?? 1;
    final velocity = details.primaryVelocity ?? 0;

    // Dragging left (negative offset) moves forward through the tabs.
    final forward = _offset < 0;
    final delta = forward ? 1 : -1;
    final travelled = _offset.abs() >= width * _commitFraction;
    final flicked = velocity.abs() >= _flickVelocity &&
        (velocity < 0) == forward;

    if ((travelled || flicked) && _canGo(delta) && _offset != 0) {
      widget.onSwitch(widget.index + delta);
      // The IndexedStack swaps content on the next frame, so start the new tab
      // just off the opposite edge and let it slide home. Without this the
      // incoming tab would pop into place with no continuity from the gesture.
      _springTo(forward ? width * 0.22 : -width * 0.22);
    } else {
      _springTo(_offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Horizontally scrollable content inside a tab (a date strip, a chart)
      // claims the same gesture and wins the arena as the inner competitor, so
      // this only fires on drags the tab itself did not want.
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(_offset, 0),
          // Nothing to composite while the content is at rest, and the tabs
          // hold live widgets, so repainting them every frame of every scroll
          // would be wasteful.
          child: RepaintBoundary(
            child: IgnorePointer(
              // Taps landing mid-drag would hit whatever is under the finger's
              // new position rather than what the user aimed at.
              ignoring: _dragging || _settle.isAnimating,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
