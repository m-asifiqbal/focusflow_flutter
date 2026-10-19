/// ============================================================
/// FF EFFECTS — "reduced visual effects" for the design system
/// ============================================================
///
/// Provided once by the app shell (app.dart, from Settings › Appearance ›
/// Visual effects and the device check in core/performance). The widgets that
/// are expensive to draw read it and fall back to a cheaper look:
///   • the tab bar — a plain, more opaque glass instead of a live blur;
///   • list cards — the page no longer grows out of the tapped card (a plain
///     slide instead);
///   • skeletons — static instead of a sweeping shimmer.
/// Without an [FFEffects] above it (tests, previews) everything is full.
/// ============================================================
library;

import 'package:flutter/widgets.dart';

class FFEffects extends InheritedWidget {
  const FFEffects({required this.reduced, required super.child, super.key});

  /// Draw the cheap versions of the costly effects.
  final bool reduced;

  /// Whether to draw the cheap versions here (false when unprovided).
  static bool reducedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FFEffects>()?.reduced ?? false;

  @override
  bool updateShouldNotify(FFEffects oldWidget) => oldWidget.reduced != reduced;
}
