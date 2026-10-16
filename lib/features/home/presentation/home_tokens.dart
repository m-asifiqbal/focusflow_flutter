/// ============================================================
/// HOME TOKENS — measurements of the Home dashboard (mockup 03 / 37)
/// ============================================================
///
/// What: the few sizes specific to Home, measured on design/03_home.png
/// (390 pt wide). Everything else comes from AppSpacing / AppRadii /
/// AppSizes and the text styles.
/// Why: one place to tune the screen against the mockup; widgets never
/// hard-code numbers.
/// ============================================================
library;

import 'package:flutter/painting.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';

abstract final class HomeDimens {
  // Header
  static const double avatar = 44;
  static const double overline = 11.5;
  static const double greeting = 17.5;
  static const double headerTop = AppSpacing.sm;

  /// Between the Search and Bell buttons.
  static const double headerButtonGap = 10;

  // Hero
  static const double heroPadding = 20;
  static const double heroPaddingTop = 22;
  static const double heroTitle = 20;
  static const double heroSubtitle = 13;
  static const double heroBar = 7;
  static const double heroBarGap = 16;
  static const double heroTileGap = 10;
  static const double heroCircle = 170;
  static const double heroCircleOffset = -50;
  static const double heroPercent = 13;

  // Sections
  static const double sectionGap = 22;
  static const double headerGap = 14;

  /// Below a header whose link already pads it to the 44-pt tap height.
  static const double linkHeaderGap = 4;

  /// Section links ("View Monthly", "All Reminders"): lighter than the
  /// shared 15 w600 link, as in the mockup.
  static const double link = 15;

  // Up next
  static const double upNextTile = 44;
  static const double upNextTitle = 16;
  static const double upNextMeta = 14;
  static const double snoozeHeight = 30;
  static const double snoozeText = 13;

  // Tasks
  static const double taskGap = 12;
  static const double taskCheck = 24;
  static const double taskTitle = 15.5;
  static const double taskMeta = 13.5;
  static const double taskMetaIcon = 13;
  static const double taskPin = 13;
  static const double taskPadding = 18;

  /// Pin mark rotation (radians, ≈45°).
  static const double pinTilt = 0.785;

  // Notes
  static const double noteGap = 12;

  // Habits
  static const double ring = 60;
  static const double ringStroke = 6;
  static const double ringIcon = 18;
  static const double ringLabel = 14;
  static const double ringCellMin = 72;

  // Skeleton
  static const double heroSkeleton = 192;
}

/// Colours specific to Home.
abstract final class HomeColors {
  /// Text, bar and glass on the hero gradient: white in both modes, since
  /// the accent gradient is the same in light and dark (mockup 37).
  static const Color onHero = AppPalette.white;
}
