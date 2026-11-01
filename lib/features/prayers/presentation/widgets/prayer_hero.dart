/// ============================================================
/// PRAYER HERO — "Now" / "Next" at the top of the Prayer tab
/// ============================================================
///
/// What: the slot PrayerSchedule.focus picks. Open: "Now · ends in 1h 08m",
/// the window, a bar of how much of it has passed and a "Mark prayed"
/// button. Upcoming: "Next · in 1h 12m" and the window. Nothing left
/// today: a calm "All done for today" card.
/// Why: one focal point (the design brief) — everything else on the tab is
/// quieter. Accent gradient, like Home's Today's Focus card, so the two
/// heroes read as one family.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

class PrayerHeroCard extends StatelessWidget {
  const PrayerHeroCard({
    required this.slot,
    required this.now,
    required this.use24h,
    required this.onMark,
    required this.onOpen,
    super.key,
  });

  /// Null = nothing left today.
  final PrayerSlot? slot;
  final DateTime now;
  final bool use24h;
  final VoidCallback onMark;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final s = slot;
    final on = ff.onGradient;
    final soft = on.withValues(alpha: 0.78);
    if (s == null) {
      return FFCard(
        gradient: ff.primaryGradient,
        border: false,
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Row(
          children: [
            Icon(FontAwesomeIcons.solidCircleCheck, color: on, size: 26),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('All done for today'),
                    style: text.cardTitle.copyWith(color: on, fontSize: 18),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    tr('Your next prayer shows here tomorrow.'),
                    style: text.bodySmall.copyWith(color: soft),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final state = s.stateAt(now);
    final open =
        state == PrayerSlotState.open || state == PrayerSlotState.endingSoon;
    final w = s.window;
    final end = w.end;
    final String eyebrow;
    final String timing;
    if (open) {
      eyebrow = tr('Now');
      timing = end == null ? '' : PrayerFormat.endsIn(end.difference(now));
    } else {
      eyebrow = tr('Next');
      timing = PrayerFormat.inTime(w.start.difference(now));
    }
    final length = w.length;
    final passed = length == null || length.inSeconds <= 0
        ? 0.0
        : (now.difference(w.start).inSeconds / length.inSeconds).clamp(
            0.0,
            1.0,
          );
    final details = [
      if (s.prayer.place.trim().isNotEmpty) s.prayer.place.trim(),
      if (s.prayer.priority == PrayerPriority.high) tr('Alarm'),
    ].join(' · ');
    return FFCard(
      gradient: ff.primaryGradient,
      border: false,
      onTap: onOpen,
      semanticLabel: tr('{when}: {name}, {window}. {timing}', {
        'when': eyebrow,
        'name': s.prayer.displayName,
        'window': PrayerFormat.window(w, use24h: use24h),
        'timing': timing,
      }),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: text.meta.copyWith(
                  color: soft,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  timing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.meta.copyWith(
                    color: state == PrayerSlotState.endingSoon ? on : soft,
                    fontWeight: state == PrayerSlotState.endingSoon
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            s.prayer.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.largeTitle.copyWith(color: on, fontSize: 26),
          ),
          Text(
            PrayerFormat.window(w, use24h: use24h),
            style: text.body.copyWith(color: soft),
          ),
          if (open && end != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: passed,
                minHeight: 6,
                color: on,
                backgroundColor: on.withValues(alpha: 0.22),
                semanticsLabel: tr('Time passed in this window'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall.copyWith(color: soft),
                ),
              ),
              if (open)
                FFPressable(
                  onTap: onMark,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.minTap,
                    ),
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      s.prayer.kind.isFast
                          ? tr('Mark fasted')
                          : tr('Mark prayed'),
                      style: text.buttonSmall.copyWith(color: ff.primaryStrong),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
