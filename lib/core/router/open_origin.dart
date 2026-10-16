/// ============================================================
/// OPEN ORIGIN — the card a page grows out of
/// ============================================================
///
/// List cards are wrapped in `FFOpenOriginTracker` (core/widgets), which
/// calls [FFOpenOrigin.record] when a card is tapped. The next page route
/// that starts within [FFOpenOrigin.window] claims it
/// ([FFOpenOrigin.claim]): that page opens from the card and closes back
/// into it (core/router/open_container_transition.dart). Any other
/// navigation (FAB, settings rows, deep links) finds nothing pending and
/// slides in instead.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/app_spacing.dart';

/// The card a page opens from.
class FFOpenOriginData {
  const FFOpenOriginData({
    required this.rect,
    required this.radius,
    this.color,
    this.live,
  });

  /// Where the card was when it was tapped (global coordinates).
  final Rect rect;

  /// The card's corner radius.
  final double radius;

  /// The card's fill, when it isn't the standard surface (tinted notes…).
  final Color? color;

  /// Where the card is *now*, or null once it is gone. Lets the page land
  /// exactly on the card even if the list scrolled or re-sorted while the
  /// page was open.
  final Rect? Function()? live;

  /// The rect to open from / close into: the card's live position while it
  /// is still on [screen], otherwise where it was tapped.
  Rect current(Size screen) {
    final now = live?.call();
    if (now == null || !now.overlaps(Offset.zero & screen)) return rect;
    return now;
  }
}

abstract final class FFOpenOrigin {
  // Long enough for pushes that wait on something first (e.g. a vault
  // unlock before the item opens).
  static const Duration window = Duration(milliseconds: 1200);

  static FFOpenOriginData? _pending;
  static DateTime? _pendingAt;
  static final Expando<Object> _claimed = Expando('ff-open-origin');
  static final Object _none = Object();

  /// Records a tapped card's global [rect] and corner [radius].
  static void record(
    Rect rect, {
    double radius = AppRadii.card,
    Color? color,
    Rect? Function()? live,
  }) {
    _pending = FFOpenOriginData(
      rect: rect,
      radius: radius,
      color: color,
      live: live,
    );
    _pendingAt = DateTime.now();
  }

  /// The origin of [route] (decided once, on its first transition build).
  static FFOpenOriginData? claim(Route<Object?> route) {
    final seen = _claimed[route];
    if (seen != null) {
      return identical(seen, _none) ? null : seen as FFOpenOriginData;
    }
    final p = _pending;
    final at = _pendingAt;
    _pending = null;
    _pendingAt = null;
    final fresh =
        p != null && at != null && DateTime.now().difference(at) <= window;
    final origin = fresh ? p : null;
    _claimed[route] = origin ?? _none;
    return origin;
  }
}
