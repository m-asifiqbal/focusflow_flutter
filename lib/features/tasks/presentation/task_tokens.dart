/// ============================================================
/// TASK TOKENS — named type styles and metrics of screens 10 / 11
/// ============================================================
///
/// What: [TaskTextStyles] (named styles derived from the design-system
/// [FFTextStyles], read as `context.text.editorTitle`) and [TaskSizes]
/// (the few measured lengths the tasks list / task editor use that the
/// shared AppSpacing / AppSizes scale has no step for).
/// Why: rule 4 — features must not scatter ad-hoc font sizes and magic
/// numbers. Each value here was measured against design/10 and design/11
/// once and is named for its role, so every widget (and the reminder
/// editor, which reuses the task editor chrome) reads the same token, and
/// colours still come from `context.ff` (dark mode and accent for free).
/// ============================================================
library;

import 'package:flutter/painting.dart';
import 'package:focusflow/core/theme/app_typography.dart';

/// Named type styles of the tasks list and the task editor.
extension TaskTextStyles on FFTextStyles {
  /// 12 w500 — due / time meta on a task row ("09:00 AM").
  TextStyle get taskRowMeta =>
      meta.copyWith(fontSize: 12, fontWeight: FontWeight.w500);

  /// 13 w700 Nunito — compact section-header link ("Reschedule all").
  TextStyle get sectionAction =>
      meta.copyWith(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2);

  /// 15.5 w500 Lexend — editor header actions ("Cancel" / "Save").
  TextStyle get editorHeaderAction =>
      buttonSmall.copyWith(fontSize: 15.5, fontWeight: FontWeight.w500);

  /// 20.5 w600 Lexend — the editor's title field.
  TextStyle get editorTitle =>
      title.copyWith(fontSize: 20.5, fontWeight: FontWeight.w600, height: 1.25);

  /// 14 / 1.72 Nunito — the editor's notes field.
  TextStyle get editorNotes => body.copyWith(fontSize: 14, height: 1.72);

  /// 14.5 Nunito — editor row values ("Today", "None") and subtask titles.
  TextStyle get editorValue => body.copyWith(fontSize: 14.5, height: 1.3);

  /// 14.5 w700 Nunito — the priority selector labels.
  TextStyle get editorChoice =>
      rowTitle.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700);

  /// 15 Lexend — inline section actions ("+ Add" on SUBTASKS).
  TextStyle get editorInlineAction => buttonSmall.copyWith(fontSize: 15);

  /// 13 Lexend — weekday toggles of the custom repeat panel ("Mo").
  TextStyle get weekdayToggle => buttonSmall.copyWith(fontSize: 13);
}

/// Measured lengths of screens 10 / 11 (also used by the reminder editor,
/// which shares the task editor chrome) that the shared AppSpacing /
/// AppSizes scale has no step for.
abstract final class TaskSizes {
  /// Section label row height on the tasks list (40 pt, mockup).
  static const double sectionRow = 40;

  /// Hair gap between a title and its meta line (3 pt).
  static const double hairGap = 3;

  /// Small inline gap (6 pt): row insets, meta wrap spacing.
  static const double inlineGap = 6;

  /// Gap between a dot / value and its neighbour (10 pt).
  static const double rowGap = 10;

  /// Gap between an icon tile and its label (14 pt).
  static const double tileGap = 14;

  /// Gap between an editor section label and its card (13 pt).
  static const double labelGap = 13;

  /// Vertical gap between editor sections (25 pt).
  static const double sectionGap = 25;

  /// Priority accent bar on a task row (4 pt wide, 2 pt radius).
  static const double accentBar = 4;
  static const double accentBarRadius = 2;

  /// Completion check circle on a task row (24 pt).
  static const double check = 24;

  /// Subtask check circle in the editor (23 pt).
  static const double subtaskCheck = 23;

  /// Subtask progress bar on a task row (80 × 6 pt).
  static const double progressWidth = 80;
  static const double progressHeight = 6;

  /// Weekday toggle of the custom repeat panel (40 pt circle).
  static const double weekdayToggle = 40;

  /// Picker row leading icon tile (32 pt) and dot box (20 pt).
  static const double pickerTile = 32;
  static const double pickerDotBox = 20;

  /// Dots: priority selector (8 pt) and picker rows (10 pt).
  static const double dotSm = 8;
  static const double dot = 10;

  /// Glyph sizes: 10 · 12 meta · 13 row meta · 14 chevron · 15 check · 16.
  static const double glyphXs = 10;
  static const double glyphSm = 12;
  static const double glyphMeta = 13;
  static const double glyph = 14;
  static const double glyphCheck = 15;
  static const double glyphMd = 16;

  /// Horizontal padding of an FFStatTile (12 start + 6 end): the label
  /// room is the tile width minus this.
  static const double statTileLabelInset = 18;

  /// Height of the Cupertino time picker in the time sheet (180 pt).
  static const double timePickerHeight = 180;
}
