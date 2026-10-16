/// ============================================================
/// FF PROGRESS RING — animated circular progress with rounded caps
/// ============================================================
///
/// Habit rings (14/16), the Habit Tracker row on Home and the "40%" hero.
/// Animates from the previous value (or 0 on first build) to [progress]
/// with [AppMotion.slow]; jumps under reduce motion.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';

class FFProgressRing extends StatelessWidget {
  const FFProgressRing({
    required this.progress,
    this.size = 64,
    this.stroke = 6,
    this.color,
    this.trackColor,
    this.child,
    this.duration = AppMotion.slow,
    this.semanticLabel,
    super.key,
  });

  /// 0..1 (clamped).
  final double progress;
  final double size;
  final double stroke;

  /// Arc colour (defaults to primary).
  final Color? color;

  /// Track colour (defaults to [color] @15%).
  final Color? trackColor;

  /// Centre content (icon, "6/8").
  final Widget? child;
  final Duration duration;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.ff.primary;
    final track = trackColor ?? c.withValues(alpha: 0.15);
    final p = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(p * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: p),
          duration: context.motion(duration),
          curve: AppMotion.curve,
          builder: (context, value, child) => CustomPaint(
            painter: _RingPainter(
              progress: value,
              stroke: stroke,
              color: c,
              track: track,
            ),
            child: child,
          ),
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double progress;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.stroke != stroke ||
      old.color != color ||
      old.track != track;
}
