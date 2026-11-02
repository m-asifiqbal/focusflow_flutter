/// ============================================================
/// PRAYER SUN ARC — the card's sky: a living scene with the curve on it
/// ============================================================
///
/// What: fills the Prayer card behind its text. A scene (sky by the hour,
/// drifting clouds, stars and moon at night, hills in the accent colour —
/// see sky/prayer_sky_painter.dart) melts into the card's gradient on the
/// text side; on the other side the four-part curve with the sun or moon in
/// front of it, the part's name with a live countdown inside it
/// ("1:29:05 left"), and sunrise / sunset at its two ends.
/// Time: once a second the widget reads the app clock again, so the part,
/// the countdown, the body's place and the sky's colour move on at the exact
/// second a waqt ends — no minute lag, and no need to leave the screen.
/// Motion: when first shown (once per visit — the hero is kept alive while
/// the page is open) the body travels from the curve's start to "now";
/// afterwards clouds drift and stars twinkle at ~30 fps; at sunrise and
/// sunset the old curve fades out and the new one in. Reduce motion or
/// reduced effects: the same picture, standing still.
/// Without a saved location: a plain 6 AM – 6 PM day and no end times.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/prayer_sky_painter.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_palette.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_path.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_sprites.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

export 'package:focusflow/features/prayers/presentation/widgets/sky/sky_path.dart';

class PrayerSunArc extends ConsumerStatefulWidget {
  const PrayerSunArc({
    required this.sunFor,
    required this.use24h,
    required this.ground,
    this.located = true,
    this.southern = false,
    super.key,
  });

  /// Sun times of a day (null without a location).
  final SolarDay? Function(DateTime day) sunFor;
  final bool use24h;

  /// The card's accent colour (the hills are this, darkened).
  final Color ground;

  /// False without a saved location: the end times are left out.
  final bool located;

  /// The moon's lit side flips south of the equator.
  final bool southern;

  @override
  ConsumerState<PrayerSunArc> createState() => _PrayerSunArcState();
}

class _PrayerSunArcState extends ConsumerState<PrayerSunArc>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: PrayerStyle.skyIntro,
  );
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: PrayerStyle.skySwap,
    value: 1,
  );
  final ValueNotifier<double> _ambient = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_onTick);
  Timer? _clock;

  late DateTime _now;
  late SkyFrame _frame;
  SkyPath? _previous;
  double _base = 0;
  Duration _lastPaint = Duration.zero;
  bool _still = false;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _frame = _compute();
    _base = _epochSeconds();
    _ambient.value = _base;
    SkySprites.instance.ensureClouds();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// A week of seconds: clouds and stars are functions of this, so a card
  /// recreated later shows the same sky.
  double _epochSeconds() =>
      ref.read(clockProvider).now().millisecondsSinceEpoch / 1000 % 604800;

  SkyFrame _compute() {
    _now = ref.read(clockProvider).now();
    return SkyFrame(
      path: SkyPath.of(widget.sunFor, _now),
      colors: SkyPalette.at(_now, widget.sunFor),
      previous: _previous,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = context.reduceMotion || FFEffects.reducedOf(context);
    if (still) {
      _still = true;
      _ticker.stop();
      _intro.value = 1;
      _swap.value = 1;
    } else {
      _still = false;
      if (!_settled) {
        _settled = true;
        _intro.forward();
      }
      if (!_ticker.isActive) _ticker.start();
    }
  }

  @override
  void didUpdateWidget(PrayerSunArc old) {
    super.didUpdateWidget(old);
    if (old.sunFor != widget.sunFor) _frame = _compute();
  }

  void _onTick(Duration elapsed) {
    // ~30 fps is plenty for slow clouds and twinkling stars.
    if ((elapsed - _lastPaint).inMilliseconds < 33) return;
    _lastPaint = elapsed;
    _ambient.value =
        _base + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  void _tick() {
    if (!mounted) return;
    final next = _compute();
    if (next.path.isDay != _frame.path.isDay) {
      _previous = _frame.path;
      if (_still) {
        _swap.value = 1;
      } else {
        _swap.forward(from: 0);
      }
    }
    setState(() {
      _frame = SkyFrame(
        path: next.path,
        colors: next.colors,
        previous: _previous,
      );
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ticker.dispose();
    _intro.dispose();
    _swap.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// "1:29:05" (hours unpadded; minutes and seconds two digits).
  static String hms(Duration d) {
    final s = d.isNegative ? 0 : d.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${s ~/ 3600}:${two(s ~/ 60 % 60)}:${two(s % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final path = _frame.path;
    final part = path.part;
    final ink = context.ff.onGradient;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final left = hms(path.until.difference(_now));
    String at(DateTime t) => PrayerFormat.time(t, use24h: widget.use24h);
    final shadows = [
      const Shadow(
        color: PrayerStyle.skyTextShadow,
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ];
    final ends = context.text.meta.copyWith(
      color: ink.withValues(alpha: 0.88),
      fontSize: PrayerStyle.skyEndFont,
      fontWeight: FontWeight.w600,
      shadows: shadows,
    );
    return Semantics(
      label: [
        part.label,
        tr('{time} left', {'time': left}),
        if (widget.located && path.isDay) ...[
          tr('Sunrise {time}', {'time': at(path.from)}),
          tr('Sunset {time}', {'time': at(path.to)}),
        ],
        if (widget.located && !path.isDay) ...[
          tr('Sunset {time}', {'time': at(path.from)}),
          tr('Sunrise {time}', {'time': at(path.to)}),
        ],
      ].join(', '),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          final lay = SkyLayout.of(c.maxWidth, rtl: rtl);
          final x0 = lay.cx - lay.radius - 12;
          final x1 = lay.cx + lay.radius + 12;
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: PrayerSkyPainter(
                    frame: _frame,
                    ground: widget.ground,
                    rtl: rtl,
                    southern: widget.southern,
                    moonAge: SkyMoon.age(_now),
                    animated: !_still,
                    ambient: _ambient,
                    intro: _intro,
                    swap: _swap,
                    sprites: SkySprites.instance,
                  ),
                ),
              ),
              Positioned(
                left: lay.cx - 50,
                width: 100,
                bottom: c.maxHeight - lay.horizon + 8,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        part.label,
                        maxLines: 1,
                        style: context.text.meta.copyWith(
                          color: ink,
                          fontSize: PrayerStyle.skyPartFont,
                          fontWeight: FontWeight.w800,
                          shadows: shadows,
                        ),
                      ),
                      Text(
                        tr('{time} left', {'time': left}),
                        maxLines: 1,
                        style: context.text.meta.copyWith(
                          fontSize: PrayerStyle.sunLeftFont,
                          fontWeight: FontWeight.w600,
                          color: ink.withValues(alpha: 0.88),
                          shadows: shadows,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.located) ...[
                // The dial is not mirrored: sunrise stays on the left.
                Positioned(
                  left: x0,
                  top: lay.horizon + 8,
                  child: Text(at(path.from), maxLines: 1, style: ends),
                ),
                Positioned(
                  right: c.maxWidth - x1,
                  top: lay.horizon + 8,
                  child: Text(at(path.to), maxLines: 1, style: ends),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
