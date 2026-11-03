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
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/providers/home_providers.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_link.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
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
    // The week strip's day: today shows the live plan, a past day what was
    // marked, a future day what is coming.
    final day = ref.watch(homeDayProvider);
    final isToday = DateUtilsX.isSameDay(day, ref.watch(todayProvider));
    void openAll() => unawaited(context.push(AppRoutes.prayers));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: tr('Prayer'),
          trailing: HomeSectionLink(tr('All'), onPressed: openAll),
        ),
        const SizedBox(height: HomeDimens.linkHeaderGap),
        if (isToday)
          _TodayCard(onOpenAll: openAll)
        else
          _OtherDayCard(day: day, onOpenAll: openAll),
      ],
    );
  }
}

/// Today: done ring, what is on now / next, every prayer with its actions.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.onOpenAll});

  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(prayerTodayProvider);
    final hijri = ref.watch(prayerDateLineProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    return today.when(
      skipLoadingOnReload: true,
      error: (_, _) =>
          HomeErrorCard(onRetry: () => ref.invalidate(prayersProvider)),
      loading: () => const FFSkeletonList(count: 1),
      data: (d) {
        final summary = PrayerDaySummary(today: d, hijri: hijri);
        if (d.slots.isEmpty) {
          return FFCard(onTap: onOpenAll, child: summary);
        }
        return PrayerDayCard(
          header: summary,
          slots: d.slots,
          now: d.now,
          use24h: use24h,
          onMark: (s) => unawaited(markPrayer(context, ref, s)),
          onCount: (s) => unawaited(countPrayer(ref, s, 1)),
          onTap: (s) => _open(context, ref, s),
        );
      },
    );
  }
}

/// Another day of the week strip. A past day lists what was prayed (and what
/// has no record); a future day lists the schedule to come. Nothing is
/// markable here except through a row's log sheet.
class _OtherDayCard extends ConsumerWidget {
  const _OtherDayCard({required this.day, required this.onOpenAll});

  final DateTime day;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(prayerDayPlanProvider(day));
    final now = ref.watch(prayerNowProvider);
    final hijri = ref.watch(prayerDateLineOnProvider(day));
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    return plan.when(
      skipLoadingOnReload: true,
      error: (_, _) =>
          HomeErrorCard(onRetry: () => ref.invalidate(prayersProvider)),
      loading: () => const FFSkeletonList(count: 1),
      data: (plan) {
        // Counting practices are a "today" tally: left out of other days.
        final slots = [
          for (final s in plan)
            if (!s.prayer.kind.counts) s,
        ];
        final summary = PrayerOtherDaySummary(
          day: day,
          slots: slots,
          now: now,
          hijri: hijri,
        );
        if (slots.isEmpty) return FFCard(onTap: onOpenAll, child: summary);
        return PrayerDayCard(
          header: summary,
          slots: slots,
          now: now,
          use24h: use24h,
          onMark: (s) => unawaited(markPrayer(context, ref, s)),
          onTap: (s) => _open(context, ref, s),
        );
      },
    );
  }
}

/// A row's tap: a counter opens its editor, anything else its log sheet.
void _open(BuildContext context, WidgetRef ref, PrayerSlot s) =>
    s.prayer.kind.counts
    ? unawaited(context.push(AppRoutes.prayerEdit(s.prayer.id)))
    : unawaited(openPrayerLog(context, ref, s));

/// The day's summary: done ring, now / next, the Hijri date.
class PrayerDaySummary extends StatelessWidget {
  const PrayerDaySummary({required this.today, this.hijri, super.key});

  final PrayerToday today;
  final String? hijri;

  @override
  Widget build(BuildContext context) {
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
    return _SummaryRow(
      done: done,
      total: total,
      headline: headline,
      line: line,
      hijri: hijri,
      doneToday: true,
    );
  }
}

/// The summary of a past or future day: how many were prayed (past), or what
/// is scheduled (future), with the day's date.
class PrayerOtherDaySummary extends StatelessWidget {
  const PrayerOtherDaySummary({
    required this.day,
    required this.slots,
    required this.now,
    this.hijri,
    super.key,
  });

  final DateTime day;
  final List<PrayerSlot> slots;
  final DateTime now;
  final String? hijri;

  @override
  Widget build(BuildContext context) {
    final prayers = [
      for (final s in slots)
        if (!s.prayer.kind.isFast && !s.prayer.kind.counts) s,
    ];
    final done = prayers
        .where((s) => s.stateAt(now) == PrayerSlotState.done)
        .length;
    final future = day.isAfter(DateUtilsX.dateOnly(now));
    final headline = switch (prayers.length) {
      0 => tr('No prayers due on this day.'),
      _ when future => tr('Upcoming'),
      _ when done == 0 => tr('Not marked'),
      final total => tr('{done} of {total} prayed', {
        'done': done,
        'total': total,
      }),
    };
    return _SummaryRow(
      done: done,
      total: prayers.length,
      headline: headline,
      line: DateFormats.of('EEEE, MMM d').format(day),
      hijri: hijri,
    );
  }
}

/// Ring · headline · line · date, shared by today's and other days' summary.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.done,
    required this.total,
    required this.headline,
    required this.line,
    required this.hijri,
    this.doneToday = false,
  });

  final int done;
  final int total;
  final String headline;
  final String? line;
  final String? hijri;

  /// Today's summary reads "x of y done today"; another day's headline
  /// already says what the ring means.
  final bool doneToday;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final accent = PrayerStyle.module.inkFor(ff.brightness);
    return Semantics(
      label: [
        if (doneToday)
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
                    line!,
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
