/// ============================================================
/// VAULT STYLE — the vault's status / category tones in ONE place
/// ============================================================
///
/// Vault screens are always dark (VaultTheme), and the mockups (17–22) use
/// a few tones FFColors has no semantic token for: strength badges
/// (STRONG emerald · FAIR/WEAK amber · REUSED orange · BREACHED rose),
/// the category icons (logins emerald · cards amber · Wi-Fi blue · notes
/// violet) and the favourite heart. They are defined here once, from the
/// shared palette, as an extension on [FFColors] — features never write
/// colour literals.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';

/// Foreground + 15 % background pair of a badge / banner.
@immutable
class VaultTone {
  const VaultTone(this.fg, this.bg);

  final Color fg;
  final Color bg;
}

extension VaultColors on FFColors {
  /// Text / icon on a [FFColors.vaultAccent] fill (emerald-950).
  Color get vaultOnAccentInk => AppPalette.emerald950;

  /// Active filter chip fill (emerald-600, mockup 18).
  Color get vaultChipFill => AppPalette.emerald600;

  /// Faint glass fill of keys, copy buttons and inactive tiles.
  Color get vaultKey => vaultInk.withValues(alpha: 0.06);

  /// Inactive inner-tab icon / label.
  Color get vaultTabIdle => vaultInk.withValues(alpha: 0.38);

  /// Section label ("A – Z").
  Color get vaultLabel => vaultAccent.withValues(alpha: 0.55);

  /// Header subtitle ("Unlocked · auto-locks in 4:59").
  Color get vaultSubtitle => vaultAccent.withValues(alpha: 0.75);

  /// Vault CTA fill (emerald-500 → emerald-600, mockup 17).
  LinearGradient get vaultButtonGradient => const LinearGradient(
    colors: [AppPalette.emerald500, AppPalette.emerald600],
  );

  /// Soft emerald glow under the vault CTA.
  List<BoxShadow> get vaultButtonGlow => [
    BoxShadow(
      color: AppPalette.emerald500.withValues(alpha: 0.32),
      blurRadius: 34,
      offset: const Offset(0, 12),
      spreadRadius: -8,
    ),
  ];

  /// Empty PIN dot ring (emerald-300 @ 40 %).
  Color get vaultPinRing => AppPalette.emerald300.withValues(alpha: 0.4);

  /// Fainter glass of the locked preview tiles (white ≈ 2.5 %).
  Color get vaultGlassFaint => vaultInk.withValues(alpha: 0.025);

  /// Favourite heart.
  Color get vaultHeart =>
      Color.lerp(AppPalette.rose500, AppPalette.rose300, 0.35)!;

  VaultTone get vaultStrong => VaultTone(
    AppPalette.emerald300,
    AppPalette.emerald400.withValues(alpha: 0.13),
  );
  VaultTone get vaultFair => VaultTone(
    AppPalette.amber300,
    AppPalette.amber400.withValues(alpha: 0.13),
  );
  VaultTone get vaultWeak => VaultTone(
    AppPalette.amber300,
    AppPalette.amber400.withValues(alpha: 0.15),
  );
  VaultTone get vaultReused => VaultTone(
    AppPalette.orange400,
    AppPalette.orange400.withValues(alpha: 0.15),
  );
  VaultTone get vaultBreached =>
      VaultTone(AppPalette.rose300, AppPalette.rose500.withValues(alpha: 0.18));

  /// Breach banner: rose icon / link on a rose 10 % pill.
  VaultTone get vaultAlert =>
      VaultTone(AppPalette.rose300, AppPalette.rose500.withValues(alpha: 0.10));
  Color get vaultAlertBorder => AppPalette.rose500.withValues(alpha: 0.22);
  Color get vaultAlertIcon =>
      Color.lerp(AppPalette.rose500, AppPalette.rose300, 0.45)!;

  /// Field label of the detail / editor cards ("USERNAME").
  Color get vaultFieldLabel => AppPalette.emerald200.withValues(alpha: 0.40);

  /// Muted line under a title ("Personal · Updated 3 days ago").
  Color get vaultSubtitleMuted => AppPalette.emerald200.withValues(alpha: 0.5);

  /// Secondary body text on vault cards (notes, health checklist).
  Color get vaultInkSoft => AppPalette.emerald100.withValues(alpha: 0.75);

  /// Round copy / reveal / open buttons and the Generate pill (emerald 10 %).
  Color get vaultAccentSoft => AppPalette.emerald400.withValues(alpha: 0.10);

  /// Shield disc of the "Security health" card (emerald 14 %).
  Color get vaultAccentTint => AppPalette.emerald400.withValues(alpha: 0.14);

  /// Large accent text: 2FA code, health score, links (emerald-300).
  Color get vaultAccentBright => AppPalette.emerald300;

  /// Colour-coded password characters (mockup 19): digits sky, symbols amber.
  Color get vaultSecretDigit =>
      Color.lerp(AppPalette.sky500, AppPalette.white, 0.45)!;
  Color get vaultSecretSymbol => AppPalette.amber300;

  /// Health bar / meter tracks (white 10 %).
  Color get vaultTrack => vaultInk.withValues(alpha: 0.10);

  /// Health bar fill (emerald-400 → teal-300).
  LinearGradient get vaultHealthGradient => LinearGradient(
    colors: [
      AppPalette.emerald400,
      Color.lerp(AppPalette.emerald300, AppPalette.sky500, 0.18)!,
    ],
  );

  /// Delete button: rose-300 on rose-500 14 %.
  VaultTone get vaultDanger =>
      VaultTone(AppPalette.rose300, AppPalette.rose500.withValues(alpha: 0.14));

  /// Category tile icon colour.
  Color vaultCategory(VaultItemType type) => switch (type) {
    VaultItemType.login => AppPalette.emerald400,
    VaultItemType.card => AppPalette.amber400,
    VaultItemType.wifi => AppPalette.blue400,
    VaultItemType.secureNote => AppPalette.indigo400,
  };

  /// Letter-avatar fill when an item has no brand / colour.
  Color get vaultAvatarFallback => AppPalette.emerald700;

  /// White brand tiles (Google, GitHub) and their default glyph colour.
  Color get vaultBrandLight => AppPalette.white;
  Color get vaultBrandDark => AppPalette.slate700;
}
