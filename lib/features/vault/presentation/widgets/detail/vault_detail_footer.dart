/// ============================================================
/// VAULT DETAIL FOOTER — notes, password history, Archive / Delete (19)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// NOTES card (+ "Password history · 4 versions" row when there is any).
class VaultNotesCard extends StatelessWidget {
  const VaultNotesCard({
    required this.notes,
    required this.historyCount,
    required this.onHistory,
    this.onCopy,
    super.key,
  });

  final String notes;
  final int historyCount;
  final VoidCallback onHistory;

  /// Copies the notes through the secure clipboard (auto-clear). The text
  /// itself is not selectable: a system "Copy" would bypass the clear.
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return VaultCard(
      children: [
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              vaultFieldInset,
              AppSpacing.md + 1,
              vaultFieldInset,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: VaultFieldLabel(tr('Notes'))),
                    if (onCopy != null)
                      VaultRoundButton(
                        icon: FontAwesomeIcons.solidCopy,
                        semanticLabel: tr('Copy notes'),
                        onTap: onCopy,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs + 1),
                Text(
                  notes,
                  style: context.text.body.copyWith(
                    fontSize: VaultType.lead,
                    height: 1.65,
                    color: ff.vaultInkSoft,
                  ),
                ),
              ],
            ),
          ),
        if (historyCount > 0)
          Semantics(
            button: true,
            label: tr(
              '{count, plural, one {Password history, # version} other {Password history, # versions}}',
              {'count': historyCount},
            ),
            excludeSemantics: true,
            child: FFPressable(
              onTap: onHistory,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: VaultSizes.footerRow,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    vaultFieldInset,
                    AppSpacing.md,
                    vaultFieldInset,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(
                            '{count, plural, one {Password history · # version} other {Password history · # versions}}',
                            {'count': historyCount},
                          ),
                          style: context.text.rowTitle.copyWith(
                            fontSize: VaultType.row,
                            color: ff.vaultAccentBright,
                          ),
                        ),
                      ),
                      Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? FontAwesomeIcons.chevronLeft
                            : FontAwesomeIcons.chevronRight,
                        size: VaultSizes.iconXs,
                        color: ff.vaultAccent.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Archive (glass) and Delete (rose) side by side.
class VaultDetailActions extends StatelessWidget {
  const VaultDetailActions({
    required this.onArchive,
    required this.onDelete,
    this.archiveLabel,
    this.archiveIcon = FontAwesomeIcons.boxArchive,
    this.deleteLabel,
    super.key,
  });

  final VoidCallback onArchive;
  final VoidCallback onDelete;

  /// Defaults to "Archive" / "Delete" (resolved when built, so the text
  /// follows the active language).
  final String? archiveLabel;
  final IconData archiveIcon;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final danger = ff.vaultDanger;
    return Row(
      children: [
        Expanded(
          child: _Button(
            label: archiveLabel ?? tr('Archive'),
            icon: archiveIcon,
            fg: ff.vaultInk.withValues(alpha: 0.9),
            bg: ff.vaultKey,
            onTap: onArchive,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Button(
            label: deleteLabel ?? tr('Delete'),
            icon: FontAwesomeIcons.trashCan,
            fg: danger.fg,
            bg: danger.bg,
            onTap: onDelete,
          ),
        ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: FFPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.secondaryButton),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.button + 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: VaultSizes.iconButton, color: fg),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: context.text.button.copyWith(
                  fontSize: VaultType.value,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
