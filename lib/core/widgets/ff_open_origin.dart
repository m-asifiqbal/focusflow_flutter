/// ============================================================
/// FF OPEN ORIGIN TRACKER — makes a card the origin of its detail page
/// ============================================================
///
/// Wrap a list card (note card, task row, habit card, vault row…) and the
/// page it opens grows out of the card and closes back into it — the
/// element → details "open container" transition
/// (core/router/page_transitions.dart › FFOpenOrigin).
///
/// It only records the card when a tap lands on it (a pointer-up without a
/// drag); navigation code stays unchanged. [radius] should match the card's
/// corner radius and [color] its fill when that isn't the standard surface
/// (a tinted note). The record also tells the page where the card is *later*,
/// so closing lands on it even if the list moved meanwhile.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/router/open_origin.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_effects.dart';

class FFOpenOriginTracker extends StatefulWidget {
  const FFOpenOriginTracker({
    required this.child,
    this.radius = AppRadii.card,
    this.color,
    super.key,
  });

  final Widget child;
  final double radius;
  final Color? color;

  @override
  State<FFOpenOriginTracker> createState() => _FFOpenOriginTrackerState();
}

class _FFOpenOriginTrackerState extends State<FFOpenOriginTracker> {
  Offset? _down;

  /// Movement beyond this is a scroll / swipe, not a tap.
  static const double _slop = 18;

  /// The card's rect on screen right now, from its render box — null once
  /// that is gone. Holds the box weakly and never touches the element, so
  /// it is safe to call at any time (even for a card that has just been
  /// removed) and keeps nothing alive.
  static Rect? _rectOf(RenderBox? box) {
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _record() {
    // A drop can rebuild the list (and unmount this card) mid-event.
    if (!mounted) return;
    // Reduced effects: the page slides in like any other (no grow-from-card).
    if (FFEffects.reducedOf(context)) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final rect = _rectOf(box);
    if (rect == null) return;
    final weak = WeakReference<RenderBox>(box);
    // Colours come from the card's own theme (the vault is always dark).
    final ff = context.ff;
    FFOpenOrigin.record(
      rect,
      radius: widget.radius,
      color: widget.color ?? ff.surface,
      pageColor: ff.canvas,
      live: () => _rectOf(weak.target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _down = e.position,
      onPointerUp: (e) {
        final down = _down;
        _down = null;
        if (down != null && (e.position - down).distance <= _slop) _record();
      },
      onPointerCancel: (_) => _down = null,
      child: widget.child,
    );
  }
}
