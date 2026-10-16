/// ============================================================
/// FF CHECK CIRCLE — round completion checkbox with a bounce
/// ============================================================
///
/// Unchecked: 2 pt ring in [color] @35%. Checked: filled [color] + white
/// tick. Checking plays a scale bounce (skipped under reduce motion) and a
/// light haptic (unless haptics are off — [FFHaptics]). The hit target is at least 44×44 around the visual circle.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

class FFCheckCircle extends StatefulWidget {
  const FFCheckCircle({
    required this.checked,
    required this.onChanged,
    this.color,
    this.size = 26,
    this.tapTarget = AppSizes.minTap,
    this.semanticLabel,
    super.key,
  });

  final bool checked;

  /// Null makes it read-only.
  final ValueChanged<bool>? onChanged;

  /// Module colour (defaults to primary-ish success green).
  final Color? color;

  /// Visual diameter (24–26 in the mockups).
  final double size;

  /// Layout/hit size (the circle is centred inside).
  final double tapTarget;

  /// e.g. "Complete Review Q3 strategy".
  final String? semanticLabel;

  @override
  State<FFCheckCircle> createState() => _FFCheckCircleState();
}

class _FFCheckCircleState extends State<FFCheckCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0.8,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.8,
        end: 1.15,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.15,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 35,
    ),
  ]).animate(_bounce);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !widget.checked;
    if (next) {
      FFHaptics.light(context);
      if (!context.reduceMotion) _bounce.forward(from: 0);
    } else {
      FFHaptics.selection(context);
    }
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final color = widget.color ?? ff.success;
    final checked = widget.checked;
    final dim = widget.size;
    final box = widget.tapTarget > dim ? widget.tapTarget : dim;
    return Semantics(
      checked: checked,
      enabled: widget.onChanged != null,
      label: widget.semanticLabel,
      onTap: widget.onChanged == null ? null : _toggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onChanged == null ? null : _toggle,
        child: SizedBox.square(
          dimension: box,
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedContainer(
                duration: context.motion(AppMotion.fast),
                curve: AppMotion.curve,
                width: dim,
                height: dim,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? color : Colors.transparent,
                  border: Border.all(
                    color: checked ? color : color.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: AnimatedOpacity(
                  opacity: checked ? 1 : 0,
                  duration: context.motion(AppMotion.fast),
                  child: Icon(
                    FontAwesomeIcons.check,
                    size: dim * 0.48,
                    color: ff.onGradient,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
