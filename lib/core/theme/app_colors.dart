/// ============================================================
/// APP COLORS — design tokens (prompts/01_DESIGN_SYSTEM.md › Colours)
/// ============================================================
///
/// Three layers:
///   1. [AppPalette] — raw Tailwind-style swatches. Only theme code uses it.
///   2. [AccentColor] — the swappable `primary` family (Settings › Appearance).
///   3. [FFColors] — the semantic tokens every widget reads through
///      `context.ff` (a [ThemeExtension], so light/dark/accent swap at runtime).
///
/// Feature screens must never hard-code a colour: read `context.ff.*`, or
/// [ModuleStyle] for a module's solid/soft/ink trio.
///
/// **Android/Kotlin analogy:** `colors.xml` + a Material3 `ColorScheme`
/// wrapped in a custom `CompositionLocal`.
/// ============================================================
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';

/// Raw swatches (light-mode hex values from the design system).
abstract final class AppPalette {
  // ── Emerald (primary) ──
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald300 = Color(0xFF6EE7B7);
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const emerald800 = Color(0xFF065F46);
  static const emerald900 = Color(0xFF064E3B);
  static const emerald950 = Color(0xFF022C22);
  static const teal700 = Color(0xFF0F766E);

  // ── Canvas ──
  static const mint = Color(0xFFF0FDFA);
  static const sheet = Color(0xFFF7FBFA);
  static const darkCanvas = Color(0xFF06231C);
  static const darkTabBar = Color(0xFF0B2E25);
  static const vaultCanvas = Color(0xFF05382C);
  static const vaultTabBar = Color(0xFF042A21);

  // ── Status ──
  static const rose50 = Color(0xFFFFF1F2);
  static const rose100 = Color(0xFFFFE4E6);
  static const rose300 = Color(0xFFFDA4AF);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const rose700 = Color(0xFFBE123C);
  static const red100 = Color(0xFFFEE2E2);
  static const red500 = Color(0xFFEF4444);
  static const red700 = Color(0xFFB91C1C);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber300 = Color(0xFFFCD34D);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const orange50 = Color(0xFFFFF7ED);
  static const orange100 = Color(0xFFFFEDD5);
  static const orange400 = Color(0xFFFB923C);
  static const orange500 = Color(0xFFF97316);
  static const orange600 = Color(0xFFEA580C);
  static const orange700 = Color(0xFFC2410C);

  // ── Module / tag hues ──
  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue400 = Color(0xFF60A5FA);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const sky500 = Color(0xFF0EA5E9);
  static const indigo100 = Color(0xFFE0E7FF);
  static const indigo400 = Color(0xFF818CF8);
  static const indigo500 = Color(0xFF6366F1);
  static const indigo600 = Color(0xFF4F46E5);
  static const indigo700 = Color(0xFF4338CA);
  static const violet100 = Color(0xFFEDE9FE);
  static const violet500 = Color(0xFF8B5CF6);
  static const violet600 = Color(0xFF7C3AED);
  static const violet700 = Color(0xFF6D28D9);
  static const pink100 = Color(0xFFFCE7F3);
  static const pink400 = Color(0xFFF472B6);
  static const pink500 = Color(0xFFEC4899);
  static const pink600 = Color(0xFFDB2777);
  static const pink700 = Color(0xFFBE185D);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);

  static const white = Color(0xFFFFFFFF);
}

/// The user-selectable accent (Settings › Appearance). Swaps the whole
/// `primary` token family; canvas, module colours and status colours stay.
enum AccentColor {
  emerald(
    primary: AppPalette.emerald600,
    primaryDark: AppPalette.emerald400,
    soft: AppPalette.emerald100,
    gradient: [
      AppPalette.emerald500,
      AppPalette.emerald600,
      AppPalette.teal700,
    ],
    strong: AppPalette.emerald700,
  ),
  blue(
    primary: AppPalette.blue600,
    primaryDark: AppPalette.blue400,
    soft: AppPalette.blue100,
    gradient: [AppPalette.blue500, AppPalette.blue600, AppPalette.blue700],
    strong: AppPalette.blue700,
  ),
  indigo(
    primary: AppPalette.indigo600,
    primaryDark: AppPalette.indigo400,
    soft: AppPalette.indigo100,
    gradient: [
      AppPalette.indigo500,
      AppPalette.indigo600,
      AppPalette.indigo700,
    ],
    strong: AppPalette.indigo700,
  ),
  pink(
    primary: AppPalette.pink600,
    primaryDark: AppPalette.pink400,
    soft: AppPalette.pink100,
    gradient: [AppPalette.pink500, AppPalette.pink600, AppPalette.pink700],
    strong: AppPalette.pink700,
  ),
  orange(
    primary: AppPalette.orange600,
    primaryDark: AppPalette.orange400,
    soft: AppPalette.orange100,
    gradient: [
      AppPalette.orange500,
      AppPalette.orange600,
      AppPalette.orange700,
    ],
    strong: AppPalette.orange700,
  ),
  slate(
    primary: AppPalette.slate600,
    primaryDark: AppPalette.slate400,
    soft: AppPalette.slate200,
    gradient: [AppPalette.slate500, AppPalette.slate600, AppPalette.slate700],
    strong: AppPalette.slate700,
  );

