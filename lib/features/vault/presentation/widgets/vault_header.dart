/// ============================================================
/// VAULT HEADER — shield tile · "Vault" · status line · lock / add (17/18)
/// ============================================================
///
/// The emerald shield tile doubles as the way out of the vault (the
/// mockups have no back button): it pops back to Library when the vault
/// was pushed. Subtitle: "24 items · AES-256 encrypted" (locked) or
/// "Unlocked · auto-locks in 4:59" (unlocked, live).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultHeader extends StatelessWidget {
  const VaultHeader({
    required this.subtitle,
    required this.onLock,
    required this.onAdd,
    this.lockLabel,
    super.key,
  });

  final String subtitle;
  final VoidCallback? onLock;
  final VoidCallback onAdd;

  /// Defaults to "Lock vault" (resolved when built, in the active language).
  final String? lockLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? false;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.xs + 2,
        AppSpacing.screen,
        0,
      ),
      child: Row(
        children: [
          Semantics(
            button: canPop,
            label: canPop ? tr('Close vault') : tr('Vault'),
            excludeSemantics: true,
            child: FFPressable(
              onTap: canPop ? () => context.pop() : null,
              child: Container(
                width: VaultSizes.toolbarButton + 2,
                height: VaultSizes.toolbarButton + 2,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ff.vaultAccent,
                  borderRadius: BorderRadius.circular(AppRadii.tileLg),
                ),
                child: Icon(
                  FontAwesomeIcons.shieldHalved,
                  size: VaultSizes.iconLg,
                  color: ff.vaultOnAccentInk,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    tr('Vault'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.largeTitle.copyWith(
                      fontSize: VaultType.title,
                      height: 1.1,
                      color: ff.vaultInk,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall.copyWith(
                    fontSize: VaultType.small,
                    height: 1.3,
                    letterSpacing: -0.1,
                    color: ff.vaultSubtitle,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FFRoundIconButton(
            icon: FontAwesomeIcons.lock,
            semanticLabel: lockLabel ?? tr('Lock vault'),
            onPressed: onLock,
            size: VaultSizes.toolbarButton,
            iconSize: VaultSizes.iconMd,
            variant: FFRoundIconButtonVariant.dark,
          ),
          const SizedBox(width: VaultSizes.gapSm),
          FFRoundIconButton(
            icon: FontAwesomeIcons.plus,
            semanticLabel: tr('Add password'),
            onPressed: onAdd,
            size: VaultSizes.toolbarButton,
            iconSize: VaultSizes.iconMd,
            variant: FFRoundIconButtonVariant.dark,
          ),
        ],
      ),
    );
  }
}
