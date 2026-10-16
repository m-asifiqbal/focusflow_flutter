/// ============================================================
/// VAULT TOKENS — the vault's type scale and component sizes, named once
/// ============================================================
///
/// The vault mockups (17–22, 33) are measured to the half point and use a
/// denser scale than the shared [FFTextStyles] presets, so vault widgets
/// start from a `context.text` style and swap in a size from [VaultType]
/// (`context.text.body.copyWith(fontSize: VaultType.small)`). Gaps, icon
/// sizes and component dimensions that AppSpacing / AppSizes have no token
/// for live in [VaultSizes]. Vault features never write numeric literals
/// for sizes; colours live in vault_style.dart.
/// ============================================================
library;

/// Font sizes of the vault screens, smallest to largest.
abstract final class VaultType {
  /// Strength badge ("STRONG").
  static const double badge = 10;

  /// Alphabet scrubber letters, issue kind labels.
  static const double micro = 10.5;

  /// Section labels, inner tab labels.
  static const double label = 11;

  /// Tile captions, history timestamps.
  static const double caption = 11.5;

  /// Field labels, row subtitles.
  static const double meta = 12;

  /// Header subtitle, small body copy.
  static const double small = 12.5;

  /// Secondary body copy.
  static const double secondary = 13;

  /// Lock card body, links, history values.
  static const double subtitle = 13.5;

  /// Category card titles, type chips.
  static const double callout = 14;

  /// Tab subtitles, notes, empty-state copy.
  static const double lead = 14.5;

  /// Quick generator sheet values.
  static const double field = 15;

  /// Row titles and editable values.
  static const double row = 15.5;

  /// Field values, card titles, buttons.
  static const double value = 16;

  /// Monospaced secrets, settings card titles, editor links.
  static const double valueLg = 16.5;

  /// Editor nav title, recovery code.
  static const double nav = 17;

  /// Detail nav back label.
  static const double navLg = 17.5;

  /// Empty-state title.
  static const double heading = 18;

  /// Security tile numbers, editor title field.
  static const double stat = 20;

  /// TOTP code.
  static const double code = 21;

  /// Lock card / PIN pad title.
  static const double headline = 22;

  /// Character-by-character password view.
  static const double display = 24;

  /// Detail title, generated password.
  static const double titleLg = 25;

  /// Vault tab titles, health score.
  static const double title = 26;

  /// Security score in the gauge.
  static const double hero = 46;
}

/// Gaps, icon sizes and component dimensions of the vault screens.
abstract final class VaultSizes {
  // Gaps ------------------------------------------------------------------
  static const double gapXs = 6;
  static const double gapSm = 10;
  static const double gapTile = 11;
  static const double gapMd = 14;
  static const double gapLg = 18;

  // Icons -----------------------------------------------------------------
  static const double iconXxs = 12;
  static const double iconXs = 13;
  static const double iconSm = 14;
  static const double iconRow = 15;
  static const double iconMd = 16;
  static const double iconButton = 17;
  static const double iconLg = 18;
  static const double iconXl = 20;
  static const double iconXxl = 24;
  static const double emptyGlyph = 28;
  static const double lockGlyph = 34;

  // Borders ---------------------------------------------------------------
  static const double ring = 2;
  static const double swatchRing = 3;
  static const double scannerBorder = 3;

  /// Dashed "add" card outline: stroke, dash length and gap.
  static const double dashStroke = 1.6;
  static const double dash = 7;
  static const double dashGap = 6;

  // Bars ------------------------------------------------------------------
  static const double strengthBar = 5;
  static const double entropyBar = 6;
  static const double healthBar = 8;
  static const double entropyBarWidth = 178;

  // Components ------------------------------------------------------------
  static const double pinDot = 14;
  static const double pinMessage = 21;
  static const double eyeSlot = 24;
  static const double lengthLabel = 28;
  static const double pill = 30;
  static const double summaryPill = 31;
  static const double charCell = 34;
  static const double chipRow = 34;
  static const double smallButton = 36;
  static const double totpRing = 40;

  /// [VaultRoundButton] disc and its glyph.
  static const double roundButton = 40;

  /// Header buttons (favourite disc, lock, add): a size down from the
  /// shared 44 pt round button so the vault toolbars stay light.
  static const double toolbarButton = 38;
  static const double roundGlyph = iconButton;
  static const double segmented = 40;
  static const double historyRow = 45;
  static const double segmentedLg = 48;
  static const double actionButton = 48;
  static const double sheetRow = 52;
  static const double footerRow = 54;
  static const double editorAvatar = 56;
  static const double organiseRow = 58;
  static const double backLabel = 61;
  static const double emptyBadge = 64;
  static const double itemRow = 72;
  static const double fieldRow = 73;
  static const double securityTile = 74;
  static const double detailAvatar = 76;
  static const double lockRingInner = 80;
  static const double totpCard = 82;
  static const double lockRingOuter = 96;
  static const double categoryCardWidth = 111;
  static const double categoryCard = 116;
  static const double scoreGauge = 168;
  static const double scoreStroke = 14;
  static const double scanner = 240;
  static const double totpStroke = 4;
  static const double sliderTrack = 8;
  static const double sliderThumb = 12;
  static const double sliderOverlay = 22;

  // Skeleton placeholders -------------------------------------------------
  static const double skeletonRows = 90;
  static const double skeletonCard = 220;
  static const double skeletonCardLg = 280;
}
