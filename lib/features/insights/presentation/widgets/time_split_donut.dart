/// ============================================================
/// TIME SPLIT DONUT — animated callout donut of "Where your time went"
/// ============================================================
///
/// What: a donut of actions per module with a leader line from each slice
/// to its name and percentage (two-line label beside the ring) and the
/// total counting up in the centre. On first show — and when the range
/// changes — the ring sweeps round clockwise, each leader line draws out
/// as the sweep passes its slice and its label fades in. Touching a slice
/// (or its legend row) eases it outward and bolds its line.
/// Why: the ring is sized from the room left after the widest label, so it
/// is as large as the card allows at any width / text scale; labels are
/// measured once per layout (not per frame) and the animation only
/// repaints. Reduce motion shows the finished chart at once.
/// ============================================================
library;

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';

/// One slice: label, action count, module colours.
typedef DonutEntry = (String label, int value, ModuleColors colors);

class TimeSplitDonut extends StatefulWidget {
  const TimeSplitDonut({
    required this.total,
    required this.entries,
    required this.percents,
    required this.touched,
    required this.onTouch,
    super.key,
  });

  final int total;
  final List<DonutEntry> entries;
  final List<int> percents;
  final int? touched;
  final ValueChanged<int?> onTouch;

  @override
  State<TimeSplitDonut> createState() => _TimeSplitDonutState();
}

