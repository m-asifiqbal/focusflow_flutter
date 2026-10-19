/// ============================================================
/// FF BOTTOM NAV — glass tab pill + a separate fixed "+" circle
/// ============================================================
///
/// Layout (from the hand wireframe):
///
/// ```
///  ╭──────────────────────────────────╮   ╭────╮
///  │ ╭───────────╮                    │   │ +  │   ← Quick Add, fixed
///  │ │ ⌂  Home   │   ▤    ◔    ⚙     │   ╰────╯
///  │ ╰───────────╯                    │
///  ╰──────────────────────────────────╯
///        frosted glass pill (4 tabs)
/// ```
///
/// * The pill holds the four tabs; the active one is an inner pill with icon
///   + label, the others are icon-only (label via Semantics). The inner pill
///   *slides* to the tapped tab while the slots resize around it.
/// * The "+" is its own circle on the right, never part of the pill and never
///   moves; nothing opaque sits around either shape, so screen content
///   scrolls visibly beneath both.
///
/// Performance: ONE AnimationController drives the whole pill (a fractional
/// tab position `p`); slot widths, the sliding highlight, icon colours and
/// label reveal are pure functions of `p` computed in a single builder, text
/// is laid out once (clipped, never re-wrapped), the animated layer sits in a
/// RepaintBoundary, and only the pill (not the "+") carries a BackdropFilter.
///
/// Edge: the pill has a neumorphic edge, the four-shadow recipe (drop glow
/// up-start, drop shade down-end, inner shade inside the top-start edge,
/// inner light inside the bottom-end edge — see [_NeuEdgePainter]). It is a
/// static paint outside the animated layer (no per-frame cost); the glass
/// itself is only a touch frostier (blur 15, a hair more translucent, a faint
/// sheen on the upper half).
///
/// Use with `Scaffold(extendBody: true)` (the app shell does) so content
/// scrolls under the glass; scroll views pad with `context.barClearance`.
/// [currentIndex] is the tab index 0..3 (the + is not a tab).
/// ============================================================
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_effects.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

/// One tab of [FFBottomNav].
@immutable
class FFNavItem {
  const FFNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class FFBottomNav extends StatefulWidget {
  const FFBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onFab,
    this.items = defaultItems,
    this.fabSemanticLabel = 'Quick add',
    super.key,
  });

  /// Active tab (0..3).
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// The separate "+" (always opens Quick Add).
  final VoidCallback onFab;

  /// Exactly 4 tabs.
  final List<FFNavItem> items;
  final String fabSemanticLabel;

  static const List<FFNavItem> defaultItems = [
    FFNavItem(icon: FontAwesomeIcons.house, label: 'Home'),
    FFNavItem(icon: FontAwesomeIcons.layerGroup, label: 'Library'),
    FFNavItem(icon: FontAwesomeIcons.chartPie, label: 'Insights'),
    FFNavItem(icon: FontAwesomeIcons.gear, label: 'Settings'),
  ];

  /// Height of the glass pill.
  static const double height = 64;

  /// The "+" is 1 dp smaller than the pill on every side (62 vs 64): its
  /// gradient and glow read larger than the glass, so this makes the two
  /// look the same height. It stays centred on the pill's centre line.
  static const double fabSize = height - 2;

  static const double _gap = 10;
  static const double _sideMargin = AppSpacing.lg - 1;
  static const double _pillPadding = 8;

  /// Content width of an inactive (icon-only) tab.
  static const double _iconSlot = 38;
  static const double _iconSize = 19;

  /// Smallest icon-only tab (also keeps a ≥ 44 dp tap cell with its margin).
  static const double _minSlot = 30;

  /// Space between the active tab's icon and its label.
  static const double _iconGap = 7;

  /// Padding of the sliding highlight around the icon + label (it hugs the
  /// content instead of filling the leftover width).
  static const double _highlightPadding = 14;
  static const double _highlightHeight = 42;

  /// Tab label: a notch smaller than a button label.
  static const double _labelSize = 12.5;

  @override
  State<FFBottomNav> createState() => _FFBottomNavState();
}

