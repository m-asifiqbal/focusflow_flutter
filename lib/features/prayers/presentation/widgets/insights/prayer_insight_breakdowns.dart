/// ============================================================
/// PRAYER INSIGHT BREAKDOWNS — by prayer, and practice details
/// ============================================================
///
/// * [PerPrayerCard] — each prayer in the order of the day: how many of its
///   due days were prayed (bar in the prayer's own colour), on time / late
///   / missed; tap opens the prayer.
/// * [PrayerPracticeCard] — the rest of the practice in the period:
///   prayers in congregation, fasts kept, the dhikr tally (and the days its
///   goal was reached) and where prayers were prayed. Rows without data are
///   left out; the card is skipped when none have any.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/presentation/widgets/insights/medicine_insight_parts.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_insights.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:go_router/go_router.dart';

class PerPrayerCard extends StatelessWidget {
  const PerPrayerCard({required this.insights, super.key});

  final PrayerInsights insights;

  @override
  Widget build(BuildContext context) => MedicineInsightCard(
    title: tr('By prayer'),
    caption: tr('How often each prayer was prayed'),
    child: Column(
      children: [
        for (final (i, share) in insights.perPrayer.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _PrayerRow(share: share),
        ],
      ],
    ),
  );
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({required this.share});

  final PrayerShare share;

  @override
  Widget build(BuildContext context) {
    final p = share.prayer;
    final c = share.counts;
    final rate = c.completion ?? 0;
    final color = PrayerStyle.of(p);
    final percent = '${(rate * 100).round()}%';
    return Semantics(
      button: true,
      label: tr('{name}: {percent} prayed, {done} of {total}', {
        'name': p.displayName,
        'percent': percent,
        'done': c.done,
        'total': c.due,
      }),
      excludeSemantics: true,
      child: FFPressable(
        onTap: () => context.push(AppRoutes.prayerEdit(p.id)),
        child: Row(
          children: [
            Container(
              width: PrayerStyle.rowAccent,
              height: AppSizes.iconTileSm,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.rowTitle,
                        ),
                      ),
                      Text(
                        percent,
                        style: context.text.rowTitle.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: SizedBox(
                      height: PrayerStyle.progressBar,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: color.withValues(alpha: 0.15),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: rate),
                            duration: context.motion(AppMotion.slow * 3),
                            curve: AppMotion.curve,
                            builder: (_, v, _) => FractionallySizedBox(
                              widthFactor: v.clamp(0, 1),
                              heightFactor: 1,
                              alignment: AlignmentDirectional.centerStart,
                              child: ColoredBox(color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      tr('{done} of {total} prayed', {
                        'done': c.done,
                        'total': c.due,
                      }),
                      if (c.onTime > 0) tr('{n} on time', {'n': c.onTime}),
                      if (c.late > 0) tr('{n} late', {'n': c.late}),
                      if (c.missed > 0) tr('{n} missed', {'n': c.missed}),
                    ].join(' · '),
                    style: context.text.caption,
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

class PrayerPracticeCard extends StatelessWidget {
  const PrayerPracticeCard({required this.insights, super.key});

  final PrayerInsights insights;

  /// Whether the card has anything to show.
  static bool hasData(PrayerInsights s) =>
      s.congregation > 0 ||
      s.fastsDue > 0 ||
      s.dhikrTotal > 0 ||
      s.places.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = insights;
    final rows = <Widget>[
      if (s.congregation > 0)
        _row(
          context,
          FontAwesomeIcons.users,
          tr('In congregation'),
          tr('{count, plural, one {# prayer} other {# prayers}}', {
            'count': s.congregation,
          }),
        ),
      if (s.fastsDue > 0)
        _row(
          context,
          FontAwesomeIcons.solidMoon,
          tr('Fasts kept'),
          tr('{kept} of {due}', {'kept': s.fastsKept, 'due': s.fastsDue}),
        ),
      if (s.dhikrTotal > 0)
        _row(
          context,
          FontAwesomeIcons.handsPraying,
          tr('Remembrance (dhikr)'),
          '${s.dhikrTotal}',
          sub: s.dhikrGoalDays > 0
              ? tr(
                  '{count, plural, one {Goal reached on # day} other {Goal reached on # days}}',
                  {'count': s.dhikrGoalDays},
                )
              : null,
        ),
    ];
    return MedicineInsightCard(
      title: tr('Your practice'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            r,
          ],
          if (s.places.isNotEmpty) ...[
            if (rows.isNotEmpty) const SizedBox(height: AppSpacing.lg),
            Text(tr('Where you prayed'), style: context.text.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            for (final (place, n) in s.places)
              InsightLegendRow(
                color: PrayerStyle.module.solid,
                label: place,
                value: '$n',
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    String? sub,
  }) => Semantics(
    label: sub == null ? '$title, $value' : '$title, $value, $sub',
    excludeSemantics: true,
    child: Row(
      children: [
        FFIconTile.soft(
          icon: icon,
          colors: PrayerStyle.module,
          size: AppSizes.iconTileSm,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.rowTitle),
              if (sub != null) Text(sub, style: context.text.caption),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: context.text.rowTitle.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
