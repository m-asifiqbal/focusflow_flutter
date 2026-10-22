/// ============================================================
/// TASKS LIST — screen 10 (`/library/tasks`)
/// ============================================================
///
/// What: large header ("Tasks" · "7 due today · 2 overdue", view toggle,
/// ⋯ menu), search with tag filter, the four stat tiles, smart-list /
/// task-list chips and the sections (OVERDUE with "Reschedule all",
/// TODAY, UPCOMING, NO DATE, COMPLETED collapsible) — or the board view.
/// Multi-select swaps the header for the selection header and shows the
/// floating selection bar.
/// Why: everything is live (StreamProviders over the repositories) and all
/// writes go through controllers / flows, so this file is layout only.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/features/tasks/presentation/providers/tasks_list_providers.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_board.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_list_item.dart';
import 'package:focusflow/features/tasks/presentation/widgets/task_section.dart';
import 'package:focusflow/features/tasks/presentation/widgets/tasks_header.dart';
import 'package:focusflow/features/tasks/presentation/widgets/tasks_list_states.dart';
import 'package:focusflow/features/tasks/presentation/widgets/tasks_menus.dart';
import 'package:focusflow/features/tasks/presentation/widgets/tasks_overview.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class TasksListScreen extends ConsumerStatefulWidget {
  const TasksListScreen({super.key});

  @override
  ConsumerState<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends ConsumerState<TasksListScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(taskSearchProvider),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selecting = ref.watch(
      itemSelectionProvider(tasksSelectionScope).select((s) => s.active),
    );
    final board = ref.watch(taskViewProvider) == TaskView.board;
    final tagActive = ref.watch(taskTagFilterProvider) != null;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final top = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        child: FFSearchField(
          controller: _search,
          hint: tr('Search tasks...'),
          onChanged: ref.read(taskSearchProvider.notifier).set,
          onClear: () => ref.read(taskSearchProvider.notifier).set(''),
          onFilter: () => pickTaskTagFilter(context, ref),
          filterActive: tagActive,
          filterSemanticLabel: tr('Filter by tag'),
        ),
      ),
      const TaskStatTiles(),
      const SizedBox(height: AppSpacing.lg),
      const TaskFilterChips(),
    ];

    final Widget body = board
        ? Column(
            children: [
              ...top,
              Expanded(child: TaskBoard(bottomInset: bottom)),
            ],
          )
        : CustomScrollView(
            slivers: [
              SliverList(delegate: SliverChildListDelegate(top)),
              ..._sectionSlivers(),
              SliverPadding(
                padding: EdgeInsetsDirectional.only(
                  bottom:
                      bottom + (selecting ? 96 : AppSpacing.bottomBarClearance),
                ),
              ),
            ],
          );

    return MinuteTicker(
      child: PopScope(
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            ref
                .read(itemSelectionProvider(tasksSelectionScope).notifier)
                .clear();
          }
        },
        child: FFScaffold(
          safeBottom: false,
          // Not FFScaffold.floating: the bar's own SafeArea already clears
          // the shell's tab bar (MediaQuery bottom padding), so it is
          // aligned here without extra inset.
          // Title + view/more stay fixed; stats, chips and tasks scroll.
          body: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    const TasksHeader(),
                    Expanded(child: body),
                  ],
                ),
              ),
              if (selecting)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: ItemSelectionBar(
                    scope: tasksSelectionScope,
                    module: ItemType.task,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sectionSlivers() {
    final async = ref.watch(taskSectionsProvider);
    final filter = ref.watch(taskFilterProvider);
    final searching =
        ref.watch(taskSearchProvider).trim().isNotEmpty ||
        ref.watch(taskTagFilterProvider) != null;
    final now = ref.watch(minuteClockProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final collapsed = ref.watch(collapsedTaskSectionsProvider);
    final selecting = ref.watch(
      itemSelectionProvider(tasksSelectionScope).select((s) => s.active),
    );

    final sections = async.valueOrNull;
    if (sections == null) {
      if (async.hasError) {
        return [
          SliverToBoxAdapter(
            child: TasksErrorState(
              onRetry: () => ref.invalidate(taskSectionsProvider),
            ),
          ),
        ];
      }
      return const [SliverToBoxAdapter(child: TasksLoadingState())];
    }

    final allDone =
        filter == TaskFilter.today &&
        !searching &&
        sections.openCount == 0 &&
        sections.completed.isNotEmpty;
    if (sections.isEmpty) {
      final stats = ref.watch(taskStatsProvider).valueOrNull;
      final hasTasks =
          stats == null ||
          stats.today +
                  stats.overdue +
                  stats.upcoming +
                  stats.noDate +
                  stats.done >
              0;
      return [
        SliverToBoxAdapter(
          child: TasksEmptyState(
            filter: filter,
            searching: searching,
            hasTasks: hasTasks,
            onAdd: () => context.push(AppRoutes.newTask()),
          ),
        ),
      ];
    }
    return [
      if (allDone) const SliverToBoxAdapter(child: TasksAllDoneBanner()),
      for (final (key, tasks) in sections.nonEmpty)
        ...taskSectionSlivers(
          sectionKey: key,
          tasks: tasks,
          now: now,
          use24h: use24h,
          collapsed: collapsed.contains(key),
          reorderable: key != 'completed' && !selecting && !searching,
          hideListId: filter.listId,
        ),
    ];
  }
}
