/// ============================================================
/// CONTAINER BACK GESTURE — swipe in from the edge to go back
/// ============================================================
///
/// A page that grows out of a card doesn't use the Cupertino slide, so it
/// doesn't get that transition's edge swipe-back for free. This is the same
/// gesture for the container: drag in from the leading edge (right in RTL)
/// and the container shrinks back toward its card under your finger; let go
/// past a third of the screen (or flick) and it closes, otherwise it springs
/// open again.
///
/// The route stays in charge of its own animation controller:
/// [OpenContainerRoute] is the small surface this widget drives.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// What the back swipe needs from a route (implemented by `FFPageRoute`,
/// which is allowed to drive its own animation controller).
abstract interface class OpenContainerRoute {
  /// Same rules as Cupertino's swipe-back: not the first route, not already
  /// animating or covered, not vetoed by a `PopScope`, no gesture running.
  bool get backGestureEnabled;

  void backGestureStart();

  /// Moves the route's animation to [value] (0 = closed … 1 = open).
  void backGestureTo(double value);

  /// Ends the gesture: pop the route, or spring it back open.
  void backGestureEnd({required bool pop});
}

class ContainerBackGesture extends StatefulWidget {
  const ContainerBackGesture({
    required this.route,
    required this.valueForProgress,
    super.key,
  });

  final OpenContainerRoute route;

  /// Route-animation value at which the container is `p` of the way open.
  final double Function(double p) valueForProgress;

  @override
  State<ContainerBackGesture> createState() => _ContainerBackGestureState();
}

class _ContainerBackGestureState extends State<ContainerBackGesture> {
  /// Fraction of the screen width dragged toward closing (0 … 1).
  double _travel = 0;
  bool _active = false;

  /// Past this much travel (or a flick) letting go closes the page.
  static const double _closeAt = 0.35;

  /// A flick faster than this many screen widths per second decides alone.
  static const double _flick = 1.0;

  late final HorizontalDragGestureRecognizer _drag =
      HorizontalDragGestureRecognizer(debugOwner: this)
        ..onStart = _onStart
        ..onUpdate = _onUpdate
        ..onEnd = _onEnd
        ..onCancel = _onCancel;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double get _width => MediaQuery.sizeOf(context).width;

  @override
  void dispose() {
    _drag.dispose();
    if (_active) widget.route.backGestureEnd(pop: false);
    super.dispose();
  }

  void _onDown(PointerDownEvent event) {
    if (widget.route.backGestureEnabled) _drag.addPointer(event);
  }

  void _onStart(DragStartDetails details) {
    _active = true;
    _travel = 0;
    widget.route.backGestureStart();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (!_active) return;
    final delta = (details.primaryDelta ?? 0) / _width * (_rtl ? -1 : 1);
    _travel = (_travel + delta).clamp(0.0, 1.0);
    widget.route.backGestureTo(widget.valueForProgress(1 - _travel));
  }

  void _onEnd(DragEndDetails details) {
    if (!_active) return;
    _active = false;
    final fling =
        details.velocity.pixelsPerSecond.dx / _width * (_rtl ? -1 : 1);
    final pop = fling.abs() >= _flick ? fling > 0 : _travel > _closeAt;
    widget.route.backGestureEnd(pop: pop);
  }

  void _onCancel() {
    if (!_active) return;
    _active = false;
    widget.route.backGestureEnd(pop: false);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final edge = math.max(20.0, _rtl ? padding.right : padding.left);
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: 0,
      top: 0,
      bottom: 0,
      width: edge,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
      ),
    );
  }
}
