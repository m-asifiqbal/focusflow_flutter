/// ============================================================
/// WEEKLY TIP CARD — accent-gradient tip with a lightbulb (mockup 25)
/// ============================================================
///
/// Shows the rule-based tip from InsightsTips (domain). The gradient is the
/// accent's own, so it follows the chosen accent colour in both modes.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';

class WeeklyTipCard extends StatelessWidget {
  const WeeklyTipCard({required this.tip, super.key});

  final InsightsTip tip;

  @override
  Widget build(BuildContext context) {
    const on = InsightsColors.onGradient;
    return Semantics(
      label: tr('Weekly tip. {body}', {'body': tip.body}),
      excludeSemantics: true,
      child: FFCard(
        gradient: context.ff.primaryGradient,
        border: false,
        padding: const EdgeInsetsDirectional.all(InsightsDimens.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(top: AppSpacing.xxs),
              child: Icon(
                FontAwesomeIcons.solidLightbulb,
                size: InsightsDimens.tipIcon,
                color: InsightsColors.tipBulb,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Weekly tip'),
                    style: context.text.sectionTitle.copyWith(
                      fontSize: InsightsDimens.tipTitle,
                      color: on,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tip.body,
                    style: context.text.bodySmall.copyWith(
                      fontSize: InsightsDimens.tipBody,
                      color: on.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