class _FFBottomNavState extends State<FFBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );
  late double _from = widget.currentIndex.toDouble();
  late double _to = widget.currentIndex.toDouble();

  /// Fractional active-tab position (0..3), eased.
  double get _p =>
      lerpDouble(_from, _to, Curves.easeOutCubic.transform(_c.value))!;

  @override
  void didUpdateWidget(FFBottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex == widget.currentIndex) return;
    _from = _p;
    _to = widget.currentIndex.toDouble();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Float just above the home indicator (or 8 pt from the edge).
    final bottomGap = bottomInset > 0
        ? bottomInset - AppSpacing.sm
        : AppSpacing.sm;
    // Reduced effects: no live blur, so a more opaque glass instead.
    final reduced = FFEffects.reducedOf(context);
    final glass = _GlassColors.of(context, reduced: reduced);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          FFBottomNav._sideMargin,
          AppSpacing.sm,
          FFBottomNav._sideMargin,
          bottomGap,
        ),
        child: Row(
          children: [
            Expanded(
              child: _Pill(glass: glass, state: this, blur: !reduced),
            ),
            const SizedBox(width: FFBottomNav._gap),
            _Fab(
              onTap: () {
                FFHaptics.light(context);
                widget.onFab();
              },
              semanticLabel: widget.fabSemanticLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// A backdrop blur around [child] - or [child] alone when [blur] is off
/// (reduced visual effects).
class _MaybeBlur extends StatelessWidget {
  const _MaybeBlur({required this.blur, required this.child});

  final bool blur;
  final Widget child;

  @override
  Widget build(BuildContext context) => blur
      ? BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: child,
        )
      : child;
}

/// The frosted capsule with the sliding highlight and the four tabs.
class _Pill extends StatelessWidget {
  const _Pill({required this.glass, required this.state, required this.blur});

  final _GlassColors glass;
  final _FFBottomNavState state;

  /// A live backdrop blur behind the glass (off under reduced effects).
  final bool blur;

  @override
  Widget build(BuildContext context) {
    const radius = FFBottomNav.height / 2;
    return CustomPaint(
      // The bevel's glow / shade lie outside the capsule (never under the
      // glass).
      painter: _NeuEdgePainter(glass: glass, radius: radius, rim: false),
      child: DecoratedBox(
        // Shadow outside the clip so the capsule lifts off the content.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: glass.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: _MaybeBlur(
            blur: blur,
            child: CustomPaint(
              // The thin bevel rim along the glass edge, over the fill.
              foregroundPainter: _NeuEdgePainter(
                glass: glass,
                radius: radius,
                rim: true,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glass.fill,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: SizedBox(
                  height: FFBottomNav.height,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FFBottomNav._pillPadding,
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        // Width of each tab's highlight = icon + label +
                        // padding (capped to what the pill can hold).
                        // Measured here — on rebuild, never per animation
                        // frame.
                        final items = state.widget.items;
                        final cap =
                            c.maxWidth -
                            (items.length - 1) * FFBottomNav._minSlot;
                        final activeWidths = [
                          for (final item in items)
                            math.min(
                              cap,
                              FFBottomNav._iconSize +
                                  FFBottomNav._iconGap +
                                  _labelWidth(context, item.label) +
                                  2 * FFBottomNav._highlightPadding +
                                  1, // sub-pixel safety
                            ),
                        ];
                        return RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: state._c,
                            builder: (context, _) =>
                                _tabs(c.maxWidth, state._p, activeWidths),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lays the four tabs out for the fractional active position [p].
  ///
  /// Every tab has a "cell"; cells tile the pill exactly. A cell = the tab's
  /// content width + an even margin on both sides ("space-around"), so the
  /// whole cell is tappable and there are no dead zones. The active tab's
  /// content grows to its highlight width, the others shrink to the icon
  /// slot; the margin absorbs the difference, so nothing ever overflows.
  Widget _tabs(double width, double p, List<double> activeWidths) {
    final w = state.widget;
    final n = w.items.length;
    // Narrow phones: shrink the icon slot before anything gets cramped.
    final widest = activeWidths.reduce(math.max);
    final slot = math.min(
      FFBottomNav._iconSlot,
      math.max(FFBottomNav._minSlot, (width - widest) / (n - 1)),
    );
    double margin(double total) => math.max(0.0, (width - total) / (2 * n));

    // Highlight rect of tab [k] at rest (its content slot inside its cell).
    double highlightLeft(int k) {
      final m = margin((n - 1) * slot + activeWidths[k]);
      return m + k * (slot + 2 * m);
    }

    // The highlight glides between the two tabs [p] sits between.
    final f = p.floor().clamp(0, n - 1);
    final c = math.min(f + 1, n - 1);
    final t = p - f;
    final hLeft = lerpDouble(highlightLeft(f), highlightLeft(c), t)!;
    final hWidth = lerpDouble(activeWidths[f], activeWidths[c], t)!;
    const hTop = (FFBottomNav.height - FFBottomNav._highlightHeight) / 2;

    // Strength 1 on the active tab, 0 two tabs away (they always sum to 1).
    final strengths = [
      for (var i = 0; i < n; i++) (1 - (p - i).abs()).clamp(0.0, 1.0),
    ];
    final widths = [
      for (var i = 0; i < n; i++)
        slot + strengths[i] * (activeWidths[i] - slot),
    ];
    final m = margin(widths.fold<double>(0, (a, b) => a + b));

    final children = <Widget>[
      Positioned(
        left: hLeft,
        top: hTop,
        width: hWidth,
        height: FFBottomNav._highlightHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glass.activeFill,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: glass.activeBorder),
          ),
        ),
      ),
    ];
    var left = 0.0;
    for (var i = 0; i < n; i++) {
      final cell = widths[i] + 2 * m;
      children.add(
        Positioned(
          left: left,
          top: 0,
          bottom: 0,
          width: cell,
          child: _Tab(
            item: w.items[i],
            strength: strengths[i],
            selected: i == w.currentIndex,
            glass: glass,
            onTap: () {
              // A soft tick when the tab actually changes.
              if (i != w.currentIndex) FFHaptics.selection(state.context);
              w.onTap(i);
            },
          ),
        ),
      );
      left += cell;
    }
    return Stack(children: children);
  }
}

/// The tab label style (one place: the tab draws it, the pill measures it).
TextStyle _labelStyle(BuildContext context) => context.text.buttonSmall
    .copyWith(fontSize: FFBottomNav._labelSize, fontWeight: FontWeight.w700);

/// Laid-out width of [label] under the nav's (clamped) text scale.
double _labelWidth(BuildContext context, String label) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: _labelStyle(context)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width.ceilToDouble();
}

/// Glass tokens derived from the theme (light: milky white over mint;
/// dark: smoked emerald) so dark mode and accents work for free.
class _GlassColors {
  const _GlassColors({
    required this.fill,
    required this.glow,
    required this.shade,
    required this.innerLight,
    required this.innerShade,
    required this.shadow,
    required this.activeFill,
    required this.activeBorder,
    required this.active,
    required this.inactive,
  });

  final Gradient fill;

  /// The four shadows: drop glow (up-start) and drop shade (down-end)
  /// outside the glass; inner light (inside the bottom-end edge) and inner
  /// shade (inside the top-start edge).
  final Color glow;
  final Color shade;
  final Color innerLight;
  final Color innerShade;
  final List<BoxShadow> shadow;
  final Color activeFill;
  final Color activeBorder;
  final Color active;
  final Color inactive;

  /// [reduced]: the same colours with a nearly opaque fill, for use
  /// without the backdrop blur (content would show through sharply).
  factory _GlassColors.of(BuildContext context, {bool reduced = false}) {
    final glass = _GlassColors._themed(context);
    if (!reduced) return glass;
    final fill = glass.fill as LinearGradient;
    return glass.copyWith(
      fill: LinearGradient(
        begin: fill.begin,
        end: fill.end,
        colors: [for (final c in fill.colors) c.withValues(alpha: 0.95)],
      ),
    );
  }

  _GlassColors copyWith({Gradient? fill}) => _GlassColors(
    fill: fill ?? this.fill,
    glow: glow,
    shade: shade,
    innerLight: innerLight,
    innerShade: innerShade,
    shadow: shadow,
    activeFill: activeFill,
    activeBorder: activeBorder,
    active: active,
    inactive: inactive,
  );

  factory _GlassColors._themed(BuildContext context) {
    final ff = context.ff;
    if (ff.isDark) {
      return _GlassColors(
        fill: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: 0.07), // sheen
              ff.tabBar.withValues(alpha: 0.74),
            ),
            ff.tabBar.withValues(alpha: 0.85),
          ],
        ),
        glow: Colors.white.withValues(alpha: 0.10),
        shade: Colors.black.withValues(alpha: 0.55),
        innerLight: Colors.white.withValues(alpha: 0.14),
        innerShade: Colors.black.withValues(alpha: 0.40),
        shadow: [
          BoxShadow(
            offset: const Offset(0, 14),
            blurRadius: 32,
            spreadRadius: -12,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ],
        activeFill: Colors.white.withValues(alpha: 0.12),
        activeBorder: Colors.white.withValues(alpha: 0.14),
        active: ff.primary,
        inactive: ff.inkMuted,
      );
    }
    return _GlassColors(
      fill: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(
            Colors.white.withValues(alpha: 0.18), // sheen
            ff.surface.withValues(alpha: 0.76),
          ),
          Color.alphaBlend(
            ff.primarySoft.withValues(alpha: 0.35),
            ff.surface,
          ).withValues(alpha: 0.68),
        ],
      ),
      glow: Colors.white.withValues(alpha: 0.9),
      shade: Colors.black.withValues(alpha: 0.16),
      innerLight: Colors.white.withValues(alpha: 0.25),
      innerShade: Colors.black.withValues(alpha: 0.19),
      shadow: [
        BoxShadow(
          offset: const Offset(0, 16),
          blurRadius: 36,
          spreadRadius: -14,
          color: ff.primaryStrong.withValues(alpha: 0.2),
        ),
        ...ff.cardShadow,
      ],
      activeFill: ff.primary.withValues(alpha: 0.12),
      activeBorder: ff.primary.withValues(alpha: 0.16),
      active: ff.primaryStrong,
      inactive: ff.primary.withValues(alpha: 0.55),
    );
  }
}

