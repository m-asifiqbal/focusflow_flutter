/// ============================================================
/// MEDICINE VENN CARD — which kinds of days you had
/// ============================================================
///
/// Three overlapping circles — ON TIME, LATE, MISSED/SKIPPED — and in each
/// region the number of days whose doses ended that way (the centre: days
/// with all three), drawn by the shared [InsightsVenn]. Below, the
/// plain-language reading of the biggest numbers.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_no_data.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_venn.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_insight_parts.dart';

class DoseVennCard extends StatelessWidget {
  const DoseVennCard({required this.insights, super.key});

  final MedicineInsights insights;

  @override
  Widget build(BuildContext context) {
    final v = insights.venn;
    final onTime = DoseOutcome.onTime.color(context);
    final late = DoseOutcome.late.color(context);
    final missed = DoseOutcome.missed.color(context);
    return MedicineInsightCard(
      title: tr('Your days at a glance'),
      caption: tr(
        '{count, plural, one {# day with doses} other {# days with doses}}',
        {'count': v.days},
      ),
      child: v.days == 0
          ? InsightsNoData(message: tr('No doses were due in this period.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InsightsVenn(
                  regions: (
                    a: v.onTimeOnly,
                    b: v.lateOnly,
                    c: v.missedOnly,
                    ab: v.onTimeLate,
                    ac: v.onTimeMissed,
                    bc: v.lateMissed,
                    abc: v.all,
                  ),
                  colors: (onTime, late, missed),
                  labels: (
                    DoseOutcome.onTime.label,
                    DoseOutcome.late.label,
                    tr('Missed / skipped'),
                  ),
                  semanticLabel: tr(
                    'Venn diagram of days. {a} days all on time, {b} days with a late dose only, {c} days with a missed or skipped dose only, {d} days with several kinds.',
                    {
                      'a': v.onTimeOnly,
                      'b': v.lateOnly,
                      'c': v.missedOnly,
                      'd': v.onTimeLate + v.onTimeMissed + v.lateMissed + v.all,
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    InsightsFactChip(
                      color: onTime,
                      text: tr(
                        '{count, plural, one {# perfect day} other {# perfect days}}',
                        {'count': v.onTimeOnly},
                      ),
                    ),
                    if (v.lateOnly + v.onTimeLate > 0)
                      InsightsFactChip(
                        color: late,
                        text: tr(
                          '{count, plural, one {# day all taken, some late} other {# days all taken, some late}}',
                          {'count': v.lateOnly + v.onTimeLate},
                        ),
                      ),
                    if (v.missedOnly + v.onTimeMissed + v.lateMissed + v.all >
                        0)
                      InsightsFactChip(
                        color: missed,
                        text: tr(
                          '{count, plural, one {# day with a dose not taken} other {# days with a dose not taken}}',
                          {
                            'count':
                                v.missedOnly +
                                v.onTimeMissed +
                                v.lateMissed +
                                v.all,
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