  const AccentColor({
    required this.primary,
    required this.primaryDark,
    required this.soft,
    required this.gradient,
    required this.strong,
  });

  /// Name shown in the accent picker, in the active language.
  String get label => switch (this) {
    emerald => tr('Emerald'),
    blue => tr('Blue'),
    indigo => tr('Indigo'),
    pink => tr('Pink'),
    orange => tr('Orange'),
    slate => tr('Slate'),
  };

  /// Buttons, active tab, links, switches (light mode).
  final Color primary;

  /// Same role in dark mode.
  final Color primaryDark;

  /// Icon tiles, tag backgrounds, selected chips (light mode).
  final Color soft;

  /// Top-left → bottom-right hero / FAB / primary-button gradient.
  final List<Color> gradient;

  /// Darker shade for text links / labels on soft backgrounds.
  final Color strong;

  static AccentColor fromName(String? name) => AccentColor.values.firstWhere(
    (a) => a.name == name,
    orElse: () => AccentColor.emerald,
  );
}

/// Semantic colour tokens. Read with `context.ff` (see app_theme.dart).
@immutable
class FFColors extends ThemeExtension<FFColors> {
  const FFColors({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceBorder,
    required this.surfaceMuted,
    required this.sheet,
    required this.primary,
    required this.primaryStrong,
    required this.onPrimary,
    required this.primarySoft,
    required this.primaryGradient,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.divider,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.success,
    required this.highlight,
    required this.chipBorder,
    required this.snackbar,
    required this.onSnackbar,
    required this.snackbarAction,
    required this.tabBar,
    required this.scrim,
    required this.cardShadow,
    required this.heroShadow,
    required this.vaultCanvas,
    required this.vaultSurface,
    required this.vaultBorder,
    required this.vaultTabBar,
    required this.vaultInk,
    required this.vaultInkMuted,
    required this.vaultAccent,
  });

  final Brightness brightness;

  /// Screen background (mint in light mode).
  final Color canvas;

  /// Cards and grouped lists.
  final Color surface;

  /// 1px card border — transparent in light mode, white @10% in dark.
  final Color surfaceBorder;

  /// Secondary surface (slate-100-ish chip / disabled fills).
  final Color surfaceMuted;

  /// Bottom-sheet background (#F7FBFA).
  final Color sheet;

  final Color primary;

  /// Darker primary for links/labels on soft backgrounds (emerald-700).
  final Color primaryStrong;
  final Color onPrimary;
  final Color primarySoft;
  final LinearGradient primaryGradient;

  /// Primary text.
  final Color ink;

  /// Secondary text, meta.
  final Color inkMuted;

  /// Chevrons, section labels, placeholders.
  final Color inkFaint;

  /// Row separators.
  final Color divider;

  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final Color success;

  /// Search-match highlight background (emerald-200).
  final Color highlight;

  /// Outline of unselected chips / quick-capture field (emerald-100).
  final Color chipBorder;

  /// Undo snackbar (emerald-950) and its text/action colours.
  final Color snackbar;
  final Color onSnackbar;
  final Color snackbarAction;

  /// Bottom tab bar background.
  final Color tabBar;

  /// Modal backdrop (emerald-950 @45%).
  final Color scrim;

  final List<BoxShadow> cardShadow;
  final List<BoxShadow> heroShadow;

  // ── Vault "secure mode" (always dark) ──
  final Color vaultCanvas;
  final Color vaultSurface;
  final Color vaultBorder;
  final Color vaultTabBar;
  final Color vaultInk;
  final Color vaultInkMuted;
  final Color vaultAccent;

  bool get isDark => brightness == Brightness.dark;

  /// Card shadow: `0 6 24 -12 rgba(6,78,59,.18)`.
  static const List<BoxShadow> lightCardShadow = [
    BoxShadow(
      offset: Offset(0, 6),
      blurRadius: 24,
      spreadRadius: -12,
      color: Color(0x2E064E3B),
    ),
  ];

