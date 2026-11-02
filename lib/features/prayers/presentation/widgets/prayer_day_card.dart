/// ============================================================
/// PRAYER DAY CARD — today's prayers as one timeline
/// ============================================================
///
/// What: one card, one row per prayer / fast / counting practice, in the
/// order of the day. Each row: the start time (left column), a rail with a
/// status dot (done ✓, missed ✕, open = ringed in the prayer's colour,
/// upcoming = hollow), the name with its type and window, what is left
/// ("Ends in 1h 55m", "Iftar 5:45 PM", "40 / 100 today", the jamaat), and
/// on the end the one action that fits: Mark prayed / Mark fasted while
/// open, +1 for a counter, the result once marked, "in 1h 55m" when ahead.
/// The open prayer's row is tinted. An optional [header] sits on top (Home
/// puts the day's summary there).
/// Why: the whole day at a glance — Home and the Prayer page share it, so
/// a prayer reads the same everywhere. Buttons use the 12 pt rounded
/// rectangle, not a pill.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/tradition_profile.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/prayers/presentation/widgets/prayer_day_parts.dart';

class PrayerDayCard extends StatelessWidget {
  const PrayerDayCard({
    required this.slots,
    required this.now,
    required this.use24h,
    required this.onMark,
    required this.onTap,
    this.onCount,
    this.header,
    this.markInRow = true,
    super.key,
  });

  final List<PrayerSlot> slots;
  final DateTime now;
  final bool use24h;
  final ValueChanged<PrayerSlot> onMark;
  final ValueChanged<PrayerSlot> onTap;

  /// +1 on a counting practice (null hides the button).
  final ValueChanged<PrayerSlot>? onCount;
  final Widget? header;

