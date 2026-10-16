/// ============================================================
/// HABIT CONFETTI — the one-off "Perfect day!" burst (screen 14 states)
/// ============================================================
///
/// A light, dependency-free confetti shower painted over the list when the
/// last habit due today is checked in. [HabitConfettiController.play]
/// starts it; it never blocks touches and is skipped entirely under reduce
/// motion. Pieces use the habit palette so the burst matches the cards.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

/// Starts a [HabitConfetti] burst from outside the widget.
class HabitConfettiController extends ChangeNotifier {
  void play() => notifyListeners();
}

class HabitConfetti extends StatefulWidget {
  const HabitConfetti({required this.controller, super.key});

  final HabitConfettiController controller;

  /// Length of one burst.
  static const Duration duration = Duration(milliseconds: 1800);

  @override
  State<HabitConfetti> createState() => _HabitConfettiState();
}

class _HabitConfettiState extends State<HabitConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: HabitConfetti.duration,
  );
  List<_Piece> _pieces = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_play);
  }

  @override
  void didUpdateWidget(HabitConfetti old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_play);
      widget.controller.addListener(_play);
    }
  }

  void _play() {
    if (!mounted || context.reduceMotion) return;
    final rnd = math.Random();
    final colors = [for (final c in HabitPalette.colors) c.solid];
    setState(() {
      _pieces = [
        for (var i = 0; i < 48; i++)
          _Piece(
            x: rnd.nextDouble(),
            drift: (rnd.nextDouble() - 0.5) * 0.3,
            delay: rnd.nextDouble() * 0.25,
            spin: (rnd.nextDouble() - 0.5) * 14,
            size: AppSpacing.xs + rnd.nextDouble() * AppSpacing.sm,
            color: colors[i % colors.length],
          ),
      ];
    });
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_play);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => _anim.isAnimating
              ? CustomPaint(
                  size: Size.infinite,
                  painter: _ConfettiPainter(_pieces, _anim.value),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.drift,
    required this.delay,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double drift;
  final double delay;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeIn.transform(local);
      final dx = (p.x + p.drift * local) * size.width;
      final dy = -p.size + eased * (size.height * 0.85);
      paint.color = p.color.withValues(alpha: 1 - local * local);
      canvas
        ..save()
        ..translate(dx, dy)
        ..rotate(p.spin * local)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