  /// Hero / FAB shadow: `0 20 40 -18 rgba(5,150,105,.75)`.
  static List<BoxShadow> heroShadowFor(Color primary) => [
    BoxShadow(
      offset: const Offset(0, 20),
      blurRadius: 40,
      spreadRadius: -18,
      color: primary.withValues(alpha: 0.75),
    ),
  ];

  static LinearGradient gradientFor(AccentColor accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: accent.gradient,
  );

  factory FFColors.light(AccentColor accent) {
    const ink = AppPalette.emerald900;
    return FFColors(
      brightness: Brightness.light,
      canvas: AppPalette.mint,
      surface: AppPalette.white,
      surfaceBorder: const Color(0x00000000),
      surfaceMuted: AppPalette.slate100,
      sheet: AppPalette.sheet,
      primary: accent.primary,
      primaryStrong: accent.strong,
      onPrimary: AppPalette.white,
      primarySoft: accent.soft,
      primaryGradient: gradientFor(accent),
      ink: ink,
      inkMuted: ink.withValues(alpha: 0.52),
      inkFaint: ink.withValues(alpha: 0.34),
      divider: ink.withValues(alpha: 0.06),
      danger: AppPalette.rose500,
      dangerSoft: AppPalette.rose50,
      warning: AppPalette.amber500,
      warningSoft: AppPalette.amber100,
      success: AppPalette.emerald500,
      highlight: AppPalette.emerald200,
      chipBorder: AppPalette.emerald100,
      snackbar: AppPalette.emerald950,
      onSnackbar: AppPalette.white,
      snackbarAction: AppPalette.emerald400,
      tabBar: AppPalette.white.withValues(alpha: 0.96),
      scrim: AppPalette.emerald950.withValues(alpha: 0.45),
      cardShadow: lightCardShadow,
      heroShadow: heroShadowFor(accent.primary),
      vaultCanvas: AppPalette.vaultCanvas,
      vaultSurface: AppPalette.white.withValues(alpha: 0.05),
      vaultBorder: AppPalette.white.withValues(alpha: 0.08),
      vaultTabBar: AppPalette.vaultTabBar.withValues(alpha: 0.95),
      vaultInk: AppPalette.white,
      vaultInkMuted: AppPalette.emerald100.withValues(alpha: 0.55),
      vaultAccent: AppPalette.emerald400,
    );
  }

  factory FFColors.dark(AccentColor accent) {
    const white = AppPalette.white;
    return FFColors(
      brightness: Brightness.dark,
      canvas: AppPalette.darkCanvas,
      surface: white.withValues(alpha: 0.04),
      surfaceBorder: white.withValues(alpha: 0.10),
      surfaceMuted: white.withValues(alpha: 0.07),
      sheet: const Color(0xFF0A2A22),
      primary: accent.primaryDark,
      primaryStrong: accent.primaryDark,
      onPrimary: AppPalette.emerald950,
      primarySoft: accent.primaryDark.withValues(alpha: 0.15),
      primaryGradient: gradientFor(accent),
      ink: white,
      inkMuted: AppPalette.emerald100.withValues(alpha: 0.55),
      inkFaint: white.withValues(alpha: 0.35),
      divider: white.withValues(alpha: 0.06),
      danger: AppPalette.rose300,
      dangerSoft: AppPalette.rose500.withValues(alpha: 0.15),
      warning: AppPalette.amber300,
      warningSoft: AppPalette.amber500.withValues(alpha: 0.15),
      success: AppPalette.emerald400,
      highlight: AppPalette.emerald400.withValues(alpha: 0.30),
      chipBorder: white.withValues(alpha: 0.10),
      snackbar: AppPalette.emerald100,
      onSnackbar: AppPalette.emerald950,
      snackbarAction: AppPalette.emerald700,
      tabBar: AppPalette.darkTabBar.withValues(alpha: 0.95),
      scrim: Colors.black.withValues(alpha: 0.55),
      cardShadow: const [],
      heroShadow: heroShadowFor(
        accent.primary,
      ).map((s) => s.copyWith(color: s.color.withValues(alpha: 0.35))).toList(),
      vaultCanvas: AppPalette.vaultCanvas,
      vaultSurface: white.withValues(alpha: 0.05),
      vaultBorder: white.withValues(alpha: 0.08),
      vaultTabBar: AppPalette.vaultTabBar.withValues(alpha: 0.95),
      vaultInk: white,
      vaultInkMuted: AppPalette.emerald100.withValues(alpha: 0.55),
      vaultAccent: AppPalette.emerald400,
    );
  }