  /// The open prayer's row carries Mark prayed (Home); false shows "Now"
  /// instead (the Prayer page, whose hero card has the button).
  final bool markInRow;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: header,
            ),
            Divider(height: 1, color: ff.divider),
            const SizedBox(height: AppSpacing.xs),
          ],
          for (final (i, s) in slots.indexed)
            _Row(
              slot: s,
              now: now,
              use24h: use24h,
              first: i == 0,
              last: i == slots.length - 1,
              onMark: () => onMark(s),
              onTap: () => onTap(s),
              onCount: onCount == null ? null : () => onCount!(s),
              markInRow: markInRow,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.slot,
    required this.now,
    required this.use24h,
    required this.first,
    required this.last,
    required this.onMark,
    required this.onTap,
    required this.onCount,
    required this.markInRow,
  });

  final PrayerSlot slot;
  final DateTime now;
  final bool use24h;
  final bool first;
  final bool last;
  final VoidCallback onMark;
  final VoidCallback onTap;
  final VoidCallback? onCount;
  final bool markInRow;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final p = slot.prayer;
    final w = slot.window;
    final state = slot.stateAt(now);
    final status = slot.status;
    final open =
        state == PrayerSlotState.open || state == PrayerSlotState.endingSoon;
    final color = PrayerStyle.of(p);
    final counts = p.kind.counts;
    final fast = p.kind.isFast;

    // Line 2: what it is and when.
    final profile = PrayerTraditionProfile.of(p.tradition);
    final details = [
      profile.kindShort(p.kind),
      if (fast)
        profile.fast.endsWhen(
          PrayerFormat.time(w.end ?? w.until, use24h: use24h),
        )
      else if (w.end != null)
        tr('until {time}', {'time': PrayerFormat.time(w.end!, use24h: use24h)}),
    ].join(' · ');

    // Line 3: what is left.
    final count = slot.log?.count ?? 0;
    final goal = p.targetCount;
    final String? left = switch (state) {
      _ when counts =>
        goal == null
            ? tr('{count} today', {'count': count})
            : tr('{count} / {goal} today', {'count': count, 'goal': goal}),
      PrayerSlotState.open || PrayerSlotState.endingSoon when w.end != null =>
        fast
            ? profile.fast.endsWhen(PrayerFormat.inTime(w.end!.difference(now)))
            : PrayerFormat.endsIn(w.end!.difference(now)),
      _ => null,
    };
    final jamaat = counts || fast
        ? null
        : PrayerFormat.jamaat(slot, now, use24h: use24h);

    final mark = markInRow && open && status == null && !counts
        ? PrayerMarkButton(
            label: profile.markLabel(p.kind),
            color: color,
            onTap: onMark,
          )
        : null;
    // Only the prayer that is on now is tinted (not a counter beside it).
    final current = open && !counts;

    final Widget trailing;
    if (counts && onCount != null) {
      trailing = PrayerSquareButton(
        icon: FontAwesomeIcons.plus,
        label: tr('Add one to {name}', {'name': p.displayName}),
        color: color,
        onTap: onCount!,
      );
    } else if (mark != null) {
      trailing = const SizedBox.shrink();
    } else if (current && status == null) {
      trailing = PrayerResultLabel(
        label: tr('Now'),
        color: color,
        icon: FontAwesomeIcons.solidCircleDot,
      );
    } else if (status != null) {
      trailing = PrayerResultLabel(
        label: status.labelFor(p.kind),
        color: PrayerStyle.state(ff, state),
        icon: status.done
            ? FontAwesomeIcons.solidCircleCheck
            : status == PrayerStatus.excused
            ? FontAwesomeIcons.circleMinus
            : FontAwesomeIcons.solidCircleXmark,
      );
    } else if (state == PrayerSlotState.missed) {
      trailing = PrayerResultLabel(
        label: tr('Not marked'),
        color: ff.danger,
        icon: FontAwesomeIcons.circleExclamation,
      );
    } else if (state == PrayerSlotState.upcoming) {
      trailing = Text(
        PrayerFormat.inTime(w.start.difference(now)),
        style: text.meta.copyWith(color: ff.inkMuted),
      );
    } else {
      trailing = const SizedBox.shrink();
    }

    final timeStyle = text.rowTitle.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: current ? ff.ink : ff.inkMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final hour = DateFormats.of(use24h ? 'HH:mm' : 'h:mm').format(w.start);
    final meridiem = use24h ? null : DateFormats.of('a').format(w.start);

    final label = [
      p.displayName,
      details,
      ?left,
      ?jamaat,
      if (status != null) status.labelFor(p.kind),
      if (status == null && state == PrayerSlotState.upcoming)
        PrayerFormat.inTime(w.start.difference(now)),
    ].join(', ');
    // The text reads as one button (tap = log sheet); the time and the rail
    // are decoration; Mark / +1 stay their own buttons.
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.rowTitle.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          details,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall.copyWith(fontSize: 13, color: ff.inkMuted),
        ),
        if (left != null) ...[
          const SizedBox(height: 2),
          Text(
            left,
            style: text.bodySmall.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: state == PrayerSlotState.endingSoon ? ff.warning : color,
            ),
          ),
        ],
        if (counts && goal != null && goal > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: (count / goal).clamp(0.0, 1.0),
              minHeight: 4,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
        if (jamaat != null) ...[
          const SizedBox(height: 2),
          Text(
            jamaat,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PrayerStyle.module.inkFor(ff.brightness),
            ),
          ),
        ],
      ],
    );
    return FFPressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: current ? color.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: PrayerStyle.timeColumn,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hour, style: timeStyle),
                        if (meridiem != null)
                          Text(
                            meridiem,
                            style: text.meta.copyWith(color: ff.inkFaint),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: PrayerRail(
                  state: state,
                  color: color,
                  first: first,
                  last: last,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        button: true,
                        label: label,
                        onTap: onTap,
                        excludeSemantics: true,
                        child: texts,
                      ),
                      if (mark != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        mark,
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Center(child: trailing),
            ],
          ),
        ),
      ),
    );
  }
}
