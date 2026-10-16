/// ============================================================
/// TOKEN GAPS — derived colours the design system needs but FFColors lacks
/// ============================================================
///
/// The widgets below `lib/core/widgets/` must not hard-code colours, but a
/// few values from the mockups have no semantic token yet. They live here,
/// in ONE place, as an extension on [FFColors] so they can be promoted into
/// `FFColors` later without touching any widget: an instance member with the
/// same name automatically wins over these extension getters.
///
/// Internal to the widget library (not exported from `widgets.dart`).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';

extension FFTokenGaps on FFColors {
  /// Text/icons drawn on [FFColors.primaryGradient] (hero, FAB, primary
  /// button). White in both modes because the gradient never changes.
  // TODO(theme): promote to FFColors.onGradient.
  Color get onGradient => AppPalette.white;

  /// Solid destructive fill (Delete button, swipe Delete) — rose-500 in both
  /// modes; [FFColors.danger] is rose-300 in dark, too light under white text.
  // TODO(theme): promote to FFColors.dangerSolid.
  Color get dangerSolid => AppPalette.rose500;

  /// Destructive text on [FFColors.dangerSoft] (rose-600 / rose-300).
  // TODO(theme): promote to FFColors.dangerStrong.
  Color get dangerStrong => isDark ? danger : AppPalette.rose600;

  /// Neutral "Archive" fill used by swipe actions (slate-500).
  // TODO(theme): promote to FFColors.neutralSolid.
  Color get neutralSolid => AppPalette.slate500;

  /// Neutral "Archive" text on [FFColors.surfaceMuted] (slate-700 / ink).
  // TODO(theme): promote to FFColors.neutralInk.
  Color get neutralInk => isDark ? ink : AppPalette.slate700;

  /// emerald-50-style faint primary fill ("Archive instead", soft buttons).
  // TODO(theme): promote to FFColors.primaryFaint.
  Color get primaryFaint => isDark
      ? primarySoft
      : Color.alphaBlend(primarySoft.withValues(alpha: 0.5), surface);

  /// Focused input ring (emerald-400-ish: the accent's 500 shade in light).
  // TODO(theme): promote to FFColors.focusRing.
  Color get focusRing => isDark ? primary : primaryGradient.colors.first;

  /// Text on a [FFColors.vaultAccent] fill (emerald-950).
  // TODO(theme): promote to FFColors.vaultOnAccent.
  Color get vaultOnAccent => AppPalette.emerald950;

  /// Active chip fill inside the vault (emerald-600 per mockup 18).
  // TODO(theme): promote to FFColors.vaultChipActive.
  Color get vaultChipActive => AppPalette.emerald600;

  /// Sheet drag handle.
  Color get sheetHandle => ink.withValues(alpha: isDark ? 0.22 : 0.14);
}
