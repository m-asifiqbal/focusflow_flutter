/// ============================================================
/// APP TYPOGRAPHY — Lexend Deca (headings/numbers/buttons) + Nunito Sans (body)
/// ============================================================
///
/// Both families are bundled (pubspec `fonts:`) so text renders identically
/// offline. Read styles with `context.text.largeTitle` etc.; they already
/// carry the right ink colour for the current theme. Override colour with
/// `.copyWith(color: …)` only for accents.
///
/// Scale (design system):
///   Large title 30/1.15 w700 -0.5 · Nav title 16 w600 · Section title 19 w600
///   Card title 15.5 w600 · Body 15.5 w400 lh 1.6 · Meta 12.5 w600
///   Section label 11.5 w800 UPPERCASE +0.12em · Tag 10 w800 UPPERCASE
///   Big stat 26 w700 · Hero ring number 44 w700
/// ============================================================
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';

abstract final class AppFonts {
  static const String heading = 'LexendDeca';
  static const String body = 'NunitoSans';
}

// Settings › Appearance › "Use system font": the bundled families are
// dropped (fontFamily null), so text falls back to the platform default
// (San Francisco on iOS, Roboto on Android) via the Material typography.

@immutable
class FFTextStyles extends ThemeExtension<FFTextStyles> {
  const FFTextStyles({
    required this.largeTitle,
    required this.title,
    required this.navTitle,
    required this.sectionTitle,
    required this.cardTitle,
    required this.rowTitle,
    required this.body,
    required this.bodySmall,
    required this.meta,
    required this.caption,
    required this.sectionLabel,
    required this.tag,
    required this.button,
    required this.buttonSmall,
    required this.bigStat,
    required this.stat,
    required this.heroNumber,
    required this.mono,
  });

  /// 30 w700, -0.5 tracking — list screen headers ("Notes").
  final TextStyle largeTitle;

  /// 23–24 w700 — sheet/dialog titles, detail names.
  final TextStyle title;

  /// 16 w600 — centred nav header title.
  final TextStyle navTitle;

  /// 19 w600 — "Up Next", "Today's Tasks".
  final TextStyle sectionTitle;

  /// 15.5 w600 Lexend — card / row titles.
  final TextStyle cardTitle;

  /// 15.5 w600 Nunito — grouped-list row labels ("Language").
  final TextStyle rowTitle;

  /// 15.5 w400 lh 1.6 — paragraphs.
  final TextStyle body;

  /// 14 w400 muted — secondary paragraphs.
  final TextStyle bodySmall;

  /// 12.5 w600 muted — meta lines ("Today · 11:30 AM").
  final TextStyle meta;

  /// 11 w600 muted — tiny captions under stats.
  final TextStyle caption;

  /// 11.5 w800 UPPERCASE +0.12em faint — "COLLECTIONS".
  final TextStyle sectionLabel;

  /// 10 w800 UPPERCASE — tag pills.
  final TextStyle tag;

  /// 16 w600 Lexend — buttons.
  final TextStyle button;

  /// 13.5 w600 Lexend — pill buttons, chips.
  final TextStyle buttonSmall;

  /// 26 w700 Lexend — library counts, KPI values.
  final TextStyle bigStat;

  /// 20 w700 Lexend — stat tiles.
  final TextStyle stat;

  /// 44 w700 Lexend — hero rings.
  final TextStyle heroNumber;

  /// Monospace for passwords / codes.
  final TextStyle mono;

