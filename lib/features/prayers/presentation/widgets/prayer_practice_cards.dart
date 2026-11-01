/// ============================================================
/// PRAYER PRACTICE CARDS — today's fasts and counting practices
/// ============================================================
///
/// What: [PrayerFastCard] — "Fasting · Iftar in 1h 08m", Suhoor → Iftar
/// times, the fast's length and a bar of the day so far; tap = log sheet.
/// [PrayerCounterCard] — a dhikr / rosary / japa counter: a big tap target
/// (+1), −1 to correct, the goal ring; reaching the goal marks it done.
/// Why: a fast and a tally are not "prayed at a time" — they get their own
/// shape instead of a row, below the day's prayers.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';

class PrayerFastCard extends StatelessWidget {
  const PrayerFastCard({
    required this.slot,
    required this.now,
    required this.use24h,
    required this.onTap,
    super.key,
  });

  final PrayerSlot slot;
  final DateTime now;
  final bool use24h;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final p = slot.prayer;
    final w = slot.window;
    final end = w.end ?? w.until;
    final color = PrayerStyle.of(p);
    final state = slot.stateAt(now);
    final status = slot.status;
    final String headline;
    if (status != null) {
      headline = status.labelFor(p.kind);
    } else if (now.isBefore(w.start)) {
      headline = tr('Suhoor ends {when}', {
        'when': PrayerFormat.inTime(w.start.difference(now)),
      });
    } else if (now.isBefore(end)) {
      headline = tr('Iftar {when}', {
        'when': PrayerFormat.inTime(end.difference(now)),
      });
    } else {
      headline = state == PrayerSlotState.missed
          ? tr('Fast over — not marked')
          : tr('Fast over');
    }
    final total = end.difference(w.start).inSeconds;
    final passed = total <= 0
        ? 0.0
        : (now.difference(w.start).inSeconds / total).clamp(0.0, 1.0);
    return FFCard(
      onTap: onTap,
      semanticLabel: '${p.displayName}, $headline',
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FFIconTile.soft(
                icon: FontAwesomeIcons.solidMoon,
                colors: ModuleColorsX.from(color),
                size: AppSizes.iconTileSm,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.rowTitle,
                    ),
                    Text(
                      headline,
                      style: text.bodySmall.copyWith(color: ff.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('Suhoor ends {start} · Iftar {end}', {
                    'start': PrayerFormat.time(w.start, use24h: use24h),
                    'end': PrayerFormat.time(end, use24h: use24h),
                  }),
                  style: text.meta.copyWith(fontWeight: FontWeight.w400),
                ),
              ),
              Text(
                PrayerFormat.duration(end.difference(w.start)),
                style: text.meta,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: passed,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              semanticsLabel: tr('Fast so far'),
            ),
          ),
        ],
      ),
    );
  }
}

class PrayerCounterCard extends StatelessWidget {
  const PrayerCounterCard({
    required this.slot,
    required this.onAdd,
    required this.onUndo,
    required this.onTap,
    super.key,
  });

  final PrayerSlot slot;
  final VoidCallback onAdd;
  final VoidCallback onUndo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final p = slot.prayer;
    final count = slot.log?.count ?? 0;
    final target = p.targetCount;
    final color = PrayerStyle.of(p);
    final progress = target == null || target <= 0
        ? null
        : (count / target).clamp(0.0, 1.0);
    final value = target == null ? '$count' : '$count / $target';
    return FFCard(
      onTap: onTap,
      semanticLabel: tr('{name}: {value}', {
        'name': p.displayName,
        'value': value,
      }),
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Row(
        children: [
          FFProgressRing(
            progress: progress ?? 0,
            size: 56,
            stroke: 5,
            color: color,
            child: Text(
              '$count',
              style: text.stat.copyWith(fontSize: 16, color: ff.ink),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.rowTitle,
                ),
                Text(
                  target == null
                      ? tr('{count} today', {'count': count})
                      : count >= target
                      ? tr('Goal reached · {value}', {'value': value})
                      : tr('{value} today', {'value': value}),
                  style: text.bodySmall.copyWith(color: ff.inkMuted),
                ),
              ],
            ),
          ),
          FFRoundIconButton(
            icon: FontAwesomeIcons.minus,
            semanticLabel: tr('Count one less'),
            onPressed: count > 0 ? onUndo : null,
            iconSize: 14,
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: tr('Count one'),
            excludeSemantics: true,
            child: FFPressable(
              onTap: onAdd,
              scale: 0.9,
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  FontAwesomeIcons.plus,
                  size: 22,
                  color: ff.onGradient,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A module trio from one colour (soft tint / ink) for icon tiles.
abstract final class ModuleColorsX {
  static ModuleColors from(Color c) =>
      ModuleColors(solid: c, soft: c.withValues(alpha: 0.16), ink: _darker(c));
}

Color _darker(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
}
