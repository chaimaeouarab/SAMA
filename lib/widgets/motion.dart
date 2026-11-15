import 'package:flutter/material.dart';

/// Fade + slide-up entrance. [index] staggers items of a list. No timers (one controller with an Interval),
/// and it does nothing when the system asks to reduce motion.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.dy = 18,
  });
  final Widget child;
  final int index;
  final double dy;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    final start = (widget.index * 0.09).clamp(0.0, 0.6);
    _a = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _a.value) * widget.dy),
          child: child,
        ),
      ),
    );
  }
}

/// Route transition: soft fade with a small slide.
Widget samaTransition(
  BuildContext context,
  Animation<double> a,
  Animation<double> _,
  Widget child,
) {
  final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}
