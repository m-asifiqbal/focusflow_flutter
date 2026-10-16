/// ============================================================
/// HABITS LIST — screen 14 (`/library/habits`)
/// ============================================================
///
/// Large "Habits" header with "2 of 5 done today" + stats / more buttons,
/// the indigo→violet "Keep the chain going!" hero, the Today · All habits ·
/// Morning · Evening · Archived chips and the habit cards
/// (HabitsListBody). Everything is live: a check-in anywhere updates the
/// header, hero and cards. The habit day re-evaluates when the app
/// resumes (Settings › Habit reset time), and the "Perfect day!" confetti
/// plays once when the last due habit is checked in.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/domain/services/habits_day_summary.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_confetti.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_day_ticker.dart';
import 'package:focusflow/features/habits/presentation/widgets/habits_hero_card.dart';
import 'package:focusflow/features/habits/presentation/widgets/habits_list_body.dart';
import 'package:go_router/go_router.dart';

class HabitsListScreen extends ConsumerStatefulWidget {
  const HabitsListScreen({super.key});

  /// Chips in mockup order. "Evening" also lists afternoon habits.
  static const chips = [
    FFChipItem(value: HabitsScope.today, label: 'Today'),
    FFChipItem(value: HabitsScope.all, label: 'All habits'),
    FFChipItem(value: HabitsScope.morning, label: 'Morning'),
    FFChipItem(value: HabitsScope.evening, label: 'Evening'),
    FFChipItem(value: HabitsScope.archived, label: 'Archived'),
  ];

  /// Header subtitle for [s].
  static String subtitle(HabitsDaySummary s) {
    if (s.total == 0) return 'Build a streak, one day at a time';
    if (s.due == 0) return 'Nothing due today';
    return '${s.done} of ${s.due} done today';
  }

  @override
  ConsumerState<HabitsListScreen> createState() => _HabitsListScreenState();
}

class _HabitsListScreenState extends ConsumerState<HabitsListScreen> {
  final _confetti = HabitConfettiController();
  bool _reordering = false;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _onSummary(
    AsyncValue<HabitsDaySummary>? prev,
    AsyncValue<HabitsDaySummary> next,
  ) {
    final before = prev?.valueOrNull;
    final now = next.valueOrNull;
    // Only a transition to perfect celebrates (not opening a finished day).
    if (before == null || now == null || before.isPerfect || !now.isPerfect) {
      return;
    }
    final day = ref.read(habitTodayProvider);
    if (ref.read(perfectDayCelebrationProvider.notifier).claim(day)) {
      _confetti.play();
    }
  }

  Future<void> _more() => showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: 'Habits',
        icon: ModuleStyle.habits.icon,
        colors: ModuleStyle.habits.colors,
      ),
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.plus,
          label: 'New habit',
          colors: ModuleStyle.habits.colors,
          onTap: () => context.push(AppRoutes.newHabit()),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.gripLines,
          label: 'Reorder habits',
          colors: ModuleStyle.tasks.colors,
          onTap: () => setState(() => _reordering = true),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(habitsDaySummaryProvider, _onSummary);
    final summary = ref.watch(habitsDaySummaryProvider).valueOrNull;
    final scope = ref.watch(habitsScopeProvider);

    final actions = _reordering
        ? [
            FFNavAction(
              label: 'Done',
              emphasized: true,
              onPressed: () => setState(() => _reordering = false),
            ),
          ]
        : [
            FFRoundIconButton(
              icon: FontAwesomeIcons.chartSimple,
              semanticLabel: 'Habit stats',
              onPressed: () => context.go(AppRoutes.insights),
            ),
            FFRoundIconButton(
              icon: FontAwesomeIcons.ellipsis,
              semanticLabel: 'More options',
              onPressed: _more,
            ),
          ];

    // HabitDayTicker: a new habit day (midnight / reset time, or while the
    // app was in background) refreshes every card.
    return HabitDayTicker(
      child: FFScaffold(
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: FFLargeHeader(
                    title: 'Habits',
                    subtitle: _reordering
                        ? 'Drag to reorder'
                        : summary == null
                        ? ' '
                        : HabitsListScreen.subtitle(summary),
                    actions: actions,
                  ),
                ),
                if (summary != null && summary.total > 0 && !_reordering)
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.screen,
                      AppSpacing.sm + AppSpacing.xxs,
                      AppSpacing.screen,
                      AppSpacing.lg + AppSpacing.xxs,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: HabitsHeroCard(summary: summary),
                    ),
                  ),
                if (!_reordering)
                  SliverToBoxAdapter(
                    child: FFChipBar<HabitsScope>(
                      items: HabitsListScreen.chips,
                      selected: scope,
                      onSelected: ref.read(habitsScopeProvider.notifier).select,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                HabitsListBody(
                  scope: _reordering ? HabitsScope.all : scope,
                  reordering: _reordering,
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.bottomBarClearance),
                ),
              ],
            ),
            Positioned.fill(child: HabitConfetti(controller: _confetti)),
          ],
        ),
      ),
    );
  }
}