  @override
  FFColors copyWith({Color? canvas, Color? surface}) => FFColors(
    brightness: brightness,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceBorder: surfaceBorder,
    surfaceMuted: surfaceMuted,
    sheet: sheet,
    primary: primary,
    primaryStrong: primaryStrong,
    onPrimary: onPrimary,
    primarySoft: primarySoft,
    primaryGradient: primaryGradient,
    ink: ink,
    inkMuted: inkMuted,
    inkFaint: inkFaint,
    divider: divider,
    danger: danger,
    dangerSoft: dangerSoft,
    warning: warning,
    warningSoft: warningSoft,
    success: success,
    highlight: highlight,
    chipBorder: chipBorder,
    snackbar: snackbar,
    onSnackbar: onSnackbar,
    snackbarAction: snackbarAction,
    tabBar: tabBar,
    scrim: scrim,
    cardShadow: cardShadow,
    heroShadow: heroShadow,
    vaultCanvas: vaultCanvas,
    vaultSurface: vaultSurface,
    vaultBorder: vaultBorder,
    vaultTabBar: vaultTabBar,
    vaultInk: vaultInk,
    vaultInkMuted: vaultInkMuted,
    vaultAccent: vaultAccent,
  );

  @override
  FFColors lerp(ThemeExtension<FFColors>? other, double t) {
    if (other is! FFColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FFColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceBorder: c(surfaceBorder, other.surfaceBorder),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      sheet: c(sheet, other.sheet),
      primary: c(primary, other.primary),
      primaryStrong: c(primaryStrong, other.primaryStrong),
      onPrimary: c(onPrimary, other.onPrimary),
      primarySoft: c(primarySoft, other.primarySoft),
      primaryGradient: LinearGradient.lerp(
        primaryGradient,
        other.primaryGradient,
        t,
      )!,
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      divider: c(divider, other.divider),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      success: c(success, other.success),
      highlight: c(highlight, other.highlight),
      chipBorder: c(chipBorder, other.chipBorder),
      snackbar: c(snackbar, other.snackbar),
      onSnackbar: c(onSnackbar, other.onSnackbar),
      snackbarAction: c(snackbarAction, other.snackbarAction),
      tabBar: c(tabBar, other.tabBar),
      scrim: c(scrim, other.scrim),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? [],
      heroShadow: BoxShadow.lerpList(heroShadow, other.heroShadow, t) ?? [],
      vaultCanvas: c(vaultCanvas, other.vaultCanvas),
      vaultSurface: c(vaultSurface, other.vaultSurface),
      vaultBorder: c(vaultBorder, other.vaultBorder),
      vaultTabBar: c(vaultTabBar, other.vaultTabBar),
      vaultInk: c(vaultInk, other.vaultInk),
      vaultInkMuted: c(vaultInkMuted, other.vaultInkMuted),
      vaultAccent: c(vaultAccent, other.vaultAccent),
    );
  }

  List<Object> get _props => [
    brightness,
    canvas,
    surface,
    surfaceBorder,
    surfaceMuted,
    sheet,
    primary,
    primaryStrong,
    onPrimary,
    primarySoft,
    primaryGradient,
    ink,
    inkMuted,
    inkFaint,
    divider,
    danger,
    dangerSoft,
    warning,
    warningSoft,
    success,
    highlight,
    chipBorder,
    snackbar,
    onSnackbar,
    snackbarAction,
    tabBar,
    scrim,
    vaultCanvas,
    vaultSurface,
    vaultBorder,
    vaultTabBar,
    vaultInk,
    vaultInkMuted,
    vaultAccent,
  ];

  // Value equality so ThemeData == (which compares extensions) holds for
  // equal themes and MaterialApp's AnimatedTheme doesn't re-animate.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FFColors &&
          listEquals(other._props, _props) &&
          listEquals(other.cardShadow, cardShadow) &&
          listEquals(other.heroShadow, heroShadow);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(_props),
    Object.hashAll(cardShadow),
    Object.hashAll(heroShadow),
  );
}

/// A module's colour trio (+ dark-mode soft variant). See [ModuleStyle.of].
@immutable
class ModuleColors {
  const ModuleColors({
    required this.solid,
    required this.soft,
    required this.ink,
  });

  /// Icon tile fills, accents, left borders, chart series.
  final Color solid;

  /// Soft icon-tile / tag background (light mode).
  final Color soft;

  /// Text on [soft] backgrounds.
  final Color ink;

