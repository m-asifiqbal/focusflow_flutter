/// ============================================================
/// FF OPEN ORIGIN TRACKER — makes a card the origin of its detail page
/// ============================================================
///
/// Wrap a list card (note card, task row, habit card, vault row…) and the
/// page it opens grows out of the card and closes back into it — the
/// element → details "open container" transition
/// (core/router/page_transitions.dart › FFOpenOrigin).
///
/// It only records the card's on-screen rect when a tap lands on it (a
/// pointer-up without a drag); navigation code stays unchanged.
/// [radius] should match the card's corner radius.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/router/page_transitions.dart';
import 'package:focusflow/core/theme/app_spacing.dart';

class FFOpenOriginTracker extends StatefulWidget {
  const FFOpenOriginTracker({
    required this.child,
    this.radius = AppRadii.card,
    super.key,
  });

  final Widget child;
  final double radius;

  @override
  State<FFOpenOriginTracker> createState() => _FFOpenOriginTrackerState();
}

class _FFOpenOriginTrackerState extends State<FFOpenOriginTracker> {
  Offset? _down;

  /// Movement beyond this is a scroll / swipe, not a tap.
  static const double _slop = 18;

  void _record() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final topLeft = box.localToGlobal(Offset.zero);
    FFOpenOrigin.record(topLeft & box.size, radius: widget.radius);
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
