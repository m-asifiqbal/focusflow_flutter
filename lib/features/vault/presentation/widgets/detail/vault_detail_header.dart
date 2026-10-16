/// ============================================================
/// VAULT DETAIL HEADER — "‹ Vault" · heart · Edit, then the hero (19)
/// ============================================================
///
/// [VaultDetailTopBar]: back link, round favourite toggle (glass disc,
/// emerald heart when on) and the emerald "Edit" pill.
/// [VaultDetailHero]: 76 pt brand tile, title (Lexend 25 w700) and
/// "Personal · Updated 3 days ago".
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_avatar.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultDetailTopBar extends StatelessWidget {
  const VaultDetailTopBar({
    required this.isFavorite,
    required this.onFavorite,
    required this.onEdit,
    super.key,
  });

  final bool isFavorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg - 4,
        AppSpacing.xxs,
        AppSpacing.lg + 4,
        0,
      ),
      child: Row(
        children: [
          const FFBackButton(label: 'Vault'),
          const Spacer(),
          Semantics(
            button: true,
            toggled: isFavorite,
            label: isFavorite ? 'Remove from favourites' : 'Add to favourites',
            excludeSemantics: true,
            child: FFPressable(
              onTap: onFavorite,
              scale: 0.92,
              child: Container(
                width: AppSizes.roundButton,
                height: AppSizes.roundButton,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ff.vaultSurface,
                  border: Border.all(color: ff.vaultBorder),
                ),
                child: Icon(
                  isFavorite
                      ? FontAwesomeIcons.solidHeart
                      : FontAwesomeIcons.heart,
                  size: VaultSizes.iconMd,
                  color: isFavorite ? ff.vaultAccent : ff.vaultInkMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: 'Edit item',
            excludeSemantics: true,
            child: FFPressable(
              onTap: onEdit,
              child: Container(
                height: AppSizes.roundButton,
                constraints: const BoxConstraints(
                  minWidth: VaultSizes.backLabel,
                ),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ff.vaultAccent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  'Edit',
                  style: context.text.rowTitle.copyWith(
                    fontSize: VaultType.navLg,
                    fontWeight: FontWeight.w600,
                    color: ff.vaultOnAccentInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VaultDetailHero extends StatelessWidget {
  const VaultDetailHero({
    required this.record,
    required this.subtitle,
    super.key,
  });

  final VaultItemRecord record;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.lg + 1,
        AppSpacing.screen,
        0,
      ),
      child: Column(
        children: [
          VaultAvatar.record(
            record,
            size: VaultSizes.detailAvatar,
            radius: AppRadii.card,
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          Semantics(
            header: true,
            child: Text(
              record.title,
              textAlign: TextAlign.center,
              style: context.text.title.copyWith(
                fontSize: VaultType.titleLg,
                color: ff.vaultInk,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs + 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(
              fontSize: VaultType.secondary,
              height: 1.4,
              color: ff.vaultSubtitleMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Personal · Updated 3 days ago" (no folder → "Updated …" only).
String vaultUpdatedSubtitle(VaultItemRecord r, DateTime now) {
  final diff = now.difference(r.updatedAt);
  final when = diff.inMinutes < 1
      ? 'just now'
      : diff.inMinutes < 60
      ? '${diff.inMinutes} min ago'
      : diff.inHours < 24
      ? '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago'
      : diff.inDays == 1
      ? 'yesterday'
      : diff.inDays < 30
      ? '${diff.inDays} days ago'
      : diff.inDays < 365
      ? '${diff.inDays ~/ 30} ${diff.inDays < 60 ? 'month' : 'months'} ago'
      : '${diff.inDays ~/ 365} ${diff.inDays < 730 ? 'year' : 'years'} ago';
  final folder = r.folderName;
  final updated = 'Updated $when';
  return folder == null || folder.isEmpty ? updated : '$folder · $updated';
}
