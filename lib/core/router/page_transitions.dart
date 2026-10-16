/// ============================================================
/// PAGE TRANSITIONS — one motion language for every navigation
/// ============================================================
///
/// - Pushes (editors, details, settings sub-pages): [FFPageTransitionsBuilder],
///   registered once in the theme so every `GoRoute(builder:)` gets it:
///   slide-in / slide-out with parallax and edge swipe-back, on both
///   platforms.
/// - Tab switches: [FFAnimatedBranchContainer] cross-fades the tab's
///   navigators with a small scale, keeping each tab's state alive
///   (StatefulShellRoute.indexedStack semantics).
/// - Item → detail: shared-element Heroes (see core/widgets/ff_hero.dart).
///
/// Everything collapses to an instant switch under reduce motion.
/// ============================================================
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:focusflow/core/theme/app_spacing.dart';

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
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);

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
      return _OpenContainerTransition(
        origin: origin,
        animation: animation,
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

/// Where the next pushed page grows from (element → details transition).
///
/// List cards are wrapped in `FFOpenOriginTracker` (core/widgets), which
/// calls [record] with the card's on-screen rect when it is tapped. The
/// next page route that starts its transition within [window] claims it:
/// it opens from the card and closes back into it. Any other navigation
/// (FAB, settings rows, deep links) finds nothing pending and slides.
abstract final class FFOpenOrigin {
  // Long enough for pushes that wait on something first (e.g. a vault
  // unlock before the item opens).
  static const Duration window = Duration(milliseconds: 1200);

  static ({Rect rect, double radius, DateTime at})? _pending;
  static final Expando<Object> _claimed = Expando('ff-open-origin');
  static final Object _none = Object();

  /// Records a tapped card's global [rect] and corner [radius].
  static void record(Rect rect, {double radius = AppRadii.card}) =>
      _pending = (rect: rect, radius: radius, at: DateTime.now());

  /// The origin of [route] (decided once, on its first transition build).
  static ({Rect rect, double radius})? claim(Route<Object?> route) {
    final seen = _claimed[route];
    if (seen != null) {
      return identical(seen, _none)
          ? null
          : seen as ({Rect rect, double radius});
    }
    final p = _pending;
    _pending = null;
    final fresh = p != null && DateTime.now().difference(p.at) <= window;
    final origin = fresh ? (rect: p.rect, radius: p.radius) : null;
    _claimed[route] = origin ?? _none;
    return origin;
  }
}

/// Open container: the page is clipped to a rounded rect that grows from
/// the tapped card to full screen (and shrinks back on pop) while its
/// content fades in, over a softly dimmed page.
class _OpenContainerTransition extends StatelessWidget {
  const _OpenContainerTransition({
    required this.origin,
    required this.animation,
    required this.child,
  });

  final ({Rect rect, double radius}) origin;
  final Animation<double> animation;
  final Widget child;

  static const _fadeIn = Interval(0.0, 0.5, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeInOutCubicEmphasized.flipped,
    );
    // The app's own surface (white in light, canvas in dark), not
    // Cupertino's system background.
    final canvas = Theme.of(context).colorScheme.surface;
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, page) {
        final size = MediaQuery.sizeOf(context);
        final t = curved.value;
        final rect = Rect.lerp(origin.rect, Offset.zero & size, t)!;
        final radius = lerpDouble(origin.radius, 0, t)!;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: const Color(0xFF000000).withValues(alpha: 0.16 * t),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  color: canvas,
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    child: SizedBox.fromSize(
                      size: size,
                      child: Opacity(
                        opacity: _fadeIn.transform(animation.value),
                        child: page,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