/// The pill's neumorphic edge — the classic four-shadow recipe (two drop, two
/// inner; Figma: drop white −33/−33 blur 46 @90 %, drop black 28/28 blur 54
/// @16 %, inner white −33/−33 blur 46 @25 %, inner black 28/28 blur 54
/// @25 %) scaled down to a 64 pt capsule. Light comes from the top-start.
///
/// Painted twice from one class:
/// * [rim] false, *behind* the glass and clipped to the outside of the
///   capsule: the two drop shadows — a white glow up-start, a black shade
///   down-end (no tint: it must read as the same light on any canvas);
/// * [rim] true, *over* the glass and clipped to the capsule: the two inner
///   shadows — black along the inside of the top-start edge, white along the
///   inside of the bottom-end edge. That inner pair is what gives the
///   pressed-in "lip" of the reference instead of a flat outline.
/// Static: it repaints only when the pill's size or colours change.
class _NeuEdgePainter extends CustomPainter {
  const _NeuEdgePainter({
    required this.glass,
    required this.radius,
    required this.rim,
  });

  final _GlassColors glass;
  final double radius;
  final bool rim;

  /// The recipe's offsets and blurs (Figma blur = 2 σ), at 64 pt scale.
  static const Offset _lightOffset = Offset(-6, -6);
  static const Offset _darkOffset = Offset(4, 4);
  static const double _lightSigma = 4.6;
  static const double _darkSigma = 5.4;

