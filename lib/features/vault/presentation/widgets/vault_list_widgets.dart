/// ============================================================
/// VAULT LIST WIDGETS — category tiles, breach banner, "A – Z" header
/// ============================================================
///
/// Pieces of screen 18 above the rows:
/// * [VaultCategoryTiles] — Logins 16 · Cards 3 · Wi-Fi 2 · Secure notes 3
///   (horizontal, 112 × 116, radius 22); tap filters by type.
/// * [VaultBreachBanner]  — rose pill "1 password found in a data breach"
///   + "Fix now".
/// * [VaultSectionHeader] — "A – Z" / "RECENT" label + Sort toggle.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

IconData vaultTypeIcon(VaultItemType type) => switch (type) {
  VaultItemType.login => FontAwesomeIcons.key,
  VaultItemType.card => FontAwesomeIcons.solidCreditCard,
  VaultItemType.wifi => FontAwesomeIcons.wifi,
  VaultItemType.secureNote => FontAwesomeIcons.solidNoteSticky,
};

class VaultCategoryTiles extends StatelessWidget {
  const VaultCategoryTiles({
    required this.counts,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final VaultCounts? counts;
  final VaultItemType? selected;
  final ValueChanged<VaultItemType> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final type in VaultItemType.values) ...[
            if (type.index > 0) const SizedBox(width: VaultSizes.gapTile),
            _CategoryTile(
              type: type,
              count: counts?.byType[type] ?? 0,
              selected: selected == type,
              onTap: () => onSelect(type),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.type,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final VaultItemType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      selected: selected,
      label: '${type.plural}, $count ${count == 1 ? 'item' : 'items'}',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motion(AppMotion.fast),
          width: VaultSizes.categoryCardWidth,
          constraints: const BoxConstraints(minHeight: VaultSizes.categoryCard),
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: selected ? ff.vaultKey : ff.vaultSurface,
            borderRadius: BorderRadius.circular(AppRadii.card + 2),
            border: Border.all(
              color: selected ? ff.vaultAccent : ff.vaultBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                vaultTypeIcon(type),
                size: VaultSizes.iconMd,
                color: ff.vaultCategory(type),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                type.plural,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.cardTitle.copyWith(
                  fontSize: VaultType.callout,
                  color: ff.vaultInk,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '$count ${count == 1 ? 'item' : 'items'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.meta.copyWith(
                  fontSize: VaultType.caption,
                  color: ff.vaultInkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VaultBreachBanner extends StatelessWidget {
  const VaultBreachBanner({
    required this.count,
    required this.onFix,
    super.key,
  });

  final int count;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final tone = ff.vaultAlert;
    final message = count == 1
        ? '1 password found in a data breach'
        : '$count passwords found in data breaches';
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.minTap),
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.lg),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: ff.vaultAlertBorder),
      ),
      child: Row(
        children: [
          Icon(
            FontAwesomeIcons.triangleExclamation,
            size: VaultSizes.iconMd,
            color: ff.vaultAlertIcon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: AppSpacing.sm,
              ),
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall.copyWith(
                  fontSize: VaultType.secondary,
                  height: 1.3,
                  color: ff.vaultInk.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          FFTextButton(
            label: 'Fix now',
            onPressed: onFix,
            color: tone.fg,
            style: _linkStyle(context),
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.sm,
              end: AppSpacing.lg,
            ),
            semanticLabel: 'Fix breached passwords',
          ),
        ],
      ),
    );
  }
}

class VaultSectionHeader extends StatelessWidget {
  const VaultSectionHeader({
    required this.sort,
    required this.onSort,
    super.key,
  });

  final VaultSort sort;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final label = sort == VaultSort.az ? 'A – Z' : 'RECENT';
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.screen),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label,
                style: context.text.sectionLabel.copyWith(
                  fontSize: VaultType.caption,
                  letterSpacing: 1.5,
                  color: ff.vaultLabel,
                ),
              ),
            ),
          ),
          FFTextButton(
            label: 'Sort',
            icon: sort == VaultSort.az
                ? FontAwesomeIcons.arrowDownAZ
                : FontAwesomeIcons.arrowDownShortWide,
            onPressed: onSort,
            color: ff.vaultAccent,
            style: _linkStyle(context),
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.sm,
              end: AppSpacing.screen,
            ),
            semanticLabel: sort == VaultSort.az
                ? 'Sort: A to Z. Switch to most recent'
                : 'Sort: most recent. Switch to A to Z',
          ),
        ],
      ),
    );
  }
}

/// "Fix now" / "Sort": Nunito Sans 13.5 w800, as in mockup 18.
TextStyle _linkStyle(BuildContext context) => context.text.bodySmall.copyWith(
  fontSize: VaultType.subtitle,
  fontWeight: FontWeight.w800,
);
