/// ============================================================
/// HOME FOCUS CARD — "Today's Focus" hero (mockup 03, keeps its gradient
/// in dark mode, 37)
/// ============================================================
///
/// What: accent gradient card (radius 28) with a decorative white circle
/// top-right, the title + encouragement line, the "57%" pill, a white
/// progress bar and three glass stat tiles (Tasks 4/7 · Habits 2/4 ·
/// Reminders 3). Tiles open the matching list.
/// Why: pure presentation over [HomeFocus]; the bar animates unless the
/// user asked to reduce motion.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/domain/services/home_focus.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:go_router/go_router.dart';

class HomeFocusCard extends StatelessWidget {
  const HomeFocusCard({required this.focus, super.key});

  final HomeFocus focus;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const on = HomeColors.onHero;
    final text = context.text;

    return Semantics(
      container: true,
      label:
          "Today's focus, ${focus.percent} percent. "
          '${focus.tasksDone} of ${focus.tasksTarget} tasks, '
          '${focus.habitsDone} of ${focus.habitsDue} habits, '
          '${focus.remindersLeft} reminders left',
      child: Container(
        decoration: BoxDecoration(
          gradient: ff.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadii.hero),
          boxShadow: ff.heroShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            PositionedDirectional(
              top: HomeDimens.heroCircleOffset,
              end: HomeDimens.heroCircleOffset,
              child: ExcludeSemantics(
                child: Container(
                  width: HomeDimens.heroCircle,
                  height: HomeDimens.heroCircle,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                HomeDimens.heroPadding,
                HomeDimens.heroPaddingTop,
                HomeDimens.heroPadding,
                HomeDimens.heroPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's Focus",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.title.copyWith(
                                  fontSize: HomeDimens.heroTitle,
                                  fontWeight: FontWeight.w600,
                                  color: on,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                focus.encouragement,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall.copyWith(
                                  fontSize: HomeDimens.heroSubtitle,
                                  color: on.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _PercentPill(percent: focus.percent),
                      ],
                    ),
                  ),
                  const SizedBox(height: HomeDimens.heroBarGap),
                  _ProgressBar(progress: focus.progress),
                  const SizedBox(height: HomeDimens.heroBarGap),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: FFStatTile.glass(
                            value: '${focus.tasksDone}/${focus.tasksTarget}',
                            label: 'Tasks',
                            onTap: () => context.push(AppRoutes.tasks),
                          ),
                        ),
                        const SizedBox(width: HomeDimens.heroTileGap),
                        Expanded(
                          child: FFStatTile.glass(
                            value: '${focus.habitsDone}/${focus.habitsDue}',
                            label: 'Habits',
                            onTap: () => context.push(AppRoutes.habits),
                          ),
                        ),
                        const SizedBox(width: HomeDimens.heroTileGap),
                        Expanded(
                          child: FFStatTile.glass(
                            value: '${focus.remindersLeft}',
                            label: 'Reminders',
                            onTap: () => context.push(AppRoutes.reminders),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentPill extends StatelessWidget {
  const _PercentPill({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    const on = HomeColors.onHero;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: on.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$percent%',
        style: context.text.buttonSmall.copyWith(
          fontSize: HomeDimens.heroPercent,
          color: on,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    const on = HomeColors.onHero;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: SizedBox(
          height: HomeDimens.heroBar,
          child: ColoredBox(
            color: on.withValues(alpha: 0.25),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: reduce ? Duration.zero : AppMotion.slow,
              curve: AppMotion.curve,
              builder: (context, value, _) => FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: value.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: on,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
