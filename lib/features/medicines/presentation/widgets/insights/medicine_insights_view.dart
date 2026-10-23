/// ============================================================
/// MEDICINE INSIGHTS VIEW — the "Medicine" tab of Insights
/// ============================================================
///
/// What: Daily · Monthly · Yearly chips, then for that period: KPI tiles
/// (adherence, doses taken, on time, best run), the dose outcome donut, the
/// stacked bars per day / month, the adherence trend line, the Venn of
/// days, when doses are taken (time of day) and adherence per medicine.
/// Every card reveals with the Insights stagger; switching periods keeps
/// the previous one on screen (dimmed) until the next is ready.
/// Why: lives in the medicines feature; the Insights screen only hosts it.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_kpi_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_motion.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/medicines/presentation/providers/medicine_insights_providers.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_chart_cards.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_breakdown_cards.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_venn_card.dart';
import 'package:go_router/go_router.dart';

String medicinePeriodLabel(MedicinePeriod p) => switch (p) {
  MedicinePeriod.daily => tr('Daily'),
  MedicinePeriod.monthly => tr('Monthly'),
  MedicinePeriod.yearly => tr('Yearly'),
};

class MedicineInsightsView extends ConsumerStatefulWidget {
  const MedicineInsightsView({super.key});

  @override
  ConsumerState<MedicineInsightsView> createState() =>
      _MedicineInsightsViewState();
}

class _MedicineInsightsViewState extends ConsumerState<MedicineInsightsView> {
  MedicineInsights? _last;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(medicinePeriodProvider);
    final async = ref.watch(medicineInsightsProvider(period));
    final fresh = async.valueOrNull;
    if (fresh != null) _last = fresh;
    final shown = fresh ?? _last;
    final Widget body;
    if (async.hasError && fresh == null) {
      body = FFEmptyState.compact(
        colors: ModuleStyle.medicines.colors,
        icon: FontAwesomeIcons.chartPie,
        title: tr('Couldn\'t load insights'),
        body: tr('Something went wrong while reading your data.'),
        ctaLabel: tr('Try again'),
        ctaIcon: FontAwesomeIcons.arrowRotateRight,
        onCta: () => ref.invalidate(medicineInsightsProvider(period)),
      );
    } else if (shown == null) {
      body = const Padding(
        padding: EdgeInsetsDirectional.only(top: AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    } else if (!shown.hasData) {
      body = FFEmptyState.compact(
        colors: ModuleStyle.medicines.colors,
        icon: ModuleStyle.medicines.icon,
        title: tr('No doses yet'),
        body: tr(
          'Add a medicine and log your doses — your adherence charts appear here.',
        ),
        ctaLabel: tr('Add medicine'),
        onCta: () => context.push(AppRoutes.newMedicinePath),
      );
    } else {
      body = AnimatedOpacity(
        opacity: fresh == null ? InsightsDimens.staleOpacity : 1,
        duration: context.motion(AppMotion.fast),
        child: _Content(insights: shown),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFChipBar<MedicinePeriod>(
          items: [
            for (final p in MedicinePeriod.values)
              FFChipItem(value: p, label: medicinePeriodLabel(p)),
          ],
          selected: period,
          onSelected: ref.read(medicinePeriodProvider.notifier).select,
        ),
        const SizedBox(height: InsightsDimens.chipsGap),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          child: body,
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.insights});

  final MedicineInsights insights;

  static KpiDelta? _delta(double? a, double? b) => a == null || b == null
      ? null
      : KpiDelta((a * 100).round() - (b * 100).round(), '%');

  @override
  Widget build(BuildContext context) {
    final s = insights;
    const gap = SizedBox(height: AppSpacing.section);
    var i = 0;
    Widget reveal(Widget child) => InsightsReveal(index: i++, child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        reveal(
          InsightsKpiGrid(
            cards: [
              InsightsKpiCard(
                label: tr('Adherence'),
                value: InsightsFormat.percent(s.counts.adherence),
                number: s.counts.adherence == null
                    ? null
                    : s.counts.adherence! * 100,
                format: (v) => '${v.round()}%',
                delta: _delta(s.counts.adherence, s.previous.adherence),
              ),
              InsightsKpiCard(
                label: tr('Doses taken'),
                value: '${s.counts.taken}',
                number: s.counts.taken.toDouble(),
                format: (v) => '${v.round()}',
                delta: s.previous.isEmpty
                    ? null
                    : KpiDelta(s.counts.taken - s.previous.taken, ''),
              ),
              InsightsKpiCard(
                label: tr('On time'),
                value: InsightsFormat.percent(s.counts.onTimeRate),
                number: s.counts.onTimeRate == null
                    ? null
                    : s.counts.onTimeRate! * 100,
                format: (v) => '${v.round()}%',
                delta: _delta(s.counts.onTimeRate, s.previous.onTimeRate),
              ),
              InsightsKpiCard(
                label: tr('Best run'),
                value: tr('{count, plural, one {# day} other {# days}}', {
                  'count': s.bestStreak,
                }),
                number: s.bestStreak.toDouble(),
                format: (v) => tr(
                  '{count, plural, one {# day} other {# days}}',
                  {'count': v.round()},
                ),
              ),
            ],
          ),
        ),
        gap,
        reveal(DoseOutcomeCard(insights: s)),
        gap,
        reveal(DoseBarsCard(insights: s)),
        gap,
        reveal(AdherenceTrendCard(insights: s)),
        gap,
        reveal(DoseVennCard(insights: s)),
        gap,
        reveal(TimeOfDayCard(insights: s)),
        if (s.perMedicine.isNotEmpty) ...[
          gap,
          reveal(PerMedicineCard(insights: s)),
        ],
        if (s.asNeededTaken > 0) ...[
          gap,
          reveal(
            FFInfoBanner(
              icon: ModuleStyle.medicines.icon,
              colors: ModuleStyle.medicines.colors,
              text: tr(
                '{count, plural, one {# as-needed dose logged} other {# as-needed doses logged}} in this period (not counted in adherence).',
                {'count': s.asNeededTaken},
              ),
            ),
          ),
        ],
      ],
    );
  }
}
