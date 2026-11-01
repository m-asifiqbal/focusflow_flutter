/// ============================================================
/// PRAYER PROGRESS — streak, on time, month, week grid (Prayer page)
/// ============================================================
///
/// What: three tiles (streak with the best one, on-time % of the last 30
/// days, this month done / due), the last 7 days as a grid — one row per
/// prayer, one rounded cell per day coloured by what happened (legend
/// below) — and rows for congregation, fasting days and dhikr this month
/// when there is anything to count.
/// Why: progress sits under "today" on the same tab (scroll down), not in
/// a separate screen; encouraging but calm — no confetti, a missed prayer
/// can still be logged as made up.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

class PrayerProgressSection extends StatelessWidget {
  const PrayerProgressSection({required this.progress, super.key});

  final PrayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final rate = p.onTimeRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Tile(
                  label: tr('Streak'),
                  value: tr('{count, plural, one {# day} other {# days}}', {
                    'count': p.streakDays,
                  }),
                  sub: p.bestStreakDays > p.streakDays
                      ? tr('Best {count}', {'count': p.bestStreakDays})
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Tile(
                  label: tr('On time'),
                  value: rate == null ? '—' : '${(rate * 100).round()}%',
                  sub: tr('30 days'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Tile(
                  label: tr('This month'),
                  value: '${p.monthDone}/${p.monthDue}',
                  sub: tr('prayed'),
                ),
              ),
            ],
          ),
        ),
        if (p.week.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          FFCard(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: _WeekGrid(progress: p),
          ),
        ],
        if (p.congregationThisMonth > 0 ||
            p.fastingDaysThisMonth > 0 ||
            p.dhikrThisMonth > 0) ...[
          const SizedBox(height: AppSpacing.md),
          FFGroupedList(
            children: [
              if (p.congregationThisMonth > 0)
                FFListRow(
                  leading: _icon(FontAwesomeIcons.users),
                  title: tr('In congregation'),
                  subtitle: tr('{count} this month', {
                    'count': p.congregationThisMonth,
                  }),
                ),
              if (p.fastingDaysThisMonth > 0)
                FFListRow(
                  leading: _icon(FontAwesomeIcons.solidMoon),
                  title: tr('Fasting days'),
                  subtitle: tr('{count} this month', {
                    'count': p.fastingDaysThisMonth,
                  }),
                ),
              if (p.dhikrThisMonth > 0)
                FFListRow(
                  leading: _icon(FontAwesomeIcons.handsPraying),
                  title: tr('Remembrance (dhikr)'),
                  subtitle: tr('{count} this month', {
                    'count': p.dhikrThisMonth,
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static Widget _icon(IconData icon) => FFIconTile.soft(
    icon: icon,
    colors: PrayerStyle.module,
    size: AppSizes.iconTileSm,
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      semanticLabel: [label, value, ?sub].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.meta.copyWith(color: ff.inkMuted)),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: text.stat.copyWith(fontSize: 20)),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.meta.copyWith(
                color: ff.inkFaint,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.progress});

  final PrayerProgress progress;

  static const double _cell = 14;
  static const double _nameWidth = 72;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final days = progress.weekDays;
    final initials = DateFormats.of('EEEEE');
    Widget cell(PrayerCell c) => Container(
      height: _cell,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: PrayerStyle.cell(ff, c),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Last 7 days'), style: text.cardTitle.copyWith(fontSize: 15)),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const SizedBox(width: _nameWidth),
            for (final d in days)
              Expanded(
                child: Text(
                  initials.format(d),
                  textAlign: TextAlign.center,
                  style: text.meta.copyWith(
                    color: d == days.last ? ff.primary : ff.inkMuted,
                    fontWeight: d == days.last
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final row in progress.week)
          Semantics(
            label: tr('{name}: {done} of {due} days', {
              'name': row.prayer.displayName,
              'done': row.cells
                  .where(
                    (c) =>
                        c == PrayerCell.onTime ||
                        c == PrayerCell.late ||
                        c == PrayerCell.madeUp,
                  )
                  .length,
              'due': row.cells
                  .where((c) => c != PrayerCell.none && c != PrayerCell.pending)
                  .length,
            }),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: _nameWidth,
                    child: Text(
                      row.prayer.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall.copyWith(fontSize: 12.5),
                    ),
                  ),
                  for (final c in row.cells) Expanded(child: cell(c)),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (c, label) in [
              (PrayerCell.onTime, tr('On time')),
              (PrayerCell.late, tr('Late')),
              (PrayerCell.madeUp, tr('Made up')),
              (PrayerCell.missed, tr('Missed')),
              (PrayerCell.excused, tr('Excused')),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: PrayerStyle.cell(ff, c),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(label, style: text.meta.copyWith(color: ff.inkMuted)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