  /// [systemFont]: use the platform's default family instead of the
  /// bundled Lexend Deca / Nunito Sans (monospace is unchanged).
  factory FFTextStyles.from(FFColors c, {bool systemFont = false}) {
    final heading = systemFont ? null : AppFonts.heading;
    final bodyFamily = systemFont ? null : AppFonts.body;
    TextStyle h(double size, FontWeight w, {double? height, Color? color}) =>
        TextStyle(
          fontFamily: heading,
          fontSize: size,
          fontWeight: w,
          height: height,
          color: color ?? c.ink,
          leadingDistribution: TextLeadingDistribution.even,
        );
    TextStyle b(double size, FontWeight w, {double? height, Color? color}) =>
        TextStyle(
          fontFamily: bodyFamily,
          fontSize: size,
          fontWeight: w,
          height: height,
          color: color ?? c.ink,
          leadingDistribution: TextLeadingDistribution.even,
        );
    return FFTextStyles(
      largeTitle: h(26, FontWeight.w700, height: 1.15).copyWith(
        letterSpacing: -0.5,
      ),
      title: h(23, FontWeight.w700, height: 1.2).copyWith(letterSpacing: -0.3),
      navTitle: h(16, FontWeight.w600, height: 1.25),
      sectionTitle: h(19, FontWeight.w600, height: 1.25),
      cardTitle: h(16, FontWeight.w600, height: 1.3),
      rowTitle: b(16, FontWeight.w600, height: 1.3),
      body: b(16, FontWeight.w500, height: 1.55, color: c.inkMuted),
      bodySmall: b(14.5, FontWeight.w500, height: 1.45, color: c.inkMuted),
      meta: b(13.5, FontWeight.w600, height: 1.35, color: c.inkMuted),
      caption: b(12, FontWeight.w600, height: 1.3, color: c.inkMuted),
      sectionLabel: b(12, FontWeight.w800, height: 1.2, color: c.inkFaint)
          .copyWith(letterSpacing: 1.4),
      tag: b(10, FontWeight.w800, height: 1.2).copyWith(letterSpacing: 0.6),
      button: h(16, FontWeight.w600, height: 1.2),
      buttonSmall: h(13.5, FontWeight.w600, height: 1.2),
      bigStat: h(26, FontWeight.w700, height: 1.1),
      stat: h(20, FontWeight.w700, height: 1.1),
      heroNumber: h(44, FontWeight.w700, height: 1.0),
      mono: TextStyle(
        fontFamily: 'Menlo',
        fontFamilyFallback: const ['Roboto Mono', 'Courier', 'monospace'],
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.ink,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Material [TextTheme] so stock widgets (dialogs, pickers, Quill) match.
  static TextTheme materialTextTheme(FFColors c, {bool systemFont = false}) {
    final s = FFTextStyles.from(c, systemFont: systemFont);
    return TextTheme(
      displayLarge: s.heroNumber,
      displayMedium: s.bigStat,
      displaySmall: s.largeTitle,
      headlineLarge: s.largeTitle,
      headlineMedium: s.title,
      headlineSmall: s.sectionTitle,
      titleLarge: s.sectionTitle,
      titleMedium: s.cardTitle,
      titleSmall: s.navTitle,
      bodyLarge: s.body.copyWith(color: c.ink),
      bodyMedium: s.bodySmall.copyWith(color: c.ink),
      bodySmall: s.meta,
      labelLarge: s.button,
      labelMedium: s.buttonSmall,
      labelSmall: s.caption,
    );
  }

  @override
  FFTextStyles copyWith() => this;

  List<TextStyle> get _all => [
    largeTitle,
    title,
    navTitle,
    sectionTitle,
    cardTitle,
    rowTitle,
    body,
    bodySmall,
    meta,
    caption,
    sectionLabel,
    tag,
    button,
    buttonSmall,
    bigStat,
    stat,
    heroNumber,
    mono,
  ];

  // Value equality so ThemeData == (which compares extensions) holds for
  // equal themes and MaterialApp's AnimatedTheme doesn't re-animate.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FFTextStyles && listEquals(other._all, _all);

  @override
  int get hashCode => Object.hashAll(_all);

  @override
  FFTextStyles lerp(ThemeExtension<FFTextStyles>? other, double t) {
    if (other is! FFTextStyles) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return FFTextStyles(
      largeTitle: l(largeTitle, other.largeTitle),
      title: l(title, other.title),
      navTitle: l(navTitle, other.navTitle),
      sectionTitle: l(sectionTitle, other.sectionTitle),
      cardTitle: l(cardTitle, other.cardTitle),
      rowTitle: l(rowTitle, other.rowTitle),
      body: l(body, other.body),
      bodySmall: l(bodySmall, other.bodySmall),
      meta: l(meta, other.meta),
      caption: l(caption, other.caption),
      sectionLabel: l(sectionLabel, other.sectionLabel),
      tag: l(tag, other.tag),
      button: l(button, other.button),
      buttonSmall: l(buttonSmall, other.buttonSmall),
      bigStat: l(bigStat, other.bigStat),
      stat: l(stat, other.stat),
      heroNumber: l(heroNumber, other.heroNumber),
      mono: l(mono, other.mono),
    );
  }
}