class _TimeSplitDonutState extends State<TimeSplitDonut>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this);
  late final AnimationController _pop = AnimationController(vsync: this);
  int? _previous;

  static const Duration _introLength = Duration(milliseconds: 1100);
  static const Duration _popLength = Duration(milliseconds: 240);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  /// Sweeps the ring in (or jumps to the end under reduce motion).
  void _play() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    _intro.duration = _introLength;
    _pop.duration = _popLength;
    if (reduce) {
      _intro.value = 1;
    } else {
      _intro.forward(from: 0);
    }
    _pop.value = 1;
  }

  @override
  void didUpdateWidget(TimeSplitDonut old) {
    super.didUpdateWidget(old);
    if (!_sameData(old.entries, widget.entries)) _play();
    if (old.touched != widget.touched) {
      _previous = old.touched;
      if (MediaQuery.disableAnimationsOf(context)) {
        _pop.value = 1;
      } else {
        _pop.forward(from: 0);
      }
    }
  }

  static bool _sameData(List<DonutEntry> a, List<DonutEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].$2 != b[i].$2) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _intro.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final textScaler = MediaQuery.textScalerOf(context);
    final nameStyle = context.text.caption.copyWith(
      fontWeight: FontWeight.w800,
    );
    final percentStyle = context.text.caption.copyWith(
      fontWeight: FontWeight.w700,
      color: ff.ink,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final geo = _DonutGeometry.build(
          width: constraints.maxWidth,
          entries: widget.entries,
          percents: widget.percents,
          total: widget.total,
          brightness: ff.brightness,
          nameStyle: nameStyle,
          percentStyle: percentStyle,
          textScaler: textScaler,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) =>
              widget.onTouch(geo.hit(d.localPosition, widget.touched)),
          child: SizedBox(
            width: geo.size.width,
            height: geo.size.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: geo.size,
                  painter: _DonutPainter(
                    geo: geo,
                    intro: _intro,
                    pop: _pop,
                    touched: widget.touched,
                    previous: _previous,
                  ),
                ),
                AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_intro.value);
                    return Opacity(
                      opacity: t,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(widget.total * t).round()}',
                            style: context.text.stat,
                          ),
                          Text(
                            tr(
                              '{count, plural, one {action} other {actions}}',
                              {'count': widget.total},
                            ),
                            style: context.text.caption.copyWith(
                              color: ff.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One slice's resolved geometry + measured label.
class _Callout {
  _Callout({
    required this.index,
    required this.start,
    required this.end,
    required this.mid,
    required this.color,
    required this.name,
    required this.percent,
    required this.right,
  });

  final int index;

  /// Angles in radians clockwise from 12 o'clock, gap excluded.
  final double start;
  final double end;
  final double mid;
  final Color color;
  final TextPainter name;
  final TextPainter percent;
  final bool right;

  /// Where the label's centre line sits (after overlap resolution).
  double y = 0;

  double get labelWidth => math.max(name.width, percent.width);
  double get labelHeight => name.height + percent.height;
}

class _DonutGeometry {
  _DonutGeometry._({
    required this.size,
    required this.center,
    required this.rOut,
    required this.stroke,
    required this.callouts,
    required this.total,
    required this.entries,
  });

  /// Slice gap and the leader-line pieces (logical px).
  static const double _gap = 2.4 * math.pi / 180;
  static const double _elbow = 12;
  static const double _turn = 8;
  static const double _stub = 8;
  static const double _labelGap = 4;
  static const double _vPad = 8;

  final Size size;
  final Offset center;
  final double rOut;
  final double stroke;
  final List<_Callout> callouts;
  final int total;
  final List<DonutEntry> entries;

  double get rIn => rOut - stroke;

  static _DonutGeometry build({
    required double width,
    required List<DonutEntry> entries,
    required List<int> percents,
    required int total,
    required Brightness brightness,
    required TextStyle nameStyle,
    required TextStyle percentStyle,
    required TextScaler textScaler,
  }) {
    final visible = [
      for (var i = 0; i < entries.length; i++)
        if (entries[i].$2 > 0) i,
    ];

    TextPainter tp(String text, TextStyle style, Color color) => TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    final callouts = <_Callout>[];
    var cursor = 0.0;
    for (final i in visible) {
      final sweep = entries[i].$2 / total * 2 * math.pi;
      final gap = visible.length > 1 ? _gap : 0.0;
      final start = cursor + gap / 2;
      final end = math.max(start + 0.01, cursor + sweep - gap / 2);
      final mid = (start + end) / 2;
      final ink = entries[i].$3.inkFor(brightness);
      callouts.add(
        _Callout(
          index: i,
          start: start,
          end: end,
          mid: mid,
          color: entries[i].$3.solid,
          name: tp(entries[i].$1, nameStyle, ink),
          percent: tp('${percents[i]}%', percentStyle, percentStyle.color!),
          // 0 is 12 o'clock, clockwise: the right half is sin(mid) >= 0.
          right: math.sin(mid) >= 0,
        ),
      );
      cursor += sweep;
    }

    // The ring takes what the widest label leaves: as big as fits.
    final labelW = callouts.fold<double>(
      0,
      (m, c) => math.max(m, c.labelWidth),
    );
    final reserve = labelW + _turn + _stub + _labelGap + 2;
    final rOut = ((width - 2 * reserve) / 2).clamp(54.0, 100.0);
    final stroke = (rOut * 0.36).clamp(20.0, 32.0);
    final labelH = callouts.fold<double>(
      0,
      (m, c) => math.max(m, c.labelHeight),
    );
    final height =
        2 * rOut + 2 * (_elbow + _vPad) + math.max(0.0, labelH - 2 * _vPad);
    final size = Size(width, height);
    final center = Offset(width / 2, height / 2);

    // Natural label rows sit at each slice's elbow height; spread any that
    // would collide, per side.
    for (final c in callouts) {
      c.y = center.dy - (rOut + _elbow) * math.cos(c.mid);
    }
    final gapY = labelH + 4;
    for (final right in [true, false]) {
      final side = callouts.where((c) => c.right == right).toList()
        ..sort((a, b) => a.y.compareTo(b.y));
      _spread(side, gapY, labelH / 2, height - labelH / 2);
    }
    return _DonutGeometry._(
      size: size,
      center: center,
      rOut: rOut,
      stroke: stroke,
      callouts: callouts,
      total: total,
      entries: entries,
    );
  }

  /// Pushes sorted rows apart by at least [gap] inside [min]..[max].
  static void _spread(List<_Callout> rows, double gap, double min, double max) {
    if (rows.isEmpty) return;
    rows.first.y = math.max(rows.first.y, min);
    for (var k = 1; k < rows.length; k++) {
      rows[k].y = math.max(rows[k].y, rows[k - 1].y + gap);
    }
    if (rows.last.y > max) {
      rows.last.y = max;
      for (var k = rows.length - 2; k >= 0; k--) {
        rows[k].y = math.min(rows[k].y, rows[k + 1].y - gap);
      }
    }
  }

  /// The slice under [p] (toggling [current] off when it is tapped again),
  /// or null for a tap outside the ring.
  int? hit(Offset p, int? current) {
    final d = p - center;
    final dist = d.distance;
    if (dist < rIn - 10 || dist > rOut + _elbow + 10) return null;
    var a = math.atan2(d.dx, -d.dy); // clockwise from 12 o'clock
    if (a < 0) a += 2 * math.pi;
    for (final c in callouts) {
      // Tolerate the hairline gaps between slices.
      if (a >= c.start - _gap && a <= c.end + _gap) {
        return current == c.index ? null : c.index;
      }
    }
    return null;
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.geo,
    required this.intro,
    required this.pop,
    required this.touched,
    required this.previous,
  }) : super(repaint: Listenable.merge([intro, pop]));

  final _DonutGeometry geo;
  final Animation<double> intro;
  final Animation<double> pop;
  final int? touched;
  final int? previous;

  /// Radians the sweep runs ahead of a label's slice before it is whole.
  static const double _reveal = 0.55;

  /// 0..1 emphasis of slice [i] (eases in when touched, out when released).
  double _emphasis(int i) {
    final t = Curves.easeOutBack.transform(pop.value.clamp(0.0, 1.0));
    if (i == touched) return t;
    if (i == previous) return 1 - pop.value;
    return 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeInOutCubic.transform(intro.value);
    final sweepLimit = eased * 2 * math.pi;
    // Labels follow the sweep and finish after it, so the last slices'
    // lines (which the sweep reaches only at the very end) complete too.
    final reach = eased * (2 * math.pi + _reveal);
    final c = geo.center;

    for (final callout in geo.callouts) {
      final e = _emphasis(callout.index);
      final stroke = geo.stroke + 5 * e;
      final radius = geo.rOut - geo.stroke / 2 + 2.5 * e;
      final end = math.min(callout.end, sweepLimit);
      if (end > callout.start) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: radius),
          callout.start - math.pi / 2,
          end - callout.start,
          false,
          Paint()
            ..color = callout.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt,
        );
      }
      _paintCallout(canvas, callout, e, reach);
    }
  }

  void _paintCallout(Canvas canvas, _Callout k, double e, double reach) {
    // Appears once the sweep has passed the slice's middle.
    final reveal = ((reach - k.mid) / _reveal).clamp(0.0, 1.0);
    if (reveal <= 0) return;
    final c = geo.center;
    final sign = k.right ? 1.0 : -1.0;
    Offset polar(double r) =>
        Offset(c.dx + r * math.sin(k.mid), c.dy - r * math.cos(k.mid));

    final rStart = geo.rOut + 3 * e;
    final start = polar(rStart);
    final elbow = polar(geo.rOut + _DonutGeometry._elbow);
    // Where the line leaves the diagonal and runs level to the label.
    final side = sign > 0
        ? math.max(elbow.dx + 4, c.dx + geo.rOut + 6)
        : math.min(elbow.dx - 4, c.dx - geo.rOut - 6);
    final lineEnd = side + sign * _DonutGeometry._stub;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(side, k.y)
      ..lineTo(lineEnd, k.y);

    final lineColor = k.color.withValues(alpha: 0.55 + 0.45 * e);
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 + 0.8 * e
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // The line draws itself out from the slice.
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * reveal), linePaint);
    }
    canvas.drawCircle(
      start,
      2 + e,
      Paint()..color = k.color.withValues(alpha: reveal),
    );

    if (reveal < 1) {
      // Label fades in over the last of the line.
      final a = ((reveal - 0.5) * 2).clamp(0.0, 1.0);
      if (a <= 0) return;
      canvas.saveLayer(
        Offset.zero & geo.size,
        Paint()..color = Color.fromRGBO(0, 0, 0, a),
      );
      _paintLabel(canvas, k, lineEnd, sign);
      canvas.restore();
    } else {
      _paintLabel(canvas, k, lineEnd, sign);
    }
  }

  void _paintLabel(Canvas canvas, _Callout k, double lineEnd, double sign) {
    final w = geo.size.width;
    final lw = k.labelWidth;
    // Right labels start after the line, left ones end before it; both stay
    // inside the card even when large text leaves little room.
    var x = sign > 0
        ? lineEnd + _DonutGeometry._labelGap
        : lineEnd - _DonutGeometry._labelGap - lw;
    x = x.clamp(0.0, math.max(0.0, w - lw));
    final top = k.y - k.labelHeight / 2;
    final dx = sign > 0 ? 0.0 : lw;
    k.name.paint(canvas, Offset(x + (sign > 0 ? 0 : dx - k.name.width), top));
    k.percent.paint(
      canvas,
      Offset(x + (sign > 0 ? 0 : dx - k.percent.width), top + k.name.height),
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.geo != geo || old.touched != touched || old.previous != previous;
}
