/// ============================================================
/// HABITS HERO — "Keep the chain going!" card (mockup 14)
/// ============================================================
///
/// Indigo → violet gradient, a white 72-pt ring with today's completion
/// ("40%"), the headline and "Longest active streak: **45 days** ·
/// Reading". The headline turns into "Perfect day!" once every habit due
/// today is done, and "Rest day" when nothing is due.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/features/habits/domain/services/habits_day_summary.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/core/widgets/ff_progress_ring.dart';

class HabitsHeroCard extends StatelessWidget {
  const HabitsHeroCard({required this.summary, super.key});

  final HabitsDaySummary summary;

  /// The headline for [s].
  static String headline(HabitsDaySummary s) {
    if (s.isPerfect) return 'Perfect day!';
    if (s.due == 0) return s.total == 0 ? 'Start a chain' : 'Rest day';
    return 'Keep the chain going!';
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    const on = HabitAccents.onColor;
    final percent = (summary.progress * 100).round();
    final longest = summary.longest;
    final soft = text.body.copyWith(
      fontSize: HabitDimens.heroSubtitle,
      height: 1.45,
      color: on.withValues(alpha: 0.78),
    );

    return Semantics(
      container: true,
      label:
          '${headline(summary)} ${summary.done} of ${summary.due} done today',
      child: Container(
        padding: const EdgeInsetsDirectional.all(HabitDimens.heroPadding),
        decoration: BoxDecoration(
          gradient: HabitAccents.heroGradient(),
          borderRadius: BorderRadius.circular(AppRadii.hero),
          boxShadow: HabitAccents.heroShadow(dark: context.isDark),
        ),
        child: Row(
          children: [
            FFProgressRing(
              progress: summary.progress,
              size: HabitDimens.heroRing,
              stroke: HabitDimens.heroRingStroke,
              color: on,
              trackColor: HabitAccents.heroTrack(),
              child: ExcludeSemantics(
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      '$percent%',
                      style: text.stat.copyWith(
                        fontSize: HabitDimens.heroPercent,
                        color: on,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headline(summary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.sectionTitle.copyWith(
                        fontSize: HabitDimens.heroTitle,
                        color: on,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                    Text.rich(
                      longest == null
                          ? const TextSpan(
                              text: 'Check in today to start a streak',
                            )
                          : TextSpan(
                              children: [
                                const TextSpan(text: 'Longest active streak: '),
                                TextSpan(
                                  text: longest.streak.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(text: ' · ${longest.habit.name}'),
                              ],
                            ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: soft,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
