/// ============================================================
/// PAGE TRANSITIONS — one motion language for every navigation
/// ============================================================
///
/// - Pushes (editors, details, settings sub-pages): [FFPageTransitionsBuilder],
///   registered once in the theme so every `GoRoute(builder:)` gets it:
///   slide-in / slide-out with parallax and edge swipe-back, on both
///   platforms ([FFSlideTransition]).
/// - Tab switches: [FFAnimatedBranchContainer] fades the tab's navigators,
///   keeping each tab's state alive (StatefulShellRoute.indexedStack
///   semantics).
/// - Item → detail: a page opened from a tapped card grows out of it and
///   closes back into it ([OpenContainerTransition]; the card is recorded
///   by `FFOpenOriginTracker`, see core/router/open_origin.dart).
///
/// Everything collapses to an instant switch under reduce motion.
/// ============================================================
library;

import 'package:flutter/cupertino.dart';
import 'package:focusflow/core/router/container_back_gesture.dart';
import 'package:focusflow/core/router/open_container_transition.dart';
import 'package:focusflow/core/router/open_origin.dart';
import 'package:focusflow/core/theme/app_spacing.dart';

export 'package:focusflow/core/router/open_origin.dart';

/// Theme-level transition for every MaterialPage route: the page slides in
/// from the trailing edge while the page underneath slides out part of the
/// way and dims (parallax), and slides back on pop. The same slide runs on
/// Android and iOS so the app feels identical on both, and the edge
/// swipe-back gesture works on both. Full-screen dialogs keep the
/// Cupertino slide-up.
class FFPageTransitionsBuilder extends PageTransitionsBuilder {
  const FFPageTransitionsBuilder();

  static const _slideUp = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => FFSlideTransition.forward;

  @override
  Duration get reverseTransitionDuration => FFSlideTransition.reverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    // Opened from a list card: grow out of that card (open container).
    final origin = FFOpenOrigin.claim(route);
    if (origin != null) {
      return OpenContainerTransition(
        origin: origin,
        animation: animation,
        route: route is OpenContainerRoute ? route as OpenContainerRoute : null,
        child: child,
      );
    }
    if (route.fullscreenDialog) {
      return _slideUp.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FFSlideTransition(
      route: route,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// The push / pop slide. Lighter than the Cupertino one it replaces:
/// shorter (280 / 240 ms instead of 380 / 300), with a curve that is quick
/// out of the gate and settles without a long crawl at the end (Cupertino's
/// tail is what made it feel slow on 60 Hz screens, where the last frames
/// barely move), and no edge-shadow gradient repainted on every frame — the
/// page underneath dims instead (a flat fill). The page itself is never
/// rebuilt or re-laid-out: only its translation changes, and it sits in the
/// route's own repaint boundary.
///
/// While the user drags the edge swipe-back the slide follows the finger
/// one to one (no curve), as Cupertino's does.
class FFSlideTransition extends StatefulWidget {
  const FFSlideTransition({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
  });

  static const Duration forward = Duration(milliseconds: 280);
  static const Duration reverse = Duration(milliseconds: 240);

  /// How far the page underneath travels (a fraction of the width)…
  static const double parallax = 0.28;

  /// …and how dark it gets.
  static const double dim = 0.10;

  final PageRoute<Object?> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<FFSlideTransition> createState() => _FFSlideTransitionState();
}

class _FFSlideTransitionState extends State<FFSlideTransition> {
  late CurvedAnimation _in;
  late CurvedAnimation _under;

  // Quick start, soft landing — both ways (on pop the reverse curve runs
  // 1 → 0, so ease-*in* is what leaves fast).
  static CurvedAnimation _curved(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _in = _curved(widget.animation);
    _under = _curved(widget.secondaryAnimation);
  }

  @override
  void didUpdateWidget(FFSlideTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _in.dispose();
      _in = _curved(widget.animation);
    }
    if (old.secondaryAnimation != widget.secondaryAnimation) {
      _under.dispose();
      _under = _curved(widget.secondaryAnimation);
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _under.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final route = widget.route;
    final gestureRoute = route is OpenContainerRoute
        ? route as OpenContainerRoute
        : null;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([
            widget.animation,
            widget.secondaryAnimation,
          ]),
          child: widget.child,
          builder: (context, page) {
            final linear = route.navigator?.userGestureInProgress ?? false;
            final t = linear ? widget.animation.value : _in.value;
            final s = linear ? widget.secondaryAnimation.value : _under.value;
            return FractionalTranslation(
              translation: Offset(
                dir * (1 - t) - dir * FFSlideTransition.parallax * s,
                0,
              ),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  page!,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: const Color(
                          0xFF000000,
                        ).withValues(alpha: FFSlideTransition.dim * s),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (gestureRoute != null)
          ContainerBackGesture(route: gestureRoute, valueForProgress: _same),
      ],
    );
  }

  static double _same(double p) => p;
}

/// `StatefulShellRoute.indexedStack(navigatorContainerBuilder: …)`:
/// cross-fades between tab branches while keeping every branch alive.
class FFAnimatedBranchContainer extends StatelessWidget {
  const FFAnimatedBranchContainer({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _Branch(
            active: i == currentIndex,
            animate: !reduce,
            child: children[i],
          ),
      ],
    );
  }
}

class _Branch extends StatefulWidget {
  const _Branch({
    required this.active,
    required this.animate,
    required this.child,
  });

  final bool active;
  final bool animate;
  final Widget child;

  @override
  State<_Branch> createState() => _BranchState();
}

/// Inactive tabs are Offstage (state kept, not painted, not hit-tested,
/// invisible to finders and screen readers — like IndexedStack); the tab
/// being shown fades in with a slight scale-up.
class _BranchState extends State<_Branch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: AppMotion.curve,
  );

  @override
  void didUpdateWidget(_Branch old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (widget.animate) {
        _c.forward(from: 0);
      } else {
        _c.value = 1;
      }
    } else if (!widget.active) {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inactive tabs are Offstage (state kept, not painted). The tab being
    // shown fades in over a short 150 ms — opacity only: no scale/transform,
    // so a whole screen is never re-rasterised through a transform layer.
    return Offstage(
      offstage: !widget.active,
      child: TickerMode(
        enabled: widget.active,
        child: RepaintBoundary(
          child: FadeTransition(opacity: _t, child: widget.child),
        ),
      ),
    );
  }
}
