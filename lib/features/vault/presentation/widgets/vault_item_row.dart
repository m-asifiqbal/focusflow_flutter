/// ============================================================
/// VAULT ITEM ROW — one row of the grouped dark list (screen 18)
/// ============================================================
///
/// Brand / letter avatar 44 · title (+ heart when favourite) · muted
/// username · status badge (STRONG / FAIR / WEAK / REUSED / BREACHED) ·
/// 36 pt copy button (44 pt tap target). Tap → detail (19); long-press →
/// item actions sheet; swipe → Settings › Gestures actions.
/// [VaultItemGroup] is the glass card that stacks rows with inset dividers.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_list_providers.dart';
import 'package:focusflow/features/vault/presentation/vault_copy_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_avatar.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/item_actions/item_swipe.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Inset between the card edge and the avatar.
const double _inset = AppSpacing.lg;

/// Glass card with rows separated by dividers inset to the text column.
class VaultItemGroup extends StatelessWidget {
  const VaultItemGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const radius = BorderRadius.all(Radius.circular(AppRadii.dialog - 6));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ff.vaultSurface,
        borderRadius: radius,
        border: Border.all(color: ff.vaultBorder),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: _inset + AppSizes.roundButton + 14,
                  color: ff.vaultBorder,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class VaultItemRow extends ConsumerWidget {
  const VaultItemRow({required this.entry, super.key});

  final VaultListEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final r = entry.record;
    final title = r.title.isEmpty ? 'Untitled' : r.title;
    final row = Semantics(
      container: true,
      button: true,
      label: [
        title,
        if (r.isFavorite) 'favourite',
        if (entry.subtitle.isNotEmpty) entry.subtitle,
        if (entry.badge != null) _badgeText(entry.badge!).toLowerCase(),
      ].join(', '),
      child: FFPressable(
        scale: 0.99,
        onTap: () {
          ref.read(vaultSessionProvider.notifier).touch();
          unawaited(context.push(AppRoutes.vaultItem(r.id)));
        },
        onLongPress: () => unawaited(showItemActions(context, ref, r.ref)),
        child: Container(
          constraints: const BoxConstraints(minHeight: VaultSizes.itemRow),
          padding: const EdgeInsetsDirectional.fromSTEB(
            _inset,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              VaultAvatar.record(r),
              const SizedBox(width: AppSpacing.rowLeadingGap),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.cardTitle.copyWith(
                                color: ff.vaultInk,
                              ),
                            ),
                          ),
                          if (r.isFavorite) ...[
                            const SizedBox(width: VaultSizes.gapXs),
                            Icon(
                              FontAwesomeIcons.solidHeart,
                              size: VaultSizes.iconXxs,
                              color: ff.vaultHeart,
                            ),
                          ],
                        ],
                      ),
                      if (entry.subtitle.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          entry.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall.copyWith(
                            fontSize: VaultType.meta,
                            height: 1.4,
                            color: ff.vaultInkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (entry.badge != null) ...[
                const SizedBox(width: AppSpacing.sm),
                VaultStatusBadge(entry.badge!),
              ],
              const SizedBox(width: VaultSizes.gapSm),
              _CopyButton(
                label: 'Copy password for $title',
                onTap: () => unawaited(copyVaultSecret(context, ref, r)),
              ),
            ],
          ),
        ),
      ),
    );
    return ItemSwipe(
      item: r.ref,
      isPinned: r.isPinned,
      isFavorite: r.isFavorite,
      radius: 0,
      title: title,
      child: row,
    );
  }
}

String _badgeText(VaultBadge b) => switch (b) {
  VaultBadge.strong => 'STRONG',
  VaultBadge.fair => 'FAIR',
  VaultBadge.weak => 'WEAK',
  VaultBadge.reused => 'REUSED',
  VaultBadge.breached => 'BREACHED',
};

/// Small uppercase status pill.
class VaultStatusBadge extends StatelessWidget {
  const VaultStatusBadge(this.badge, {super.key});

  final VaultBadge badge;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final tone = switch (badge) {
      VaultBadge.strong => ff.vaultStrong,
      VaultBadge.fair => ff.vaultFair,
      VaultBadge.weak => ff.vaultWeak,
      VaultBadge.reused => ff.vaultReused,
      VaultBadge.breached => ff.vaultBreached,
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(AppRadii.tileSm - 2),
      ),
      child: Text(
        _badgeText(badge),
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 1.15),
        style: context.text.tag.copyWith(
          fontSize: VaultType.badge,
          letterSpacing: 0.3,
          color: tone.fg,
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    // Own node (container) with its own tap: nested in the row's button,
    // it would otherwise merge into the row's label.
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.92,
        child: SizedBox(
          width: AppSizes.minTap,
          height: AppSizes.minTap,
          child: Center(
            child: Container(
              width: VaultSizes.smallButton,
              height: VaultSizes.smallButton,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ff.vaultKey,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Icon(
                FontAwesomeIcons.solidCopy,
                size: VaultSizes.iconMd,
                color: ff.vaultAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
