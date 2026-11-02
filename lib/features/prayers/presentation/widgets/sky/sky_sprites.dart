/// ============================================================
/// SKY SPRITES — procedural clouds and moon faces for the Prayer card
/// ============================================================
///
/// What: no image assets. The cloud and moon pixels come from
/// sky_pixels.dart; here each is turned into a small [ui.Image] and cached
/// for the life of the app, so recreating the card costs nothing.
/// [SkySprites.ensureClouds] builds one cloud per frame after the card
/// first shows (a few ms each, so the page transition never stalls);
/// [SkySprites.moon] asks for a phase and returns it once it is ready.
/// Why: every later frame just draws images. Tests can
/// [SkySprites.warmUp] to have them all at once.
/// ============================================================
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:focusflow/features/prayers/presentation/widgets/sky/sky_pixels.dart';

/// A cloud ready to draw.
class CloudSprite {
  CloudSprite({
    required this.spec,
    required this.image,
    required this.alpha,
    required this.pw,
    required this.ph,
    required this.cssW,
    required this.cssH,
    required this.solid,
  });

  final CloudSpec spec;
  final ui.Image image;
  final Uint8List alpha;

  /// Pixel and logical size.
  final int pw;
  final int ph;
  final double cssW;
  final double cssH;

  /// How much of the cloud's alpha blocks the light (wisps barely do).
  final double solid;

  /// How much of this cloud covers the point (x, y) given in its own
  /// logical px (0 … 1).
  double coverAt(double x, double y) {
    final ix = (x * pw / cssW).round(), iy = (y * ph / cssH).round();
    if (ix < 0 || iy < 0 || ix >= pw || iy >= ph) return 0;
    return alpha[iy * pw + ix] / 255 * solid;
  }
}

Future<ui.Image> _decode(SkyPixels p) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    p.rgba,
    p.width,
    p.height,
    ui.PixelFormat.rgba8888,
    c.complete,
  );
  return c.future;
}

/// The cache. [clouds] fills one sprite per frame after the card first
/// shows; [moon] asks for a phase and returns it once it is ready.
final class SkySprites {
  SkySprites._();

  static final SkySprites instance = SkySprites._();

  final List<CloudSprite> clouds = [];
  final Map<int, ui.Image> _moons = {};
  final Set<int> _moonAsked = {};
  final List<Future<void> Function()> _jobs = [];

  /// Bumped whenever a sprite arrives, so a still painter redraws.
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool _cloudsAsked = false;
  bool _running = false;

  /// Starts building the clouds (once).
  void ensureClouds() {
    if (_cloudsAsked) return;
    _cloudsAsked = true;
    for (final spec in kCloudSpecs) {
      _enqueue(() async {
        final (px, cw, ch) = spec.wisp ? wispPixels(spec) : cloudPixels(spec);
        clouds.add(
          CloudSprite(
            spec: spec,
            image: await _decode(px),
            alpha: px.alpha,
            pw: px.width,
            ph: px.height,
            cssW: cw,
            cssH: ch,
            solid: spec.wisp ? .3 : 1,
          ),
        );
        revision.value++;
      });
    }
  }

  /// The moon for [age] days (rounded to a tenth), or null while it is
  /// being drawn.
  ui.Image? moon(double age, {required bool southern}) {
    final key = (age * 10).round() + (southern ? 1000 : 0);
    final hit = _moons[key];
    if (hit != null) return hit;
    if (_moonAsked.add(key)) {
      _enqueue(() async {
        _moons[key] = await _decode(
          moonPixels(key % 1000 / 10, southern: southern),
        );
        revision.value++;
      });
    }
    return null;
  }

  /// Builds everything now (tests and previews).
  Future<void> warmUp({double moonAge = 11}) async {
    for (final spec in kCloudSpecs) {
      if (clouds.any((c) => c.spec == spec)) continue;
      final (px, cw, ch) = spec.wisp ? wispPixels(spec) : cloudPixels(spec);
      clouds.add(
        CloudSprite(
          spec: spec,
          image: await _decode(px),
          alpha: px.alpha,
          pw: px.width,
          ph: px.height,
          cssW: cw,
          cssH: ch,
          solid: spec.wisp ? .3 : 1,
        ),
      );
    }
    _cloudsAsked = true;
    for (final southern in [false, true]) {
      final key = (moonAge * 10).round() + (southern ? 1000 : 0);
      _moons[key] ??= await _decode(moonPixels(moonAge, southern: southern));
    }
    revision.value++;
  }

  /// One job per frame, after the frame, so no single frame carries more
  /// than one sprite.
  void _enqueue(Future<void> Function() job) {
    _jobs.add(job);
    if (_running) return;
    _running = true;
    _next();
  }

  void _next() {
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) async {
      if (_jobs.isEmpty) {
        _running = false;
        return;
      }
      try {
        await _jobs.removeAt(0)();
      } catch (e) {
        debugPrint('Sky sprite failed: $e');
      }
      _next();
    });
    binding.ensureVisualUpdate();
  }
}
