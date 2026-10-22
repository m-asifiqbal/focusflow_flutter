/// ============================================================
/// VAULT SECURITY SUMMARY — health ring, weekly delta, four tiles (22)
/// ============================================================
///
/// [VaultHealthRing]  — 168-pt ring (stroke 14) with the 0–100 score and
///   "HEALTH SCORE"; emerald ≥ 80, amber ≥ 50, rose below.
/// [VaultScoreDelta]  — "+6 since last week" pill.
/// [VaultStatTiles]   — Breached · Reused · Weak · Strong counts.
/// Sizes measured from the 1170-px mockup (÷ 3).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/services/vault_security_report.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Colour of an issue kind (label, icon) and its tile tint.
extension VaultIssueTones on FFColors {
  VaultTone vaultIssueTone(VaultIssueKind kind) => switch (kind) {
    VaultIssueKind.breached => vaultBreached,
    VaultIssueKind.reused => vaultReused,
    VaultIssueKind.weak => vaultWeak,
    VaultIssueKind.old => VaultTone(
      vaultSecretDigit,
      vaultSecretDigit.withValues(alpha: 0.16),
    ),
  };

  /// Ring / score colour for a health score.
  Color vaultScoreColor(int score) => score >= 80
      ? vaultAccent
      : score >= 50
      ? vaultFair.fg
      : vaultBreached.fg;
}

class VaultHealthRing extends StatelessWidget {
  const VaultHealthRing({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFProgressRing(
      progress: score / 100,
      size: VaultSizes.scoreGauge,
      stroke: VaultSizes.scoreStroke,
      color: ff.vaultScoreColor(score),
      trackColor: ff.vaultKey,
      semanticLabel: tr('Health score {score} out of 100', {'score': score}),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              textScaler: TextScaler.noScaling,
              style: context.text.largeTitle.copyWith(
                fontSize: VaultType.hero,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: ff.vaultInk,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('HEALTH SCORE'),
              textScaler: TextScaler.noScaling,
              style: context.text.sectionLabel.copyWith(
                fontSize: VaultType.badge,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
                color: ff.vaultAccent.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "+6 since last week" (hidden by the caller when there is no snapshot).
class VaultScoreDelta extends StatelessWidget {
  const VaultScoreDelta({required this.delta, super.key});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final up = delta >= 0;
    final fg = up ? ff.vaultAccentBright : ff.vaultFair.fg;
    final text = delta == 0
        ? tr('No change since last week')
        : tr('{change} since last week', {
            'change': '${up ? '+' : '−'}${delta.abs()}',
          });
    return Container(
      constraints: const BoxConstraints(minHeight: VaultSizes.summaryPill),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: up ? ff.vaultAccentTint : ff.vaultFair.bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delta == 0
                ? FontAwesomeIcons.minus
                : up
                ? FontAwesomeIcons.arrowTrendUp
                : FontAwesomeIcons.arrowTrendDown,
            size: VaultSizes.iconSm,
            color: fg,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Flexible(
            child: Text(
              text,
              style: context.text.body.copyWith(
                fontSize: VaultType.secondary,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VaultStatTiles extends StatelessWidget {
  const VaultStatTiles({required this.report, super.key});

  final VaultSecurityReport report;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final tiles = [
      (
        report.breached,
        tr('Breached'),
        ff.vaultBreached.fg,
        tr('{count} breached', {'count': report.breached}),
      ),
      (
        report.reused,
        tr('Reused'),
        ff.vaultReused.fg,
        tr('{count} reused', {'count': report.reused}),
      ),
      (
        report.weak,
        tr('Weak'),
        ff.vaultWeak.fg,
        tr('{count} weak', {'count': report.weak}),
      ),
      (
        report.strong,
        tr('Strong'),
        ff.vaultAccentBright,
        tr('{count} strong', {'count': report.strong}),
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: VaultSizes.gapTile),
            Expanded(
              child: Semantics(
                label: tiles[i].$4,
                excludeSemantics: true,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: VaultSizes.securityTile,
                  ),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: ff.vaultSurface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: ff.vaultBorder),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${tiles[i].$1}',
                        style: context.text.title.copyWith(
                          fontSize: VaultType.stat,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: tiles[i].$3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        tiles[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.body.copyWith(
                          fontSize: VaultType.caption,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: ff.vaultSubtitleMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
