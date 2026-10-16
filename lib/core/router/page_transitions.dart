/// ============================================================
/// PAGE TRANSITIONS — one motion language for every navigation
/// ============================================================
///
/// - Pushes (editors, details, settings sub-pages): [FFPageTransitionsBuilder],
///   registered once in the theme so every `GoRoute(builder:)` gets it.
///   iOS keeps the native Cupertino slide + edge swipe-back; Android gets a
///   calm "fade-through + slight rise", the same feel as the mockups' sheets.
/// - Tab switches: [FFAnimatedBranchContainer] cross-fades the tab's
///   navigators with a small scale, keeping each tab's state alive
///   (StatefulShellRoute.indexedStack semantics).
/// - Item → detail: shared-element Heroes (see core/widgets/ff_hero.dart).
///
/// Everything collapses to an instant switch under reduce motion.
/// ============================================================
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';

/// Theme-level transition for every MaterialPage route.
class FFPageTransitionsBuilder extends PageTransitionsBuilder {
  const FFPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _cupertino.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FFFadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Incoming page fades in while rising 4% / scaling from 0.97; the page
/// underneath fades back slightly so the two never fight for attention.
class FFFadeThroughTransition extends StatelessWidget {
  const FFFadeThroughTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  static final _enterCurve = CurveTween(curve: AppMotion.curve);
  static final _fadeIn = CurveTween(
    curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
  );

  @override
  Widget build(BuildContext context) {
    final enter = animation.drive(_enterCurve);
    final exit = secondaryAnimation.drive(_enterCurve);
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, child) {
        final t = enter.value;
        final out = exit.value;
        return Opacity(
          opacity: (_fadeIn.transform(animation.value)) * (1 - 0.25 * out),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: Transform.scale(
              scale: (0.97 + 0.03 * t) * (1 - 0.02 * out),
              child: child,
            ),
          ),
        );
      },
      child: child,
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
    duration: AppMotion.normal,
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
    return Offstage(
      offstage: !widget.active,
      child: TickerMode(
        enabled: widget.active,
        child: FadeTransition(
          opacity: _t,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(_t),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
