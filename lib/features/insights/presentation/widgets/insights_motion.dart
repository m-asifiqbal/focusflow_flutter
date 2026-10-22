/// ============================================================
/// INSIGHTS MOTION — the small animations of the Insights tab
/// ============================================================
///
/// What: [InsightsReveal] fades + lifts a section in (staggered by its
/// position) when it first appears; [AnimatedCount] counts a number up from
/// zero and eases to the new value when the range changes.
/// Why: the page used to pop in all at once and its numbers jumped when the
/// range changed; this makes loading and switching ranges feel continuous.
/// Both follow reduce motion through `context.motion` (zero length).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';

/// Fades and slides [child] up a few points the first time it is built;
/// sections further down start later ([index] × [stagger]).
class InsightsReveal extends StatefulWidget {
  const InsightsReveal({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  static const Duration stagger = Duration(milliseconds: 70);
  static const Duration base = Duration(milliseconds: 380);

  @override
  State<InsightsReveal> createState() => _InsightsRevealState();
}

class _InsightsRevealState extends State<InsightsReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late Animation<double> _t;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final delay = InsightsReveal.stagger * widget.index;
    final total = InsightsReveal.base + delay;
    _c.duration = context.motion(total);
    // The delay is the front part of the timeline, so one controller
    // drives the whole stagger.
    final begin = total.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(begin, 1, curve: AppMotion.curve),
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
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * 14),
          child: child,
        ),
      ),
    );
  }
}

/// A number that counts up from zero when first shown and eases to a new
/// value when it changes; [format] turns the in-between value into text.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    required this.value,
    required this.format,
    required this.style,
    super.key,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: context.motion(const Duration(milliseconds: 700)),
      curve: AppMotion.curve,
      builder: (context, v, _) => Text(format(v), maxLines: 1, style: style),
    );
  }
}
