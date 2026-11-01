/// ============================================================
/// PRAYER PROGRESS — streak, on time, month, Day · Week · Month · Year
/// ============================================================
///
/// What: three tiles (streak with the best one, on-time % of the last 30
/// days, this month done / due), the Day · Week · Month · Year card
/// (progress/prayer_progress_card.dart) and rows for congregation, fasting
/// days and dhikr this month when there is anything to count.
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
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/progress/prayer_progress_card.dart';

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
          PrayerProgressCard(progress: p),
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
