/// ============================================================
/// HABIT STYLE — a habit's colour trio + the editor's colour palette
/// ============================================================
///
/// A habit stores its colour as `RRGGBB` (`Habit.colorHex`; null = the
/// Habits module indigo). The editor offers [HabitPalette.colors] — the
/// mockup's blue · emerald · amber · red · indigo first, then extra hues
/// for the "Customize Habit" sheet. Every swatch is an existing theme trio
/// (ModuleStyle / TagPalette), so rings, soft tiles and inks stay
/// consistent with the rest of the app and adapt to dark mode through
/// `ModuleColors.softFor` / `inkFor`. Unknown hexes (imports) get a
/// derived trio.
/// ============================================================
library;

import 'package:flutter/painting.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';

abstract final class HabitPalette {
  static final ModuleColors blue = ModuleStyle.tasks.colors;
  static final ModuleColors emerald = ModuleStyle.notes.colors;
  static final ModuleColors amber = ModuleStyle.vault.colors;
  static const ModuleColors red = TagPalette.high;
  static final ModuleColors indigo = ModuleStyle.habits.colors;
  static const ModuleColors violet = TagPalette.design;
  static const ModuleColors pink = TagPalette.personal;
  static final ModuleColors orange = ModuleStyle.reminders.colors;
  static const ModuleColors sky = TagPalette.travel;
  static final ModuleColors rose = ModuleStyle.scan.colors;

  /// Inline swatches of the editor's Colour row (mockup 15).
  static final List<ModuleColors> inline = [blue, emerald, amber, red, indigo];

  /// Every swatch of the "Customize Habit" sheet.
  static final List<ModuleColors> colors = [
    ...inline,
    violet,
    pink,
    orange,
    sky,
    rose,
  ];

  /// Accessible names of [colors], same order.
  // A getter, not a const list: it must follow the active language.
  static List<String> get names => [
    tr('Blue'),
    tr('Emerald'),
    tr('Amber'),
    tr('Red'),
    tr('Indigo'),
    tr('Violet'),
    tr('Pink'),
    tr('Orange'),
    tr('Sky'),
    tr('Rose'),
  ];

  /// Accessible name of the swatch [c] ("Custom" when not in the palette).
  static String nameOf(ModuleColors c) {
    final i = colors.indexWhere((e) => e.solid == c.solid);
    return i < 0 ? tr('Custom') : names[i];
  }

  /// Storage hex of a swatch.
  static String hexOf(ModuleColors c) => toHex(c.solid);

  /// The trio for a stored [hex]; null → Habits indigo; unknown → derived.
  static ModuleColors forHex(String? hex) {
    final color = parseHex(hex);
    if (color == null) return indigo;
    final argb = color.toARGB32() | 0xFF000000;
    for (final c in colors) {
      if (c.solid.toARGB32() == argb) return c;
    }
    // Translucent soft fill: reads correctly on light and dark surfaces.
    return ModuleColors(
      solid: color,
      soft: color.withValues(alpha: 0.18),
      ink: color,
    );
  }
}

extension HabitColorsX on Habit {
  /// This habit's colour trio.
  ModuleColors get colors => HabitPalette.forHex(colorHex);
}

/// Colours of the habits screens that are not a habit's own colour.
abstract final class HabitAccents {
  /// The 🔥 streak label (orange in every mockup).
  static final Color streak = HabitPalette.orange.solid;

  /// Text / icons on a habit's solid colour, the week squares and the hero
  /// gradient — white in light and dark mode alike.
  static const Color onColor = AppPalette.white;

  /// Outline of the pending check button: the habit colour, faded.
  static Color pendingBorder(ModuleColors c) => c.solid.withValues(alpha: 0.32);

  /// Glow under the detail's "+ Log" button, in the habit colour.
  static List<BoxShadow> buttonGlow(Color c, {required bool dark}) => [
    BoxShadow(
      color: c.withValues(alpha: dark ? 0.25 : 0.4),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// Track of the hero's white ring.
  static Color heroTrack() => onColor.withValues(alpha: 0.22);

  /// The hero's violet glow (dimmer in dark mode, like FFColors.heroShadow).
  static List<BoxShadow> heroShadow({required bool dark}) => [
    for (final s in FFColors.heroShadowFor(HabitPalette.indigo.solid))
      s.copyWith(color: s.color.withValues(alpha: dark ? 0.3 : 0.6)),
  ];

  /// The "Keep the chain going!" hero: indigo-500 → violet-600 (mockup 14),
  /// derived from the Habits module indigo and the violet tag trio.
  static LinearGradient heroGradient() => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HabitPalette.indigo.solid,
      Color.lerp(HabitPalette.violet.solid, HabitPalette.violet.ink, 0.5)!,
    ],
  );
}

