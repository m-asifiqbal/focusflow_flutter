/// ============================================================
/// VAULT SETTINGS STYLE — icon tints + labels of screen 33
/// ============================================================
///
/// Solid icon-tile tints of the Settings › Vault security rows (from the
/// mockup: emerald Face ID, amber PIN, indigo auto-lock, slate background
/// lock, sky clipboard, red screenshots, violet breach, rose wipe, blue
/// autofill) and the value labels / option lists of the pickers.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';

abstract final class VaultSettingsTints {
  static const emerald = ModuleColors(
    solid: AppPalette.emerald500,
    soft: AppPalette.emerald100,
    ink: AppPalette.emerald700,
  );
  static const amber = TagPalette.finance;
  static const indigo = ModuleColors(
    solid: AppPalette.indigo500,
    soft: AppPalette.indigo100,
    ink: AppPalette.indigo700,
  );
  static const slate = ModuleColors(
    solid: AppPalette.slate700,
    soft: AppPalette.slate100,
    ink: AppPalette.slate700,
  );
  static const sky = TagPalette.travel;
  static const red = TagPalette.high;
  static const violet = ModuleColors(
    solid: AppPalette.violet600,
    soft: AppPalette.violet100,
    ink: AppPalette.violet700,
  );
  static const rose = ModuleColors(
    solid: AppPalette.rose500,
    soft: AppPalette.rose100,
    ink: AppPalette.rose700,
  );
  static const blue = TagPalette.work;
  static const teal = ActionTints.share;
}

/// The 32-pt solid tile at the start of every row.
class VaultSettingsTile extends StatelessWidget {
  const VaultSettingsTile(this.icon, this.colors, {super.key});

  final IconData icon;
  final ModuleColors colors;

  @override
  Widget build(BuildContext context) => FFIconTile(
    icon: icon,
    colors: colors,
    size: AppSizes.iconTileSm,
    iconSize: AppSizes.tileGlyph,
  );
}

/// Picker options and value labels.
abstract final class VaultSettingsLabels {
  /// Auto-lock delays in minutes (0 = only when leaving the app).
  static const autoLockMinutes = [1, 2, 5, 15, 30, 0];

  /// Clipboard clear delays in seconds (0 = never).
  static const clipboardSeconds = [10, 30, 60, 90, 0];

  static String autoLock(int minutes) =>
      minutes == 0 ? 'On leave' : 'After $minutes min';

  static String autoLockOption(int minutes) =>
      minutes == 0 ? 'Only when I leave the app' : 'After $minutes min';

  static String clipboard(int seconds) => seconds == 0 ? 'Never' : '$seconds s';

  static String clipboardOption(int seconds) => switch (seconds) {
    0 => 'Never',
    60 => 'After 1 minute',
    90 => 'After 90 seconds',
    _ => 'After $seconds seconds',
  };
}
