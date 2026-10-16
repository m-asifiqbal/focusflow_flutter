/// ============================================================
/// SPACING · RADII · SIZES · MOTION (design-system tokens)
/// ============================================================
///
/// 4-pt grid. Screen padding 24 (lists/cards) or 20 (grouped settings).
/// Never inline magic numbers for these in feature code — use the tokens.
/// ============================================================
library;

import 'package:flutter/animation.dart';

abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal screen padding for lists / cards.
  static const double screen = 24;

  /// Horizontal screen padding for grouped settings lists.
  static const double grouped = 20;

  /// Gap between cards.
  static const double cardGap = 12;

  /// Top padding before a section.
  static const double section = 26;

  /// Row separators are inset this far from the left edge.
  static const double dividerInset = 60;

  /// Gap between the last scrollable item and the floating nav bar. Add it
  /// to `MediaQuery.paddingOf(context).bottom` (the shell reserves the bar's
  /// height there) — or just use `context.barClearance`.
  static const double bottomBarClearance = 8;

  /// Gap between a list row's leading tile and its title.
  static const double rowLeadingGap = 14;

  /// Vertical padding of a list row (and a time pill's outer margin).
  static const double rowVertical = 10;

  /// Vertical padding inside a small pill (time pills).
  static const double pillVertical = 7;
}

abstract final class AppRadii {
  static const double pill = 999;
  static const double button = 16;
  static const double input = 16;
  static const double card = 22;
  static const double row = 20;
  static const double hero = 28;
  static const double sheet = 34;

  /// Floating bottom sheet (all four corners, inset from the screen edges).
  static const double sheetFloating = 30;
  static const double dialog = 30;

  static const double tileSm = 9;
  static const double tile = 12;
  static const double tileLg = 14;
  static const double statTile = 16;
}

abstract final class AppSizes {
  static const double primaryButton = 56;
  static const double secondaryButton = 52;
  static const double search = 52;
  static const double rowMin = 60;
  static const double chip = 36;
  static const double roundButton = 44;
  static const double minTap = 44;
  static const double fab = 60;
  static const double fabRing = 4;
  static const double fabRaise = 28;
  static const double tabBar = 64;
  static const double sheetHandleWidth = 44;
  static const double sheetHandleHeight = 6;
  static const double iconTile = 38;
  static const double iconTileLg = 46;

  /// Small icon tile of settings rows (32) and its glyph (14).
  static const double iconTileSm = 32;
  static const double tileGlyph = 14;

  /// Glyph in a hero / gradient card circle.
  static const double heroGlyph = 18;

  /// Height of a time-wheel (CupertinoPicker) sheet body.
  static const double wheelPicker = 180;

  /// Hairline separators / thin strokes.
  static const double hairline = 1.5;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;

  /// Undo snackbar lifetime.
  static const Duration snackbar = Duration(seconds: 5);

  /// Card press scale.
  static const double pressScale = 0.98;
}
