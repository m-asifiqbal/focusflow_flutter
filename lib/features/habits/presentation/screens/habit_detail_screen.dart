/// ============================================================
/// SCREEN 16 — Habit detail & stats
/// ============================================================
///
/// Back · "Habit" · edit + more. Big ring with today's value, name and
/// meta, "+ Log 1 glass" / "Skip today", the 2×2 stats, the consistency
/// heatmap (tap a day to edit it), monthly completion bars and the latest
/// history. Everything comes from the live habitDetailProvider, so a
/// check-in anywhere updates the screen. A build habit without check-ins
/// shows dashes and "Your stats appear after the first check-in"; a quit
/// habit has stats from its start date on (clean days need no log).
/// Route: `/habits/:id`.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/habit_detail_actions.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_detail_providers.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_consistency_card.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_day_log_sheet.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_detail_hero.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_history_card.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_monthly_chart.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_stat_grid.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_day_ticker.dart';
import 'package:go_router/go_router.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({required this.habitId, super.key});

  final String habitId;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.habits);
    }
  }

  void _editDay(HabitDetail d, DateTime day) => showHabitDayLogSheet(
    context,
    habit: d.habit,
    day: day,
    today: d.today,
    log: d.logs.firstWhereOrNull((l) => DateUtilsX.isSameDay(l.date, day)),
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(habitDetailProvider(widget.habitId));
    final d = async.valueOrNull;

    // HabitDayTicker: a new habit day (midnight / reset time, or while the
    // app was in background) moves "today" on.
    return HabitDayTicker(
      child: FFScaffold(
        body: Column(
          children: [
            FFNavHeader(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.grouped,
              ),
              leading: FFBackButton(onPressed: _back),
              title: tr('Habit'),
              trailing: [
                FFRoundIconButton(
                  icon: FontAwesomeIcons.pen,
                  semanticLabel: tr('Edit habit'),
                  iconColor: context.ff.primary,
                  onPressed: d == null
                      ? null
                      : () => context.push(AppRoutes.habitEdit(widget.habitId)),
                ),
                FFRoundIconButton(
                  icon: FontAwesomeIcons.ellipsis,
                  semanticLabel: tr('More options'),
                  onPressed: d == null
                      ? null
                      : () =>
                            showHabitDetailMore(context, ref, d.habit, d.logs),
                ),
              ],
            ),
            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                loading: () => const _DetailSkeleton(),
                error: (_, _) => Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.grouped),
                  child: FFErrorBanner(
                    message: tr('Couldn\'t load this habit.'),
                    onRetry: () =>
                        ref.invalidate(habitDetailProvider(widget.habitId)),
                  ),
                ),
                data: (detail) => detail == null
                    ? FFEmptyState(
                        colors: ModuleStyle.habits.colors,
                        icon: ModuleStyle.habits.icon,
                        title: tr('Habit not found'),
                        body: tr('It may have been deleted.'),
                        ctaLabel: tr('Back to habits'),
                        ctaIcon: null,
                        onCta: () => context.go(AppRoutes.habits),
                      )
                    : _DetailBody(
                        detail: detail,
                        onDay: (day) => _editDay(detail, day),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.onDay});

  final HabitDetail detail;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = detail.habit;
    final stats = detail.stats;
    final todayLog = stats.todayLog;
    final empty = detail.isEmpty;
    final history = ref.watch(habitHistoryProvider(habit.id));
    final canLog = habit.isActive;
    const sectionGap = SizedBox(height: AppSpacing.xxxl);
    // Before a header with a 44-pt action link (its title sits lower).
    const actionGap = SizedBox(
      height: AppSpacing.xxxl - HabitDimens.actionHeaderInset,
    );

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.grouped,
        AppSpacing.xl,
        AppSpacing.grouped,
        AppSpacing.xxxl,
      ),
      children: [
        HabitDetailHero(
          habit: habit,
          todayLog: todayLog,
          progress: stats.todayProgress,
          onLog: canLog
              ? () => logFromDetail(context, ref, habit, todayLog)
              : null,
          onSkip: canLog
              ? () => skipFromDetail(context, ref, habit, todayLog)
              : null,
        ),
        const SizedBox(height: AppSpacing.section),
        HabitStatGrid(habit: habit, stats: stats, empty: empty),
        if (empty) sectionGap else actionGap,
        if (empty)
          FFEmptyState.compact(
            colors: habit.colors,
            icon: FontAwesomeIcons.chartSimple,
            title: habit.isQuit
                ? tr('Not started yet')
                : tr('No check-ins yet'),
            body: habit.isQuit
                ? tr('Clean days count from the start date.')
                : tr('Your stats appear after the first check-in.'),
          )
        else ...[
          HabitConsistencyCard(habit: habit, today: detail.today, onDay: onDay),
          sectionGap,
          if (stats.monthly.isNotEmpty) ...[
            HabitMonthlyChart(months: stats.monthly, colors: habit.colors),
            if (history.length > HabitHistoryCard.defaultLimit)
              actionGap
            else
              sectionGap,
          ],
          HabitHistoryCard(
            habit: habit,
            entries: history,
            today: detail.today,
            onDay: onDay,
          ),
        ],
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return FFShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.all(AppSpacing.grouped),
        children: [
          const Center(
            child: FFSkeleton(
              width: HabitDimens.detailRing,
              height: HabitDimens.detailRing,
              radius: HabitDimens.detailRing / 2,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Center(
            child: FFSkeleton(
              widthFactor: 0.5,
              height: HabitDimens.detailNameSkeleton,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          for (var i = 0; i < 2; i++) ...[
            const Row(
              children: [
                Expanded(
                  child: FFSkeleton(
                    height: HabitDimens.statTileHeight,
                    radius: AppRadii.card,
                  ),
                ),
                SizedBox(width: AppSpacing.cardGap),
                Expanded(
                  child: FFSkeleton(
                    height: HabitDimens.statTileHeight,
                    radius: AppRadii.card,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.cardGap),
          ],
        ],
      ),
    );
  }
}
