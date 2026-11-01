/// ============================================================
/// HOME PRAYER SECTION — "Prayer ……… All": the whole day at a glance
/// ============================================================
///
/// What: one card. On top, the day's summary: a ring of prayers done
/// ("2/5"), what is on now or next ("Asr now · Ends in 1h 55m", "Next:
/// Maghrib · Starts in 1h 55m", "All prayers done today") and the Hijri
/// date. Below it, every prayer, fast and practice of today as the Prayer
/// page's timeline (PrayerDayCard): start time, status dot, type and
/// window, what is left, the jamaat, and Mark prayed / +1 where it fits.
/// Tapping a row opens its log sheet (a counter opens its editor); All
/// opens the Prayer page. Home shows this section only to someone who has
/// prayers (home_screen.dart).
/// Why: the user wants every prayer of the day on Home, not just the next
/// one — the same flows as the Prayer page (prayer_flows.dart), so a mark
/// here updates the page, the notifications and the progress.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_link.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_flows.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_day_card.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Whether the user has any active prayer (Home shows the section).
final homeHasPrayersProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(
    prayersProvider.select((p) => p.valueOrNull?.isNotEmpty ?? false),
  ),
);

class HomePrayerSection extends ConsumerWidget {
  const HomePrayerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(prayerTodayProvider);
    final hijri = ref.watch(prayerHijriProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    void openAll() => unawaited(context.push(AppRoutes.prayers));
    final Widget body = today.when(
      skipLoadingOnReload: true,
      error: (_, _) =>
          HomeErrorCard(onRetry: () => ref.invalidate(prayersProvider)),
      loading: () => const FFSkeletonList(count: 1),
      data: (d) {
        final summary = PrayerDaySummary(today: d, hijri: hijri);
        if (d.slots.isEmpty) {
          return FFCard(onTap: openAll, child: summary);
        }
        return PrayerDayCard(
          header: summary,
          slots: d.slots,
          now: d.now,
          use24h: use24h,
          onMark: (s) => unawaited(markPrayer(context, ref, s)),
          onCount: (s) => unawaited(countPrayer(ref, s, 1)),
          onTap: (s) => s.prayer.kind.counts
              ? unawaited(context.push(AppRoutes.prayerEdit(s.prayer.id)))
              : unawaited(openPrayerLog(context, ref, s)),
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: tr('Prayer'),
          trailing: HomeSectionLink(tr('All'), onPressed: openAll),
        ),
        const SizedBox(height: HomeDimens.linkHeaderGap),
        body,
      ],
    );
  }
}

/// The day's summary: done ring, now / next, the Hijri date.
class PrayerDaySummary extends StatelessWidget {
  const PrayerDaySummary({required this.today, this.hijri, super.key});

  final PrayerToday today;
  final String? hijri;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final now = today.now;
    final prayers = today.prayers;
    final done = prayers
        .where((s) => s.stateAt(now) == PrayerSlotState.done)
        .length;
    final total = prayers.length;
    final focus = today.focus;
    final (String headline, String? line) = switch (focus) {
      null when total == 0 => (tr('Nothing due today'), null),
      null when done == total => (tr('All prayers done today'), null),
      null => (tr('No more prayers today'), null),
      final f when f.stateAt(now) == PrayerSlotState.upcoming => (
        tr('Next: {name}', {'name': f.prayer.displayName}),
        tr('Starts {when}', {
          'when': PrayerFormat.inTime(f.window.start.difference(now)),
        }),
      ),
      final f => (
        tr('{name} now', {'name': f.prayer.displayName}),
        f.window.end == null
            ? null
            : PrayerFormat.endsIn(f.window.end!.difference(now)),
      ),
    };
    final accent = PrayerStyle.module.inkFor(ff.brightness);
    return Semantics(
      label: [
        tr('{done} of {total} done today', {'done': done, 'total': total}),
        headline,
        ?line,
        ?hijri,
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        children: [
          FFProgressRing(
            progress: total == 0 ? 0 : done / total,
            size: PrayerStyle.summaryRing,
            stroke: 5,
            color: PrayerStyle.module.solid,
            child: Text(
              '$done/$total',
              style: text.rowTitle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.cardTitle,
                ),
                if (line != null)
                  Text(
                    line,
                    style: text.bodySmall.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (hijri != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.solidMoon,
                        size: 10,
                        color: ff.inkFaint,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          hijri!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.meta.copyWith(color: ff.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