/// Size tokens of the habits screens (mockups 14–16, in logical points).
/// Shared sizes (padding, radii, buttons) come from AppSpacing / AppRadii /
/// AppSizes; these are the habit-specific ones, kept in one place.
abstract final class HabitDimens {
  // ── Habit card (14) ──
  static const double cardRing = 50;
  static const double cardRingStroke = 5;
  static const double cardIcon = 17;
  static const double checkButton = AppSizes.minTap;
  static const double checkRadius = 14;
  static const double checkBorder = 2;
  static const double weekSquare = 18;
  static const double weekSquareGap = 4;
  static const double weekSquareRadius = 5;

  static const double ringTextGap = 14;
  static const double cardSubtitle = 13;
  static const double weekLetter = 8.5;
  static const double streakText = 12;
  static const double streakIcon = 12;
  static const double checkIcon = 16;

  // ── Hero (14) ──
  static const double heroRing = 72;
  static const double heroRingStroke = 8;
  static const double heroPadding = 20;
  static const double heroTitle = 18;
  static const double heroPercent = 17;
  static const double heroSubtitle = 13;

  // ── Detail (16) ──
  static const double detailRing = 132;
  static const double detailRingStroke = 11;
  static const double historyTile = 32;
  static const double chartHeight = 124;

  /// How far a section header's 44-pt action link grows the header past its
  /// title line; the gaps around such headers shrink by this much so they
  /// match plain headers (mockup 16).
  static const double actionHeaderInset = 10;

  // ── Editor (15) ──
  static const double previewTile = 64;
  static const double templateTile = 92;
  static const double templateIcon = 36;
  static const double rowTile = 34;
  static const double swatch = 28;
  static const double swatchSlot = 36;
  static const double weekdayCircle = 40;
  static const double stepperButton = 32;
  static const double stepperIcon = 14;
  static const double stepperValue = 22;
  static const double stepperText = 19;
  static const double previewPadding = 20;
  static const double previewIcon = 26;
  static const double previewRadius = 18;
  static const double previewName = 21;
  static const double templateGap = 10;
  static const double templateIconSize = 16;
  static const double rowIcon = 15;
  static const double swatchRing = 2;
  static const double weekdayGap = 6;
  static const double unitMaxWidth = 96;
  static const double frequencyValue = 16;
  static const double templateLabel = 13.5;
  static const double pickerIcon = 20;
  static const double editorRowTitle = 16.5;
  static const double weekdayLetter = 15;

  // ── Detail (16), continued ──
  static const double detailRingIcon = 22;
  static const double detailRingValue = 26;
  static const double detailName = 24;
  static const double actionButtonHeight = 44;
  static const double actionButtonMinWidth = 140;
  static const double actionIcon = 15;
  static const double actionLabel = 15.5;
  static const double statValue = 26;
  static const double statTileHeight = 98;
  static const double chartBarRadius = 7;
  static const double chartBarMaxWidth = 44;
  static const double heatmapGapYear = 2;

  /// Legend swatch of the heatmap (as FFHeatmapLegend) and the cell width
  /// used when the heatmap has no width constraint.
  static const double heatmapLegendCell = 12;
  static const double heatmapFallbackCell = 18;

  /// Week / Month calendar of the heatmap: widest cell, weekday header height.
  static const double calendarCellMax = 44;
  static const double calendarHeader = 22;
  static const double historyIcon = 13;
  static const double historyTitle = 16.5;
  static const double rangeLink = 15;
  static const double statUnit = 13.5;
  static const double chartLabel = 12;
  static const double detailNameSkeleton = 22;

  // ── Skeletons (14) ──
  static const double skeletonTitle = 16;
  static const double skeletonSubtitle = 12;
  static const double skeletonStreak = 14;
  static const double skeletonStreakWidth = 60;
}
