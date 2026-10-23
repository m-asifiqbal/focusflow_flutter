/// ============================================================
/// MEDICINE TODAY CARD — "Today's doses · 2 of 4 taken" hero
/// ============================================================
///
/// The accent-gradient hero of the medicine list (and the Reminders
/// "Medicine" chip): how many of the day's scheduled doses are taken, the
/// next one, a progress bar and a ring. The ring, the bar and the
/// percentage count animate to their new values when a dose is logged (a
/// small reward for taking it); with reduce motion they jump.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';

class MedicineTodayCard extends StatelessWidget {
  const MedicineTodayCard({
    required this.day,
    required this.slots,
    required this.now,
    this.use24h = false,
    super.key,
  });

  final DateTime day;

  /// The day's scheduled doses.
  final List<DoseSlot> slots;
  final DateTime now;
  final bool use24h;

  static const Color _on = AppPalette.white;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final total = slots.length;
    final taken = slots.where((s) => s.stateAt(now) == DoseState.taken).length;
    final progress = total == 0 ? 0.0 : taken / total;
    final isToday = DateUtilsX.isSameDay(day, now);
    final next = isToday
        ? slots.where((s) => !s.stateAt(now).isLogged).firstOrNull
        : null;
    final duration = context.reduceMotion ? Duration.zero : AppMotion.slow * 3;
    final title = isToday
        ? tr('Today\'s doses')
        : tr('Doses · {day}', {'day': DateUtilsX.relativeDay(day, now)});
    final String subtitle;
    if (total == 0) {
      subtitle = tr('Nothing scheduled');
    } else if (taken == total) {
      subtitle = tr('All done — nicely done!');
    } else if (next != null) {
      final name = next.medicine.name.trim();
      subtitle = tr('Next: {name} at {time}', {
        'name': name,
        'time': DateUtilsX.time(next.at, use24h: use24h),
      });
    } else {
      subtitle = tr('{count, plural, one {# dose left} other {# doses left}}', {
        'count': total - taken,
      });
    }
    return Semantics(
      container: true,
      label:
          '$title. ${tr('{taken} of {total} taken', {'taken': taken, 'total': total})}. $subtitle',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            gradient: ff.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadii.hero),
            boxShadow: ff.heroShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.sectionLabel.copyWith(
                        color: _on.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      tr('{taken} of {total} taken', {
                        'taken': taken,
                        'total': total,
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.title.copyWith(color: _on),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    AnimatedSwitcher(
                      duration: context.reduceMotion
                          ? Duration.zero
                          : AppMotion.normal,
                      child: Text(
                        subtitle,
                        key: ValueKey(subtitle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall.copyWith(
                          color: _on.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Bar(progress: progress, duration: duration),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              FFProgressRing(
                progress: progress,
                size: MedicineSizes.heroRing,
                stroke: MedicineSizes.heroStroke,
                color: _on,
                trackColor: _on.withValues(alpha: 0.25),
                duration: duration,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress * 100),
                  duration: duration,
                  curve: AppMotion.curve,
                  builder: (context, v, _) => Text(
                    '${v.round()}%',
                    style: text.stat.copyWith(color: _on),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.progress, required this.duration});

  final double progress;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    const on = MedicineTodayCard._on;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: MedicineSizes.progressBar,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: on.withValues(alpha: 0.25)),
            ),
            AnimatedFractionallySizedBox(
              duration: duration,
              curve: AppMotion.curve,
              widthFactor: progress.clamp(0, 1),
              heightFactor: 1,
              alignment: AlignmentDirectional.centerStart,
              child: const ColoredBox(color: on),
            ),
          ],
        ),
      ),
    );
  }
}
