/// ============================================================
/// HABIT CARD SKELETON — loading placeholder shaped like a HabitCard
/// ============================================================
///
/// Ring circle, two text lines, the 44-pt button, a divider and the seven
/// week squares — so the list doesn't jump when data arrives. Shimmers
/// (static under reduce motion, via FFShimmer).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

class HabitCardSkeleton extends StatelessWidget {
  const HabitCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return FFCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              FFSkeleton(
                width: HabitDimens.cardRing,
                height: HabitDimens.cardRing,
                radius: HabitDimens.cardRing / 2,
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FFSkeleton(
                      widthFactor: 0.6,
                      height: HabitDimens.skeletonTitle,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    FFSkeleton(
                      widthFactor: 0.4,
                      height: HabitDimens.skeletonSubtitle,
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md),
              FFSkeleton(
                width: HabitDimens.checkButton,
                height: HabitDimens.checkButton,
                radius: HabitDimens.checkRadius,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          Divider(height: 1, thickness: 1, color: context.ff.divider),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: HabitDimens.weekSquareGap),
                const FFSkeleton(
                  width: HabitDimens.weekSquare,
                  height: HabitDimens.weekSquare,
                  radius: HabitDimens.weekSquareRadius,
                ),
              ],
              const Spacer(),
              const FFSkeleton(
                width: HabitDimens.skeletonStreakWidth,
                height: HabitDimens.skeletonStreak,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A shimmering column of [count] skeleton cards.
class HabitListSkeleton extends StatelessWidget {
  const HabitListSkeleton({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading habits',
      child: FFShimmer(
        child: Column(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.cardGap),
              const HabitCardSkeleton(),
            ],
          ],
        ),
      ),
    );
  }
}
