/// ============================================================
/// FF PRESSABLE — press-scale feedback (0.98) + reduce-motion helpers
/// ============================================================
///
/// The design system's only tap feedback for cards/tiles is a gentle scale
/// to [AppMotion.pressScale] — no Material ripple on cards. Every animated
/// widget in the library reads [FFMotionContext.reduceMotion] so the
/// platform "Reduce motion" setting turns animations into instant changes.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/app_spacing.dart';

/// Reduce-motion helpers used by every animated FF widget.
extension FFMotionContext on BuildContext {
  /// True when the OS asks for reduced motion.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// [duration], or zero under reduce motion.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}

/// Wraps [child] with a scale-on-press effect and tap/long-press handlers.
class FFPressable extends StatefulWidget {
  const FFPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.pressScale,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale while pressed (1 = no effect).
  final double scale;

  /// Optional accessible label (exposed as a button).
  final String? semanticLabel;
  final HitTestBehavior behavior;

  @override
  State<FFPressable> createState() => _FFPressableState();
}

class _FFPressableState extends State<FFPressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    // Under reduce motion the press feedback is dropped entirely (an
    // instant jump in size is still motion).
    final pressed = _down && !context.reduceMotion;
    Widget child = AnimatedScale(
      scale: pressed ? widget.scale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: widget.child,
    );
    if (_enabled) {
      child = GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: child,
      );
    }
    if (widget.semanticLabel != null) {
      child = Semantics(
        button: _enabled,
        label: widget.semanticLabel,
        child: child,
      );
    }
    return child;
  }
}
