/// ============================================================
/// PAGE TRANSITIONS — one motion language for every navigation
/// ============================================================
///
/// - Pushes (editors, details, settings sub-pages): [FFPageTransitionsBuilder],
///   registered once in the theme so every `GoRoute(builder:)` gets it:
///   slide-in / slide-out with parallax and edge swipe-back, on both
///   platforms.
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
/// from the trailing edge while the page underneath slides out a third of
/// the way with a soft shadow (iOS-style parallax), and slides back on pop.
/// The same slide runs on Android and iOS so the app feels identical on
/// both, and the edge swipe-back gesture works on both.
class FFPageTransitionsBuilder extends PageTransitionsBuilder {
  const FFPageTransitionsBuilder();

  static const _slide = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

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
    return _slide.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
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
