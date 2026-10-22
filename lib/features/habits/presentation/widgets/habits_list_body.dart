/// ============================================================
/// HABITS LIST BODY — the cards of one chip (screen 14)
/// ============================================================
///
/// A sliver over `habitDayStatusesProvider(scope)`: skeleton cards while
/// loading, an error banner with Retry, a per-chip empty state, or the
/// habit cards. Active chips wrap each card in ItemSwipe (Settings ›
/// Gestures; "Complete" = Log today) and long-press opens the shared item
/// actions sheet. The Archived chip offers Restore / Delete instead. In
/// [reordering] mode the cards get drag handles (manual order, scoped to
/// the pinned / other group — see [HabitReorderGroup]).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/habit_check_in_actions.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_amount_sheet.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_card.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_card_skeleton.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/item_actions/item_swipe.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:go_router/go_router.dart';

class HabitsListBody extends ConsumerWidget {
  const HabitsListBody({
    required this.scope,
    this.reordering = false,
    super.key,
  });

  final HabitsScope scope;
  final bool reordering;

  static const _gutter = EdgeInsetsDirectional.symmetric(
    horizontal: AppSpacing.screen,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(habitDayStatusesProvider(scope));
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const SliverPadding(
        padding: _gutter,
        sliver: SliverToBoxAdapter(child: HabitListSkeleton()),
      ),
      error: (_, _) => SliverPadding(
        padding: _gutter,
        sliver: SliverToBoxAdapter(
          child: FFErrorBanner(
            message: tr('Couldn\'t load your habits.'),
            onRetry: () => ref.invalidate(habitDayStatusesProvider(scope)),
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return SliverToBoxAdapter(child: _HabitsEmpty(scope: scope));
        }
        if (reordering) return _ReorderList(list: list);
        return SliverPadding(
          padding: _gutter,
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.cardGap),
            itemBuilder: (context, i) => _HabitRow(
              key: ValueKey(list[i].habit.id),
              status: list[i],
              archived: scope == HabitsScope.archived,
            ),
          ),
        );
      },
    );
  }
}

/// One card + its gestures.
class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.status, required this.archived, super.key});

  final HabitDayStatus status;
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = status.habit;
    final itemRef = ItemRef(ItemType.habit, habit.id);
    final card = HabitCard(
      status: status,
      onTap: () => context.push(AppRoutes.habit(habit.id)),
      onLongPress: archived
          ? () => _archivedActions(context, ref, itemRef)
          : () => showItemActions(context, ref, itemRef),
      onCheck: archived ? null : () => checkInHabit(context, ref, status),
      onCheckLongPress: archived
          ? null
          : () => showHabitAmountSheet(context, status),
    );
    // The detail grows out of this card (open-container transition).
    final tracked = FFOpenOriginTracker(child: card);
    if (archived) return tracked;
    return ItemSwipe(
      item: itemRef,
      isPinned: habit.isPinned,
      isFavorite: habit.isFavorite,
      title: habit.name,
      completeLabel: tr('Log'),
      onComplete: () => logHabitToday(context, ref, habit.id),
      child: tracked,
    );
  }

  Future<void> _archivedActions(
    BuildContext context,
    WidgetRef ref,
    ItemRef itemRef,
  ) {
    final name = status.habit.name;
    return showFFActionSheet(
      context,
      FFActionSheetData(
        header: FFActionSheetHeader(
          title: name,
          icon: ModuleStyle.habits.icon,
          colors: ModuleStyle.habits.colors,
          meta: tr('Habit · Archived'),
        ),
        actions: [
          FFActionItem(
            icon: FontAwesomeIcons.boxOpen,
            label: tr('Restore'),
            colors: ModuleStyle.habits.colors,
            onTap: () =>
                restoreFromArchive(context, ref, [itemRef], title: name),
          ),
        ],
        onDelete: () => deleteItems(
          context,
          ref,
          [itemRef],
          offerArchive: false,
          title: name,
        ),
      ),
    );
  }
}

