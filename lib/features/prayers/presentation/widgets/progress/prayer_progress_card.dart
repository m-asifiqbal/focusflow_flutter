/// ============================================================
/// PRAYER PROGRESS CARD — Day · Week · Month · Year (Prayer page)
/// ============================================================
///
/// What: a Day | Week | Month | Year switch over one card:
///   • Day — one day's prayers (‹ › back through the history): what
///     happened to each, when it was marked, in congregation;
///   • Week — the last 7 days as a grid (one row per prayer);
///   • Month — a calendar with a dot per prayer (‹ › 12 months back);
///   • Year — a heatmap of the last 53 weeks and each prayer's record.
/// The card grows / shrinks smoothly between views; the choice and the
/// paging are kept while the app runs (prayer_progress_providers.dart).
/// Why: the Prayer page's progress at every scale without leaving the page
/// — Insights › Prayer has the charts.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/insights_tokens.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_progress_views.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_stats.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayer_progress_providers.dart';
import 'package:focusflow/features/prayers/presentation/widgets/progress/prayer_progress_grids.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class PrayerProgressCard extends ConsumerWidget {
  const PrayerProgressCard({required this.progress, super.key});

  /// The Week view's grid.
  final PrayerProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(prayerProgressViewProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSegmented<PrayerProgressView>(
          segments: [
            FFSegment(value: PrayerProgressView.day, label: tr('Day')),
            FFSegment(value: PrayerProgressView.week, label: tr('Week')),
            FFSegment(value: PrayerProgressView.month, label: tr('Month')),
            FFSegment(value: PrayerProgressView.year, label: tr('Year')),
          ],
          value: view,
          onChanged: ref.read(prayerProgressViewProvider.notifier).select,
        ),
        const SizedBox(height: AppSpacing.md),
        FFCard(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: AnimatedSize(
            duration: context.motion(AppMotion.fast),
            alignment: Alignment.topCenter,
            child: KeyedSubtree(
              key: ValueKey(view),
              child: switch (view) {
                PrayerProgressView.day => const _DayView(),
                PrayerProgressView.week => PrayerWeekGrid(progress: progress),
                PrayerProgressView.month => const PrayerMonthView(),
                PrayerProgressView.year => const PrayerYearView(),
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// A view's title (and summary) with optional ‹ › arrows on the end.
class PrayerViewHeader extends StatelessWidget {
  const PrayerViewHeader({
    required this.title,
    this.summary,
    this.arrows,
    super.key,
  });

  final String title;
  final String? summary;

  /// Back / forward with their labels; null = no arrows.
  final ({
    VoidCallback? back,
    VoidCallback? forward,
    String backLabel,
    String forwardLabel,
  })?
  arrows;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final a = arrows;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: text.cardTitle.copyWith(fontSize: 15),
                ),
              ),
              if (summary != null)
                Text(summary!, style: text.meta.copyWith(color: ff.inkMuted)),
            ],
          ),
        ),
        if (a != null) ...[
          FFRoundIconButton(
            icon: rtl
                ? FontAwesomeIcons.chevronRight
                : FontAwesomeIcons.chevronLeft,
            semanticLabel: a.backLabel,
            onPressed: a.back,
            size: AppSizes.minTap,
            iconSize: 14,
          ),
          const SizedBox(width: AppSpacing.sm),
          FFRoundIconButton(
            icon: rtl
                ? FontAwesomeIcons.chevronLeft
                : FontAwesomeIcons.chevronRight,
            semanticLabel: a.forwardLabel,
            onPressed: a.forward,
            size: AppSizes.minTap,
            iconSize: 14,
          ),
        ],
      ],
    );
  }
}

/// Room for a view while its data loads.
class PrayerViewLoading extends StatelessWidget {
  const PrayerViewLoading({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: InsightsDimens.chartHeight,
    child: Center(child: CircularProgressIndicator.adaptive()),
  );
}

// ──────────────────────────────── Day ────────────────────────────────

class _DayView extends ConsumerWidget {
  const _DayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(prayerDayViewProvider);
    if (data == null) return const PrayerViewLoading();
    final (day, entries) = data;
    final back = ref.watch(prayerDayPageProvider);
    final page = ref.read(prayerDayPageProvider.notifier);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final ff = context.ff;
    // Excused prayers are not due; open ones still are (today).
    final total = entries.where((e) => e.cell != PrayerCell.excused).length;
    final done = entries
        .where((e) => PrayerRate.zero.add(e.cell).done > 0)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrayerViewHeader(
          title: switch (back) {
            0 => tr('Today'),
            -1 => tr('Yesterday'),
            _ => DateFormats.of('EEEE, MMM d').format(day),
          },
          summary: entries.isEmpty
              ? null
              : tr('{done} of {total} prayed', {'done': done, 'total': total}),
          arrows: (
            back: back > page.min ? () => page.step(-1) : null,
            forward: back < 0 ? () => page.step(1) : null,
            backLabel: tr('Previous day'),
            forwardLabel: tr('Next day'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.lg,
            ),
            child: Text(
              tr('No prayers due on this day.'),
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: ff.inkMuted),
            ),
          )
        else
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) Divider(height: AppSpacing.lg, color: ff.divider),
            _DayRow(entry: e, day: day, use24h: use24h),
          ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.entry, required this.day, required this.use24h});

  final PrayerDayEntry entry;
  final DateTime day;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final e = entry;
    final color = e.cell == PrayerCell.pending
        ? ff.inkMuted
        : PrayerStyle.cell(ff, e.cell);
    final status = switch (e.cell) {
      PrayerCell.onTime => tr('On time'),
      PrayerCell.late => tr('Late'),
      PrayerCell.madeUp => tr('Made up'),
      PrayerCell.missed => e.loggedAt == null ? tr('Not marked') : tr('Missed'),
      PrayerCell.excused => tr('Excused'),
      PrayerCell.pending || PrayerCell.none => tr('Not yet'),
    };
    final icon = switch (e.cell) {
      PrayerCell.onTime => FontAwesomeIcons.solidCircleCheck,
      PrayerCell.late => FontAwesomeIcons.clock,
      PrayerCell.madeUp => FontAwesomeIcons.arrowRotateLeft,
      PrayerCell.missed => FontAwesomeIcons.solidCircleXmark,
      PrayerCell.excused => FontAwesomeIcons.circleMinus,
      PrayerCell.pending || PrayerCell.none => FontAwesomeIcons.circle,
    };
    final at = e.loggedAt;
    final marked = at == null
        ? null
        : tr('Marked {time}', {
            'time': DateUtilsX.isSameDay(at, day)
                ? PrayerFormat.time(at, use24h: use24h)
                : '${DateFormats.of('MMM d').format(at)}, '
                      '${PrayerFormat.time(at, use24h: use24h)}',
          });
    final details = [
      status,
      ?marked,
      if (e.congregation) tr('In congregation'),
    ].join(' · ');
    return Semantics(
      label: '${e.prayer.displayName}, $details',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: AppSizes.iconTileSm,
            height: AppSizes.iconTileSm,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.prayer.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.rowTitle.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  details,
                  style: text.bodySmall.copyWith(
                    fontSize: 13,
                    color: ff.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
