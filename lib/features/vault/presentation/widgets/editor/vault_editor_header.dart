/// ============================================================
/// VAULT EDITOR HEADER — Cancel · "Edit Item" · Save, type chips (20)
/// ============================================================
///
/// [VaultEditorTopBar]: emerald text buttons either side of a centred
/// Lexend title. [VaultTypeChips]: horizontally scrolling pills (Login ·
/// Card · Wi-Fi · Secure note); the selected one is solid emerald with
/// dark ink, the others glass. Sizes measured from the mockup (÷ 3).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultEditorTopBar extends StatelessWidget {
  const VaultEditorTopBar({
    required this.title,
    required this.onCancel,
    required this.onSave,
    this.saving = false,
    super.key,
  });

  final String title;
  final VoidCallback onCancel;

  /// Null disables Save.
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final link = context.text.rowTitle.copyWith(
      fontSize: VaultType.valueLg,
      fontWeight: FontWeight.w600,
      color: ff.vaultAccent,
    );
    Widget button(String label, VoidCallback? onTap, {bool strong = false}) =>
        Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          excludeSemantics: true,
          child: FFPressable(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppSizes.minTap,
                minHeight: AppSizes.minTap,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: onTap == null
                      ? link.copyWith(color: ff.vaultLabel)
                      : link,
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.grouped,
      ),
      child: Row(
        children: [
          button(tr('Cancel'), onCancel),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.navTitle.copyWith(
                  fontSize: VaultType.nav,
                  fontWeight: FontWeight.w700,
                  color: ff.vaultInk,
                ),
              ),
            ),
          ),
          if (saving)
            SizedBox(
              width: AppSizes.minTap,
              height: AppSizes.minTap,
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ff.vaultAccent,
                  ),
                ),
              ),
            )
          else
            button(tr('Save'), onSave),
        ],
      ),
    );
  }
}

/// Icon of each vault type (chips, icon fallback).
IconData vaultTypeIcon(VaultItemType type) => switch (type) {
  VaultItemType.login => FontAwesomeIcons.key,
  VaultItemType.card => FontAwesomeIcons.solidCreditCard,
  VaultItemType.wifi => FontAwesomeIcons.wifi,
  VaultItemType.secureNote => FontAwesomeIcons.solidNoteSticky,
};

class VaultTypeChips extends StatelessWidget {
  const VaultTypeChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final VaultItemType selected;
  final ValueChanged<VaultItemType> onSelected;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
      ),
      child: Row(
        children: [
          for (final t in VaultItemType.values) ...[
            if (t != VaultItemType.values.first)
              const SizedBox(width: AppSpacing.sm),
            _TypeChip(
              type: t,
              selected: t == selected,
              onTap: () => onSelected(t),
              ff: ff,
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
    required this.ff,
  });

  final VaultItemType type;
  final bool selected;
  final VoidCallback onTap;
  final FFColors ff;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? ff.vaultOnAccentInk : ff.vaultInkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: SizedBox(
          height: AppSizes.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppMotion.fast,
              constraints: const BoxConstraints(minHeight: VaultSizes.chipRow),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md + 1,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: selected ? ff.vaultAccent : ff.vaultSurface,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(vaultTypeIcon(type), size: VaultSizes.iconSm, color: fg),
                  const SizedBox(width: AppSpacing.sm - 1),
                  Text(
                    type.label,
                    style: context.text.rowTitle.copyWith(
                      fontSize: VaultType.callout,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
