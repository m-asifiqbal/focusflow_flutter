/// ============================================================
/// OPEN CONTAINER — a page that grows out of the card you tapped
/// ============================================================
///
/// The page is laid out once at full-screen size and only *revealed*: a
/// rounded container grows from the card's rect to the whole screen (and
/// back on pop) while the page content, scaled to the container's width,
/// fades in over it. Nothing re-lays-out per frame — only the container's
/// rect, clip, colour and alphas change.
///
/// What makes it feel like a native app rather than a pop-up:
/// * the container dissolves in over the real card (and out again at the
///   end of the way back) instead of replacing it, so the card never
///   blinks to a blank rectangle — and an edited card lands as its new self;
/// * the way back lands on the card's *live* position (it may have scrolled
///   or re-sorted); it is shorter than the way out and the dissolve into the
///   card is tied to the *end of the clock*, so the page is gone exactly when
///   the motion looks finished — no invisible tail that blocks touches;
/// * a mid-flight pop continues from where the container is, no jump;
/// * once it is full screen the clip and scale are no-ops, so an open page
///   pays nothing for having been opened this way.
/// ============================================================
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/router/container_back_gesture.dart';
import 'package:focusflow/core/router/open_origin.dart';
import 'package:focusflow/core/theme/app_theme.dart';

abstract final class _Motion {
  /// Route durations while a container is in play (see FFPage).
  static const Duration opening = Duration(milliseconds: 340);
  static const Duration closing = Duration(milliseconds: 260);

  /// Opening: leaves the card softly, accelerates, settles at full screen.
  static const Curve open = Cubic(0.3, 0.0, 0.1, 1.0);

  /// Closing, as a function of how far back the container still has to go
  /// (1 → 0): leaves at once, lands on the card with a short soft tail.
  static final Curve close = const Cubic(0.25, 0.0, 0.2, 1.0).flipped;

  /// The container fades in over the first part of the opening clock…
  static const double surfaceIn = 0.14;

  /// …and dissolves into the real card over the last part of the closing one.
  static const double surfaceOut = 0.30;

  /// The page content fades in / out between these container sizes
  /// (0 = on the card, 1 = full screen).
  static const double contentFrom = 0.40;
  static const double contentTo = 0.85;

  static const double scrim = 0.16;
}

class OpenContainerTransition extends StatefulWidget {
  /// Route durations while a container is in play.
  static const Duration opening = _Motion.opening;
  static const Duration closing = _Motion.closing;

  const OpenContainerTransition({
    required this.origin,
    required this.animation,
    required this.child,
    this.route,
    super.key,
  });

  /// The route-animation value at which the container is [p] of the way
  /// open — the inverse of the opening curve, for gestures that move the
  /// container directly (the edge swipe-back).
  static double animationValueFor(double p) {
    final target = p.clamp(0.0, 1.0);
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (_Motion.open.transform(mid) < target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  final FFOpenOriginData origin;

  /// When given, a swipe in from the leading edge closes the page.
  final OpenContainerRoute? route;

  /// The route's animation: 0 → 1 opening, 1 → 0 closing.
  final Animation<double> animation;
  final Widget child;

  @override
  State<OpenContainerTransition> createState() =>
      _OpenContainerTransitionState();
}

class _OpenContainerTransitionState extends State<OpenContainerTransition> {
  // Where the animation (x), the container (p) and its surface alpha were
  // when a reversal began, so the way back starts exactly where the way out
  // stopped.
  double _fromX = 1;
  double _fromP = 1;
  double _fromSurface = 1;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(OpenContainerTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      old.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse) return;
    _fromX = widget.animation.value.clamp(0.0, 1.0);
    _fromP = _Motion.open.transform(_fromX);
    _fromSurface = _openSurface(_fromX);
  }

  static double _openSurface(double x) =>
      Curves.easeInOut.transform((x / _Motion.surfaceIn).clamp(0.0, 1.0));

  /// Container progress: 0 = on its card … 1 = full screen.
  double get _progress {
    final a = widget.animation;
    if (a.status != AnimationStatus.reverse) {
      return _Motion.open.transform(a.value.clamp(0.0, 1.0));
    }
    if (_fromX <= 0) return 0;
    return _fromP * _Motion.close.transform(_left);
  }

  /// How much of the way back is still ahead on the clock (1 → 0).
  double get _left =>
      _fromX <= 0 ? 0 : (widget.animation.value / _fromX).clamp(0.0, 1.0);

  /// Opacity of the container's own surface (the card dissolves into it on
  /// the way out and back out of it on the way home).
  double get _surface {
    final a = widget.animation;
    if (a.status != AnimationStatus.reverse) {
      return _openSurface(a.value.clamp(0.0, 1.0));
    }
    return _fromSurface *
        Curves.easeInOut.transform(
          (_left / _Motion.surfaceOut).clamp(0.0, 1.0),
        );
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final screen = MediaQuery.sizeOf(context);
    final origin = widget.origin;
    // The page the container settles as, and the card it starts as.
    final pageFill = origin.pageColor ?? ff.canvas;
    final cardFill = Color.alphaBlend(origin.color ?? ff.surface, pageFill);
    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      builder: (context, page) {
        final p = _progress;
        final rect = Rect.lerp(
          origin.current(screen),
          Offset.zero & screen,
          p,
        )!;
        final surface = _surface;
        final content = Curves.easeOut.transform(
          ((p - _Motion.contentFrom) /
                  (_Motion.contentTo - _Motion.contentFrom))
              .clamp(0.0, 1.0),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: const Color(
                    0xFF000000,
                  ).withValues(alpha: _Motion.scrim * p),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  lerpDouble(origin.radius, 0, p)!,
                ),
                clipBehavior: p >= 1 ? Clip.none : Clip.antiAlias,
                child: ColoredBox(
                  color: Color.lerp(
                    cardFill,
                    pageFill,
                    p,
                  )!.withValues(alpha: surface),
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    child: SizedBox.fromSize(
                      size: screen,
                      child: Opacity(opacity: content, child: page),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.route != null)
              ContainerBackGesture(
                route: widget.route!,
                valueForProgress: OpenContainerTransition.animationValueFor,
              ),
          ],
        );
      },
    );
  }
}
