/// ============================================================
/// NOTE METRICS — named size tokens of the notes screens (07 / 08 / 09)
/// ============================================================
///
/// What: the few note-specific sizes the shared design tokens
/// (AppSpacing / AppSizes / FFTextStyles) don't cover, measured against
/// design/07_notes_list.png and design/08_note_editor.png.
/// Why: CLAUDE.md rule 4 — no bare numbers in feature widgets; one place
/// to retune the notes UI. Body/Quill metrics live in [NoteBodyMetrics]
/// (note_quill_styles.dart).
/// ============================================================
library;

/// Note card (masonry + compact row) sizes.
abstract final class NoteCardMetrics {
  /// Preview text: 12 pt on a 17.2 pt line.
  static const double previewSize = 12;
  static const double previewLineHeight = 1.43;

  /// "TODAY · IDEAS" footer.
  static const double footerSize = 10;
  static const double footerLetterSpacing = 0.4;

  /// Checklist preview lines.
  static const double checklistSize = 12.5;
  static const double checklistLineHeight = 1.5;
  static const double checkBox = 12;
  static const double checkBoxRadius = 3;
  static const double checkBoxBorder = 1.4;
  static const double checkGlyph = 8;

  /// Title line height (size from FFTextStyles.cardTitle).
  static const double titleLineHeight = 1.36;

  static const double pinMark = 12;
  static const double lockMark = 13;

  /// Locked-note placeholder bars under the blur.
  static const double lockedBlurSigma = 3;
  static const double lockedBarHeight = 9;

  /// Multi-select circle.
  static const double selectMark = 24;
  static const double selectBorder = 1.6;
  static const double selectGlyph = 11;
}

/// Note editor (screen 08) sizes.
abstract final class NoteEditorMetrics {
  /// Title — 27 pt w700 (prompt 08 §3).
  static const double titleSize = 27;
  static const double titleLineHeight = 1.18;

  /// Minimum height of the Quill body (tap target below short notes).
  static const double bodyMinHeight = 160;

  /// Rich-text headings (Heading button cycles h3; pasted h1/h2 keep size).
  static const double h1Size = 22;
  static const double h2Size = 20;
  static const double headingSpaceBefore = 12;
  static const double headingSpaceAfter = 2;
  static const double paragraphSpace = 2;
  static const double h3Space = 6;

  /// Toolbar: formatting glyphs, "COLOUR" label, Undo.
  static const double toolIcon = 19;
  static const double colourLabelSize = 10.5;
  static const double undoLabelSize = 13;
  static const double undoIcon = 11;
  static const double undoGap = 6;

  /// Visual colour swatch (its hit cell is AppSizes.minTap).
  static const double swatch = 24;
  static const double swatchSelectedBorder = 2.5;

  /// Loading skeleton: meta line, title and body lines.
  static const double skeletonMetaWidth = 120;
  static const double skeletonMeta = 20;
  static const double skeletonTitle = 28;
  static const double skeletonLine = 14;
}
