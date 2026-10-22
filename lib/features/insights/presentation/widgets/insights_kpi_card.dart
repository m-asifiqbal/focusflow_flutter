/// ============================================================
/// INSIGHTS KPI CARD — "TASK COMPLETION 84% ▲ 12%" (mockup 25)
/// ============================================================
///
/// What: an uppercase label, a big value and an optional ▲/▼ delta
/// against the previous window (green up, rose down; no delta when either
/// window has no data). [InsightsKpiGrid] lays four out 2×2 with equal
/// row heights.
/// Why: FFStatTile has no delta slot. Value and delta sit in a Wrap so the
/// delta drops below the value at 360 pt / text scale 1.3 instead of
/// overflowing.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_motion.dart';

/// A change against the previous window; [value] 0 shows a neutral dash.
@immutable
class KpiDelta {
  const KpiDelta(this.value, this.unit);

  final num value;

  /// "%", "h" or "".
  final String unit;
}

class InsightsKpiCard extends StatelessWidget {
  const InsightsKpiCard({
    required this.label,
    required this.value,
    this.number,
    this.format,
    this.delta,
    this.onTap,
    this.semanticHint,
    super.key,
  });

  final String label;
  final String value;

  /// When both are given the value counts up to [number] ([format] must
  /// give [value] for it); otherwise [value] is shown as is ("—").
  final double? number;
  final String Function(double v)? format;
  final KpiDelta? delta;
  final VoidCallback? onTap;

  /// Extra screen-reader text ("Double tap to start a focus session").
  final String? semanticHint;

  Widget _value(TextStyle style) {
    final n = number;
    final f = format;
    if (n == null || f == null) return Text(value, maxLines: 1, style: style);
    return AnimatedCount(value: n, format: f, style: style);
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final d = delta;
    final up = d != null && d.value > 0;
    final down = d != null && d.value < 0;
    final deltaColor = up ? ff.success : (down ? ff.danger : ff.inkFaint);
    // Font Awesome carets: the text fonts have no ▲ / ▼ glyphs.
    final arrow = up
        ? FontAwesomeIcons.caretUp
        : (down ? FontAwesomeIcons.caretDown : FontAwesomeIcons.minus);
    final deltaText = d == null ? null : InsightsFormat.delta(d.value, d.unit);
    final spoken = d == null
        ? ''
        : (up
              ? ', up ${InsightsFormat.delta(d.value, d.unit)}'
              : down
              ? ', down ${InsightsFormat.delta(d.value, d.unit)}'
              : ', no change');

    return Semantics(
      label: '$label: $value$spoken',
      hint: semanticHint,
      button: onTap != null,
      excludeSemantics: true,
      child: FFCard(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.all(InsightsDimens.kpiPadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight:
                InsightsDimens.kpiMinHeight - InsightsDimens.kpiPadding * 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // One line like the mockup; a long label ("HABIT
              // CONSISTENCY") shrinks to fit rather than wrapping.
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        style: context.text.sectionLabel.copyWith(
                          letterSpacing: InsightsDimens.kpiLabelTracking,
                        ),
                      ),
                    ),
                  ),
                  // A tappable card says so (Focus hours starts a session).
                  if (onTap != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      FontAwesomeIcons.play,
                      size: InsightsDimens.kpiDeltaIcon - 2,
                      color: ff.primary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xxs,
                children: [
                  _value(
                    context.text.bigStat.copyWith(
                      fontSize: InsightsDimens.kpiValue,
                    ),
                  ),
                  if (deltaText != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          arrow,
                          size: InsightsDimens.kpiDeltaIcon,
                          color: deltaColor,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          deltaText,
                          maxLines: 1,
                          style: context.text.meta.copyWith(
                            fontSize: InsightsDimens.kpiDelta,
                            fontWeight: FontWeight.w800,
                            color: deltaColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four KPI cards, two per row, rows of equal height.
class InsightsKpiGrid extends StatelessWidget {
  const InsightsKpiGrid({required this.cards, super.key});

  /// Exactly four, in reading order.
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: InsightsDimens.kpiGap),
          Expanded(child: b),
        ],
      ),
    );
    return Column(
      children: [
        row(cards[0], cards[1]),
        const SizedBox(height: InsightsDimens.kpiGap),
        row(cards[2], cards[3]),
      ],
    );
  }
}
