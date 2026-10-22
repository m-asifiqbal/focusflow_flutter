/// ============================================================
/// VAULT HEALTH CARD — "Security health 98%" + checklist (screen 19)
/// ============================================================
///
/// Shield disc · title + "Overall rating: Excellent" · big score; an
/// emerald→teal bar; a two-column checklist (No breaches · Unique ·
/// 16+ characters · 2FA enabled) with green ticks, amber warnings and a
/// neutral dot for "not checked yet". Data: VaultHealth (domain).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/vault/domain/services/vault_health.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_fields.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultHealthCard extends StatelessWidget {
  const VaultHealthCard({required this.health, super.key});

  final VaultHealth health;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final good = health.score >= 75;
    final scoreColor = good ? ff.vaultAccentBright : ff.vaultWeak.fg;
    return VaultCard(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            vaultFieldInset,
            vaultFieldInset,
            vaultFieldInset,
            AppSpacing.md + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                label: tr('Security health {score} percent, rating {rating}', {
                  'score': health.score,
                  'rating': health.rating,
                }),
                excludeSemantics: true,
                child: Row(
                  children: [
                    Container(
                      width: AppSizes.roundButton,
                      height: AppSizes.roundButton,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ff.vaultAccentTint,
                      ),
                      child: Icon(
                        FontAwesomeIcons.shieldHeart,
                        size: VaultSizes.iconMd,
                        color: ff.vaultAccentBright,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md + 1),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Security health'),
                            style: context.text.sectionTitle.copyWith(
                              fontSize: VaultType.value,
                              color: ff.vaultInk,
                            ),
                          ),
                          Text(
                            tr('Overall rating: {rating}', {
                              'rating': health.rating,
                            }),
                            style: context.text.bodySmall.copyWith(
                              fontSize: VaultType.small,
                              height: 1.4,
                              color: ff.vaultSubtitleMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${health.score}%',
                      style: context.text.bigStat.copyWith(
                        fontSize: VaultType.title,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg + 1),
              _Bar(progress: health.score / 100),
              const SizedBox(height: AppSpacing.md - 2),
              LayoutBuilder(
                builder: (context, c) {
                  final half = (c.maxWidth - AppSpacing.sm) / 2;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      for (final check in health.checks)
                        SizedBox(width: half, child: _Check(check)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return ExcludeSemantics(
      child: Container(
        height: VaultSizes.healthBar,
        decoration: BoxDecoration(
          color: ff.vaultTrack,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.02, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ff.vaultHealthGradient,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.check);

  final VaultHealthCheck check;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final (icon, color) = check.unknown
        ? (FontAwesomeIcons.solidCircleQuestion, ff.vaultFieldLabel)
        : check.ok
        ? (FontAwesomeIcons.solidCircleCheck, ff.vaultAccent)
        : (FontAwesomeIcons.circleExclamation, ff.vaultWeak.fg);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: VaultSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              check.label,
              style: context.text.body.copyWith(
                fontSize: VaultType.subtitle,
                height: 1.5,
                color: ff.vaultInkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
