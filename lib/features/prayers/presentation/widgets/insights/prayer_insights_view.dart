/// ============================================================
/// PRAYER INSIGHTS VIEW — the "Prayer" tab of Insights
/// ============================================================
///
/// What: Daily · Monthly · Yearly chips, then for that period: KPI tiles
/// (prayed, on time, best streak, complete days), the outcome donut,
/// prayers by day / month, each prayer's record, and the practice card
/// (congregation, fasts, dhikr, places). Not set up yet → "Set up Prayer";
/// nothing marked yet → a pointer to the Prayer page. Every card reveals
/// with the Insights stagger; switching periods keeps the previous one on
/// screen (dimmed) until the next is ready.
/// Why: lives in the prayers feature; the Insights screen only hosts it.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_kpi_card.dart';
import 'package:focusflow/features/insights/presentation/widgets/insights_motion.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_insights.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayer_insights_providers.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/insights/prayer_insight_breakdowns.dart';
import 'package:focusflow/features/prayers/presentation/widgets/insights/prayer_insight_charts.dart';
import 'package:go_router/go_router.dart';

String prayerPeriodLabel(PrayerPeriod p) => switch (p) {
  PrayerPeriod.daily => tr('Daily'),
  PrayerPeriod.monthly => tr('Monthly'),
  PrayerPeriod.yearly => tr('Yearly'),
};

class PrayerInsightsView extends ConsumerStatefulWidget {
  const PrayerInsightsView({super.key});

  @override
  ConsumerState<PrayerInsightsView> createState() => _PrayerInsightsViewState();
}

class _PrayerInsightsViewState extends ConsumerState<PrayerInsightsView> {
  PrayerInsights? _last;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(prayerPeriodProvider);
    final async = ref.watch(prayerInsightsProvider(period));
    final prefs = ref.watch(prayerPrefsProvider);
    final fresh = async.valueOrNull;
    if (fresh != null) _last = fresh;
    final shown = fresh ?? _last;
    final Widget body;
    if (async.hasError && fresh == null) {
      body = FFEmptyState.compact(
        colors: PrayerStyle.module,
        icon: FontAwesomeIcons.chartPie,
        title: tr('Couldn\'t load insights'),
        body: tr('Something went wrong while reading your data.'),
        ctaLabel: tr('Try again'),
        ctaIcon: FontAwesomeIcons.arrowRotateRight,
        onCta: () => ref.invalidate(prayersProvider),
      );
    } else if (shown == null) {
      body = const Padding(
        padding: EdgeInsetsDirectional.only(top: AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    } else if (!shown.hasData) {
      body = prefs.isSetUp
          ? FFEmptyState.compact(
              colors: PrayerStyle.module,
              icon: FontAwesomeIcons.handsPraying,
              title: tr('Nothing to show yet'),
              body: tr(
                'Mark your prayers on the Prayer page — your progress appears here.',
              ),
              ctaLabel: tr('Open Prayer'),
              onCta: () => unawaited(context.push(AppRoutes.prayers)),
            )
          : FFEmptyState.compact(
              colors: PrayerStyle.module,
              icon: FontAwesomeIcons.handsPraying,
              title: tr('Set up Prayer'),
              body: tr(
                'Reminders for each prayer, its time window, and your progress — for any tradition.',
              ),
              ctaLabel: tr('Get started'),
              ctaIcon: FontAwesomeIcons.arrowRight,
              onCta: () => context.push(AppRoutes.prayerSetup),
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
        FFChipBar<PrayerPeriod>(
          items: [
            for (final p in PrayerPeriod.values)
              FFChipItem(value: p, label: prayerPeriodLabel(p)),
          ],
          selected: period,
          onSelected: ref.read(prayerPeriodProvider.notifier).select,
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

  final PrayerInsights insights;

  static KpiDelta? _delta(double? a, double? b) => a == null || b == null
      ? null
      : KpiDelta((a * 100).round() - (b * 100).round(), '%');

  static String _days(num n) =>
      tr('{count, plural, one {# day} other {# days}}', {'count': n.round()});

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
                label: tr('Prayed'),
                value: InsightsFormat.percent(s.counts.completion),
                number: s.counts.completion == null
                    ? null
                    : s.counts.completion! * 100,
                format: (v) => '${v.round()}%',
                delta: _delta(s.counts.completion, s.previous.completion),
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
                label: tr('Best streak'),
                value: _days(s.bestStreak),
                number: s.bestStreak.toDouble(),
                format: _days,
              ),
              InsightsKpiCard(
                label: tr('Complete days'),
                value: '${s.completeDays}/${s.trackedDays}',
              ),
            ],
          ),
        ),
        gap,
        reveal(PrayerOutcomeCard(insights: s)),
        gap,
        reveal(PrayerBarsCard(insights: s)),
        if (s.perPrayer.isNotEmpty) ...[
          gap,
          reveal(PerPrayerCard(insights: s)),
        ],
        if (PrayerPracticeCard.hasData(s)) ...[
          gap,
          reveal(PrayerPracticeCard(insights: s)),
        ],
      ],
    );
  }
}
