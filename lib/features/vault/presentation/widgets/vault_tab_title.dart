/// ============================================================
/// VAULT TAB TITLE — "Generator" / "Security" headers (screens 21 / 22)
/// ============================================================
///
/// Large white Lexend title (26) at the 24-pt gutter with an optional
/// emerald status line ("Last scan: today, 8:02 AM") and a trailing round
/// glass button (generator history). Sizes measured from the mockups.
/// [VaultGlassButton] is that 44-pt round button.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Horizontal inset of the tab titles, segmented control and result card.
const double vaultTabTitleInset = AppSpacing.xxl;

class VaultTabTitle extends StatelessWidget {
  const VaultTabTitle({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        vaultTabTitleInset,
        AppSpacing.xs + 1,
        vaultTabTitleInset - 3,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.largeTitle.copyWith(
                      fontSize: VaultType.title,
                      height: 1.2,
                      color: ff.vaultInk,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall.copyWith(
                      fontSize: VaultType.lead,
                      height: 1.3,
                      color: ff.vaultSubtitle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 44-pt glass disc with an emerald glyph (history button).
class VaultGlassButton extends StatelessWidget {
  const VaultGlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: Container(
          width: AppSizes.minTap,
          height: AppSizes.minTap,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ff.vaultSurface,
            border: Border.all(color: ff.vaultBorder, width: AppSizes.hairline),
          ),
          child: Icon(
            icon,
            size: VaultSizes.iconLg,
            color: ff.vaultAccentBright,
          ),
        ),
      ),
    );
  }
}