/// Manual-order mode: drag handles, no swipe / check-in.
///
/// Pinned habits always lead the list (the repository orders pinned
/// first), so a drop across that boundary could never show where it was
/// dropped. As in Notes, dragging is scoped to the habit's group: pinned
/// and other habits are two separate reorderable lists (labelled when both
/// exist), each reordered only within itself.
class _ReorderList extends StatelessWidget {
  const _ReorderList({required this.list});

  final List<HabitDayStatus> list;

  @override
  Widget build(BuildContext context) {
    final pinned = [
      for (final s in list)
        if (s.habit.isPinned) s,
    ];
    final others = [
      for (final s in list)
        if (!s.habit.isPinned) s,
    ];
    final labelled = pinned.isNotEmpty && others.isNotEmpty;
    Widget label(String text) => Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: FFSectionLabel(text),
    );
    return SliverPadding(
      padding: HabitsListBody._gutter,
      sliver: SliverMainAxisGroup(
        slivers: [
          if (labelled) SliverToBoxAdapter(child: label(tr('Pinned'))),
          if (pinned.isNotEmpty)
            HabitReorderGroup(key: const ValueKey('pinned'), list: pinned),
          if (labelled) SliverToBoxAdapter(child: label(tr('Other habits'))),
          if (others.isNotEmpty)
            HabitReorderGroup(key: const ValueKey('others'), list: others),
        ],
      ),
    );
  }
}

/// One drag scope of the reorder mode: the habits of [list] (all pinned or
/// all not pinned) can only be moved among themselves.
class HabitReorderGroup extends ConsumerWidget {
  const HabitReorderGroup({required this.list, super.key});

  final List<HabitDayStatus> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = [for (final s in list) s.habit.id];
    return SliverReorderableList(
      itemCount: list.length,
      onReorderItem: (from, to) =>
          reorderHabits(ref.read(habitsRepositoryProvider), ids, from, to),
      itemBuilder: (context, i) => Padding(
        key: ValueKey(ids[i]),
        padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.cardGap),
        child: Stack(
          children: [
            HabitCard(status: list[i]),
            PositionedDirectional(
              top: 0,
              end: 0,
              bottom: 0,
              child: ReorderableDragStartListener(
                index: i,
                child: Semantics(
                  label: tr('Reorder {name}', {'name': list[i].habit.name}),
                  button: true,
                  child: SizedBox(
                    width: AppSizes.minTap + AppSpacing.lg,
                    child: Icon(
                      FontAwesomeIcons.gripLines,
                      color: context.ff.inkFaint,
                      size: AppSpacing.xl,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-chip empty states (screen 29 pattern).
class _HabitsEmpty extends StatelessWidget {
  const _HabitsEmpty({required this.scope});

  final HabitsScope scope;

  @override
  Widget build(BuildContext context) {
    final style = ModuleStyle.habits;
    final (title, body) = switch (scope) {
      HabitsScope.today || HabitsScope.all => (
        tr('No habits yet'),
        tr(
          'Small daily actions add up. Start one habit and keep the chain going.',
        ),
      ),
      HabitsScope.morning => (
        tr('No morning habits'),
        tr("Set a habit's time of day to Morning to see it here."),
      ),
      HabitsScope.afternoon || HabitsScope.evening => (
        tr('No evening habits'),
        tr("Set a habit's time of day to Afternoon or Evening to see it here."),
      ),
      HabitsScope.archived => (
        tr('No archived habits'),
        tr('Archived habits keep their history and can be restored anytime.'),
      ),
    };
    final full = scope == HabitsScope.today || scope == HabitsScope.all;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.xxl,
      ),
      child: FFEmptyState(
        colors: style.colors,
        icon: style.icon,
        title: title,
        body: body,
        compact: !full,
        ctaLabel: full ? tr('New habit') : null,
        onCta: full ? () => context.push(AppRoutes.newHabit()) : null,
        hint: full ? tr('Try: "Drink 8 glasses of water"') : null,
        onHint: full
            ? () => context.push(AppRoutes.newHabit(name: tr('Drink water')))
            : null,
      ),
    );
  }
}
