/// ============================================================
/// REMINDER TOKENS — named type styles of screens 12 / 13
/// ============================================================
///
/// What: [ReminderTextStyles] — the reminders list / reminder editor type
/// roles derived from the design-system [FFTextStyles] (read as
/// `context.text.reminderTime`), including the time wheel's
/// distance-based digit scale ([ReminderTextStyles.wheelDigit]);
/// [ReminderSizes] — measured lengths the shared AppSpacing / AppSizes
/// scale has no step for; [ReminderShadows] — the next-due card's lift.
/// Why: rule 4 — no ad-hoc font sizes scattered through feature widgets.
/// Each value was measured once against design/12 and design/13 and is
/// named for its role; colours still come from `context.ff`.
/// ============================================================
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/painting.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_typography.dart';

/// Named type styles of the reminders list and the reminder editor.
extension ReminderTextStyles on FFTextStyles {
  /// 15 Lexend — the time column of a reminder card ("10:00").
  TextStyle get reminderTime => stat.copyWith(fontSize: 15, height: 1.2);

  /// 15 Lexend w800 — the next-due card's time (bolder, full ink).
  TextStyle get reminderTimeNext =>
      reminderTime.copyWith(fontWeight: FontWeight.w800);

  /// 11 w800 — the AM / PM under the time.
  TextStyle get reminderMeridiem =>
      caption.copyWith(fontSize: 11, fontWeight: FontWeight.w800);

  /// 11.5 w800 — inline pills ("SNOOZE 10m", "MARK DONE").
  TextStyle get reminderPill =>
      tag.copyWith(fontSize: 11.5, height: 1.45, letterSpacing: 0.1);

  /// 13 / 1.4 Nunito — card meta lines and the editor's note field.
  TextStyle get reminderNote => bodySmall.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 13 w500 Lexend — WHEN day tiles and REPEAT pills.
  TextStyle get reminderChip =>
      buttonSmall.copyWith(fontSize: 13, fontWeight: FontWeight.w500);

  /// 19.5 w600 Lexend — the editor's title field.
  TextStyle get reminderEditorTitle =>
      title.copyWith(fontSize: 19.5, fontWeight: FontWeight.w600, height: 1.25);

  /// Time wheel digit [distance] rows from the centre: 23 pt bold in the
  /// band, 18 pt one row out, 15 pt at the edges (sizes interpolate while
  /// the wheel scrolls). Colour is applied by the wheel.
  TextStyle wheelDigit(double distance) {
    final d = distance.abs();
    final size = d <= 1
        ? lerpDouble(23, 18, d)!
        : lerpDouble(18, 15, (d - 1).clamp(0.0, 1.0))!;
    return title.copyWith(
      fontSize: size,
      height: 1.1,
      fontWeight: d < 0.5 ? FontWeight.w700 : FontWeight.w500,
    );
  }
}

/// Measured lengths of screens 12 / 13 (pt, from design/12 and design/13).
abstract final class ReminderSizes {
  /// Large header top inset on screen 12 (11 pt).
  static const double headerTop = 11;

  /// Time label top inset, so "10:00" lines up with the card title.
  static const double timeTop = 12;

  /// Gap between the time and AM / PM, and between title and meta line.
  static const double hairGap = 3;

  /// Card padding above the content (and below it without pills).
  static const double cardVertical = 15;

  /// Card padding below the inline pills (they bring 10 pt of their own).
  static const double cardBottomWithPills = 5;

  /// The next-due card pulls this far into the time gutter (start) and
  /// the screen gutter (end), like design/12, staying on screen.
  static const double nextBleedStart = 12;
  static const double nextBleedEnd = 12;

  /// Inline pill: 23 pt visual pill inside a 44 pt hit area.
  static const double pillMinHeight = 23;
  static const double pillHitPad = 10;
  static const double pillHorizontal = 8;
  static const double pillVertical = 3;

  /// Done check that replaces the toggle (20 pt circle, 10 pt glyph).
  static const double doneCheck = 20;
  static const double doneCheckGlyph = 10;

  /// Week card insets (vertical 6, strip side 11).
  static const double weekCardVertical = 6;
  static const double weekStripSide = 11;

  /// Reminder editor: title tile glyph (17 pt), gap between the title and
  /// the note (4 pt), gap below the WHEN chips (13 pt).
  static const double titleGlyph = 17;
  static const double titleNoteGap = 4;
  static const double whenGap = 13;

  /// WHEN / REPEAT chips: 6 pt vertical padding, 1.5 pt pill border,
  /// 52 pt minimum pill width.
  static const double chipVertical = 6;
  static const double chipBorder = 1.5;
  static const double pillMinWidth = 52;

  /// Time wheel card vertical padding (12.5 pt).
  static const double wheelVertical = 12.5;

  /// Gap between an editor row's icon tile and its text (14 pt).
  static const double tileGap = 14;
}

/// Shadows of the reminders list, derived from the theme's card shadow.
extension ReminderShadows on FFColors {
  /// The next-due card: the card shadow, deeper and a little darker
  /// (dark mode has no card shadow, so the border carries the card).
  List<BoxShadow> get reminderNextShadow => [
    for (final s in cardShadow)
      s.copyWith(
        offset: s.offset * 1.5,
        blurRadius: s.blurRadius * 1.25,
        color: s.color.withValues(alpha: (s.color.a * 1.5).clamp(0.0, 1.0)),
      ),
  ];
}
