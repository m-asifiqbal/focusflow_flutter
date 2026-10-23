/// ============================================================
/// MEDICINE INSIGHT PARTS — outcome colours, card shell, legend row
/// ============================================================
///
/// Shared by every Insights › Medicine card: [DoseOutcome] (on time /
/// late / skipped / missed with their semantic colours), the
/// [MedicineInsightCard] shell and the tappable [InsightLegendRow].
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';

/// The four dose outcomes, in chart order.
enum DoseOutcome { onTime, late, skipped, missed }

extension DoseOutcomeStyle on DoseOutcome {
  String get label => switch (this) {
    DoseOutcome.onTime => tr('On time'),
    DoseOutcome.late => tr('Late'),
    DoseOutcome.skipped => tr('Skipped'),
    DoseOutcome.missed => tr('Missed'),
  };

  Color color(BuildContext context) {
    final ff = context.ff;
    return switch (this) {
      DoseOutcome.onTime => ff.success,
      DoseOutcome.late => ff.warning,
      DoseOutcome.skipped => ActionTints.lock.solid,
      DoseOutcome.missed => ff.danger,
    };
  }

  int of(DoseCounts c) => switch (this) {
    DoseOutcome.onTime => c.onTime,
    DoseOutcome.late => c.late,
    DoseOutcome.skipped => c.skipped,
    DoseOutcome.missed => c.missed,
  };
}

/// Card shell shared by the medicine insight cards: title + caption.
class MedicineInsightCard extends StatelessWidget {
  const MedicineInsightCard({
    required this.title,
    required this.child,
    this.caption,
    super.key,
  });

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) => FFCard(
    padding: const EdgeInsetsDirectional.all(InsightsDimens.cardPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: context.text.sectionTitle.copyWith(
              fontSize: InsightsDimens.cardTitle,
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(caption!, style: context.text.meta),
        ],
        const SizedBox(height: InsightsDimens.cardGap),
        child,
      ],
    ),
  );
}

/// A coloured dot + label (+ value) legend row; tappable.
class InsightLegendRow extends StatelessWidget {
  const InsightLegendRow({
    required this.color,
    required this.label,
    required this.value,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final Color color;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '$label, $value',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motion(AppMotion.fast),
          constraints: const BoxConstraints(minHeight: AppSizes.minTap - 8),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(AppRadii.tileSm),
          ),
          child: Row(
            children: [
              Container(
                width: InsightsDimens.legendDot,
                height: InsightsDimens.legendDot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall.copyWith(color: ff.ink),
                ),
              ),
              Text(
                value,
                style: context.text.rowTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
