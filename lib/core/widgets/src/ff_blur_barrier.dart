/// ============================================================
/// BLUR BARRIER — modal barrier with the design's backdrop blur (σ 3)
/// ============================================================
///
/// Sheets and dialogs dim the page with `ff.scrim` *and* blur it slightly.
/// Routes override `buildModalBarrier()` and wrap the stock barrier with
/// [ffBlurBarrier]; the blur fades in with the route animation.
/// Internal to the widget library.
/// ============================================================
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// Backdrop blur sigma for sheets and dialogs.
const double kFFBackdropBlur = 3;

Widget ffBlurBarrier(Widget barrier, Animation<double>? animation) {
  if (animation == null) {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: kFFBackdropBlur,
        sigmaY: kFFBackdropBlur,
      ),
      child: barrier,
    );
  }
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final sigma = kFFBackdropBlur * animation.value.clamp(0.0, 1.0);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      );
    },
    child: barrier,
  );
}
