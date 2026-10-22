/// ============================================================
/// VAULT ISSUE LIST — "NEEDS ATTENTION" card + all-good state (22)
/// ============================================================
///
/// Each row: tinted 44-pt icon tile · BREACHED / REUSED / WEAK / OLD label ·
/// item title · reason · action pill (Change / Fix / Update). The pill is
/// 30 pt tall inside a 44-pt tap target. [VaultAllGood] replaces the card
/// when nothing needs attention.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/services/vault_security_report.dart';
import 'package:focusflow/features/vault/presentation/vault_security_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/security/vault_security_summary.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultIssueCard extends StatelessWidget {
  const VaultIssueCard({required this.issues, required this.onFix, super.key});

  final List<VaultIssue> issues;
  final ValueChanged<VaultIssue> onFix;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ff.vaultSurface,
        borderRadius: BorderRadius.circular(vaultCardRadius),
        border: Border.all(color: ff.vaultBorder),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            for (final issue in issues)
              _IssueRow(issue: issue, onFix: () => onFix(issue)),
          ],
        ),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.onFix});

  final VaultIssue issue;
  final VoidCallback onFix;

  static IconData _icon(VaultIssueKind kind) => switch (kind) {
    VaultIssueKind.breached => FontAwesomeIcons.triangleExclamation,
    VaultIssueKind.reused => FontAwesomeIcons.solidCopy,
    VaultIssueKind.weak => FontAwesomeIcons.lockOpen,
    VaultIssueKind.old => FontAwesomeIcons.solidHourglassHalf,
  };

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final tone = ff.vaultIssueTone(issue.kind);
    final action = vaultIssueAction(issue.kind);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg + 0.5,
        AppSpacing.md + 5,
        AppSpacing.lg + 0.5,
        AppSpacing.md + 5,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: AppSizes.minTap,
              height: AppSizes.minTap,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.bg,
                borderRadius: BorderRadius.circular(AppRadii.tileLg - 1),
              ),
              child: Icon(
                _icon(issue.kind),
                size: VaultSizes.iconLg,
                color: tone.fg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg + 2),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    issue.kind.label,
                    style: context.text.sectionLabel.copyWith(
                      fontSize: VaultType.micro,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      height: 1.25,
                      color: tone.fg,
                    ),
                  ),
                  Text(
                    issue.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.title.copyWith(
                      fontSize: VaultType.row,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: ff.vaultInk,
                    ),
                  ),
                  Text(
                    issue.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.body.copyWith(
                      fontSize: VaultType.meta,
                      height: 1.3,
                      color: ff.vaultSubtitleMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: tr('{action} {title}', {
              'action': action,
              'title': issue.title,
            }),
            excludeSemantics: true,
            child: FFPressable(
              onTap: onFix,
              child: SizedBox(
                height: AppSizes.minTap,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: AppSizes.minTap - 4,
                    ),
                    // No `alignment`: it would stretch the pill to the
                    // 44-pt tap target.
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.pillVertical,
                    ),
                    decoration: BoxDecoration(
                      color: ff.vaultInk.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(AppRadii.tileLg),
                    ),
                    child: Text(
                      action,
                      style: context.text.body.copyWith(
                        fontSize: VaultType.small,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: ff.vaultInk,
                      ),
                    ),
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

/// "Your vault is in great shape".
class VaultAllGood extends StatelessWidget {
  const VaultAllGood({super.key});

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return VaultCard(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            children: [
              Container(
                width: VaultSizes.emptyBadge,
                height: VaultSizes.emptyBadge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ff.vaultAccentTint,
                ),
                child: Icon(
                  FontAwesomeIcons.check,
                  size: VaultSizes.emptyGlyph,
                  color: ff.vaultAccentBright,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                tr('Your vault is in great shape'),
                textAlign: TextAlign.center,
                style: context.text.title.copyWith(
                  fontSize: VaultType.heading,
                  fontWeight: FontWeight.w600,
                  color: ff.vaultInk,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tr('No breached, reused, weak or old passwords.'),
                textAlign: TextAlign.center,
                style: context.text.body.copyWith(
                  fontSize: VaultType.lead,
                  color: ff.vaultSubtitleMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
