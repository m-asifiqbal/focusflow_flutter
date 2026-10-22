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
import 'package:focusflow/core/l10n/tr.dart';
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
          FFBackButton(label: tr('Vault')),
          const Spacer(),
          Semantics(
            button: true,
            toggled: isFavorite,
            label: isFavorite
                ? tr('Remove from favourites')
                : tr('Add to favourites'),
            excludeSemantics: true,
            child: FFPressable(
              onTap: onFavorite,
              scale: 0.92,
              child: Container(
                width: VaultSizes.toolbarButton,
                height: VaultSizes.toolbarButton,
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
            label: tr('Edit item'),
            excludeSemantics: true,
            child: FFPressable(
              onTap: onEdit,
              child: Container(
                height: VaultSizes.toolbarButton - 4,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md + 2,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ff.vaultAccent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  tr('Edit'),
                  style: context.text.rowTitle.copyWith(
                    fontSize: VaultType.value,
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
  // One whole sentence per case (not "Updated " + a time fragment): word
  // order and plural forms differ between languages.
  final updated = diff.inMinutes < 1
      ? tr('Updated just now')
      : diff.inMinutes < 60
      ? tr('Updated {n} min ago', {'n': diff.inMinutes})
      : diff.inHours < 24
      ? tr(
          '{count, plural, one {Updated # hour ago} other {Updated # hours ago}}',
          {'count': diff.inHours},
        )
      : diff.inDays == 1
      ? tr('Updated yesterday')
      : diff.inDays < 30
      ? tr(
          '{count, plural, one {Updated # day ago} other {Updated # days ago}}',
          {'count': diff.inDays},
        )
      : diff.inDays < 365
      ? tr(
          '{count, plural, one {Updated # month ago} other {Updated # months ago}}',
          {'count': diff.inDays ~/ 30},
        )
      : tr(
          '{count, plural, one {Updated # year ago} other {Updated # years ago}}',
          {'count': diff.inDays ~/ 365},
        );
  final folder = r.folderName;
  return folder == null || folder.isEmpty ? updated : '$folder · $updated';
}