  /// Soft background that adapts to dark mode (solid @15%).
  Color softFor(Brightness b) =>
      b == Brightness.dark ? solid.withValues(alpha: 0.15) : soft;

  /// Ink that stays readable in dark mode.
  Color inkFor(Brightness b) =>
      b == Brightness.dark ? Color.lerp(solid, Colors.white, 0.35)! : ink;
}

/// Priority colours (task rows' 4px left bar and chip dots).
abstract final class PriorityColors {
  static const high = AppPalette.red500;
  static const medium = AppPalette.amber500;
  static const low = AppPalette.emerald500;
}

/// Icon-tile tints of the item actions sheet rows (screen 09) that are not
/// a module or tag colour.
abstract final class ActionTints {
  /// "Share / export" — teal.
  static const share = ModuleColors(
    solid: Color(0xFF14B8A6),
    soft: Color(0xFFCCFBF1),
    ink: Color(0xFF0F766E),
  );

  /// "Lock with a PIN" (notes) — slate.
  static const lock = ModuleColors(
    solid: AppPalette.slate500,
    soft: AppPalette.slate100,
    ink: AppPalette.slate600,
  );
}

/// Tag / folder palette (bg/fg pairs from the design system). Unknown names
/// get a stable colour from [TagPalette.forName].
abstract final class TagPalette {
  static const ideas = ModuleColors(
    solid: AppPalette.emerald500,
    soft: AppPalette.emerald100,
    ink: AppPalette.emerald700,
  );
  static const work = ModuleColors(
    solid: AppPalette.blue500,
    soft: AppPalette.blue100,
    ink: AppPalette.blue700,
  );
  static const personal = ModuleColors(
    solid: AppPalette.pink500,
    soft: AppPalette.pink100,
    ink: AppPalette.pink700,
  );
  static const finance = ModuleColors(
    solid: AppPalette.amber500,
    soft: AppPalette.amber100,
    ink: AppPalette.amber700,
  );
  static const design = ModuleColors(
    solid: AppPalette.violet500,
    soft: AppPalette.violet100,
    ink: AppPalette.violet700,
  );
  static const health = ModuleColors(
    solid: AppPalette.emerald500,
    soft: AppPalette.emerald100,
    ink: AppPalette.emerald700,
  );
  static const high = ModuleColors(
    solid: AppPalette.red500,
    soft: AppPalette.red100,
    ink: AppPalette.red700,
  );
  static const travel = ModuleColors(
    solid: AppPalette.sky500,
    soft: Color(0xFFE0F2FE),
    ink: Color(0xFF0369A1),
  );

  static const List<ModuleColors> _rotation = [
    ideas,
    work,
    personal,
    finance,
    design,
    travel,
  ];

  /// Named colours first, otherwise a stable hash-based pick.
  static ModuleColors forName(String name) {
    switch (name.toLowerCase().replaceAll('#', '').trim()) {
      case 'ideas':
        return ideas;
      case 'work':
        return work;
      case 'personal':
        return personal;
      case 'finance':
        return finance;
      case 'design':
        return design;
      case 'health':
        return health;
      case 'high':
        return high;
      case 'travel':
        return travel;
    }
    var hash = 0;
    for (final unit in name.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _rotation[hash % _rotation.length];
  }
}

/// Note card colours (white, mint, amber, blue, pink, violet). The stored
/// `colorHex` is one of [NoteColors.hexes]; null = white.
abstract final class NoteColors {
  static const List<String> hexes = [
    'FFFFFF',
    'D1FAE5',
    'FEF3C7',
    'DBEAFE',
    'FCE7F3',
    'EDE9FE',
  ];

  /// Card background for [hex] in the current brightness (dark = 15% tint).
  static Color background(String? hex, Brightness brightness) {
    final color = parseHex(hex) ?? AppPalette.white;
    if (brightness == Brightness.light) return color;
    if (hex == null || hex.toUpperCase() == 'FFFFFF') {
      return Colors.white.withValues(alpha: 0.04);
    }
    return _saturated(color).withValues(alpha: 0.15);
  }

  static Color _saturated(Color soft) {
    final hsl = HSLColor.fromColor(soft);
    return hsl
        .withLightness(lerpDouble(hsl.lightness, 0.55, 1)!)
        .withSaturation(0.8)
        .toColor();
  }
}

/// Parses `RRGGBB` / `#RRGGBB` / `AARRGGBB`. Returns null for null/invalid.
Color? parseHex(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}

/// `RRGGBB` (upper case, no alpha) for storage.
String toHex(Color color) {
  final argb = color.toARGB32();
  return (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
}