  static Paint _blurred(Color color, double sigma) => Paint()
    ..color = color
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

  /// Everything outside [hole] (an inner shadow is a blurred "outside").
  static Path _outsideOf(RRect hole, Rect box) => Path.combine(
    PathOperation.difference,
    Path()..addRect(box.inflate(60)),
    Path()..addRRect(hole),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(box, Radius.circular(radius));
    canvas.save();
    if (rim) {
      canvas
        ..clipRRect(shape)
        // Dark inside the top-start edge (the hole shifted down-end), light
        // inside the bottom-end edge (the hole shifted up-start).
        ..drawPath(
          _outsideOf(shape.shift(_darkOffset), box),
          _blurred(glass.innerShade, _darkSigma),
        )
        ..drawPath(
          _outsideOf(shape.shift(_lightOffset), box),
          _blurred(glass.innerLight, _lightSigma),
        );
    } else {
      canvas
        ..clipPath(_outsideOf(shape, box))
        ..drawRRect(shape.shift(_darkOffset), _blurred(glass.shade, _darkSigma))
        ..drawRRect(
          shape.shift(_lightOffset),
          _blurred(glass.glow, _lightSigma),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NeuEdgePainter old) =>
      old.rim != rim ||
      old.radius != radius ||
      old.glass.glow != glass.glow ||
      old.glass.shade != glass.shade ||
      old.glass.innerLight != glass.innerLight ||
      old.glass.innerShade != glass.innerShade;
}

/// One tab slot: the icon (colour eases with [strength]) and, while the tab
/// is (becoming) active, its label sliding open beside it.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.strength,
    required this.selected,
    required this.glass,
    required this.onTap,
  });

  final FFNavItem item;

  /// 0 = icon only … 1 = fully active (label open).
  final double strength;
  final bool selected;
  final _GlassColors glass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(glass.inactive, glass.active, strength)!;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The content keeps its natural size (the label is laid out once and
        // only revealed) and scales down only if a cramped phone / huge text
        // leaves less room than it needs — never clipped, never overflowing.
        // The highlight's side padding fades in with [strength].
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: FFBottomNav._highlightPadding * strength,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: FFBottomNav._iconSize, color: color),
                if (strength > 0.01)
                  ClipRect(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: strength,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: FFBottomNav._iconGap,
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          style: _labelStyle(
                            context,
                          ).copyWith(color: color.withValues(alpha: strength)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The standalone Quick Add circle, right of the pill.
class _Fab extends StatelessWidget {
  const _Fab({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          width: FFBottomNav.fabSize,
          height: FFBottomNav.fabSize,
          decoration: BoxDecoration(
            gradient: ff.primaryGradient,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 12),
                blurRadius: 24,
                spreadRadius: -8,
                color: ff.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
          child: Center(
            child: Icon(FontAwesomeIcons.plus, size: 22, color: ff.onGradient),
          ),
        ),
      ),
    );
  }
}
