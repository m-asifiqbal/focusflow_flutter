/// ============================================================
/// SCREEN 15 — Habit editor (new / edit)
/// ============================================================
///
/// Cancel · "New Habit" / "Edit Habit" · Create / Save. Preview card,
/// QUICK START templates, DETAILS, GOAL & SCHEDULE, REMINDERS and — when
/// editing — MANAGE (Reset history / Archive / Delete). All state lives in
/// HabitEditorController; leaving with unsaved changes asks first. Edits
/// that change what existing history means are confirmed first
/// (habit_editor_actions.dart): build ⇄ quit needs a history reset, a new
/// goal / schedule / start date re-evaluates past days.
/// Routes: `/habits/new?name=` and `/habits/:id/edit`.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/presentation/habit_editor_actions.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_customize_sheet.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_details_section.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_goal_section.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_preview_card.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_reminders_section.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:go_router/go_router.dart';

class HabitEditorScreen extends ConsumerWidget {
  const HabitEditorScreen({this.habitId, this.initialName, super.key});

  /// The habit to edit; null = new habit.
  final String? habitId;

  /// Pre-filled name of a new habit (Quick Add).
  final String? initialName;

  HabitEditorArgs get _args => (id: habitId, name: initialName);

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final s = ref.read(habitEditorControllerProvider(_args)).valueOrNull;
    if (s != null && s.isDirty) {
      final discard = await showFFConfirm(
        context,
        title: 'Discard changes?',
        message: s.isNew
            ? 'This habit hasn\'t been created yet.'
            : 'Your edits to this habit will be lost.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!discard) return;
    }
    if (context.mounted) _pop(context);
  }

  void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.habits);
    }
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final p = habitEditorControllerProvider(_args);
    final c = ref.read(p.notifier);
    final isNew = habitId == null;
    // Build ⇄ quit with history (e.g. the reset was undone): only with a
    // reset — the same confirmation as picking the type.
    final s = ref.read(p).valueOrNull;
    if (s != null && s.changesKind && await c.refreshHistory()) {
      if (!context.mounted) return;
      if (!await changeHabitKind(context, ref, _args, s.draft.kind)) return;
    }
    if (!context.mounted) return;
    // A new goal / schedule re-evaluates past days: say so first.
    if (!await confirmScheduleChange(context, ref, _args)) return;
    final id = await c.save();
    if (id == null || !context.mounted) return;
    showFFToast(
      context,
      isNew ? 'Habit created' : 'Habit saved',
      icon: FontAwesomeIcons.solidCircleCheck,
    );
    _pop(context);
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref, {
    required bool delete,
  }) async {
    final habit = ref
        .read(habitEditorControllerProvider(_args))
        .valueOrNull
        ?.original;
    if (habit == null) return;
    final refs = [habit.ref];
    final done = delete
        ? await deleteItems(context, ref, refs, title: habit.name)
        : await archiveItems(context, ref, refs, title: habit.name);
    if (done && context.mounted) context.go(AppRoutes.habits);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(habitEditorControllerProvider(_args));
    final s = async.valueOrNull;
    final isNew = habitId == null;
    final canSave = s != null && s.canSave && (s.isNew || s.isDirty);

    return PopScope(
      canPop: s == null || !s.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context, ref);
      },
      child: FFScaffold(
        body: Column(
          children: [
            FFNavHeader(
              leading: FFNavAction(
                label: 'Cancel',
                onPressed: () => _leave(context, ref),
              ),
              title: isNew ? 'New Habit' : 'Edit Habit',
              trailing: [
                FFNavAction(
                  label: isNew ? 'Create' : 'Save',
                  emphasized: true,
                  enabled: canSave,
                  onPressed: () => _save(context, ref),
                ),
              ],
            ),
            Expanded(
              child: async.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsetsDirectional.all(AppSpacing.grouped),
                  child: FFSkeletonList(count: 4),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.grouped),
                  child: FFErrorBanner(
                    message: 'Couldn\'t load this habit.',
                    onRetry: () =>
                        ref.invalidate(habitEditorControllerProvider(_args)),
                  ),
                ),
                data: (state) => state == null
                    ? FFEmptyState(
                        colors: ModuleStyle.habits.colors,
                        icon: ModuleStyle.habits.icon,
                        title: 'Habit not found',
                        body: 'It may have been deleted on another device.',
                        ctaLabel: 'Back to habits',
                        ctaIcon: null,
                        onCta: () => context.go(AppRoutes.habits),
                      )
                    : _EditorBody(
                        args: _args,
                        state: state,
                        onReset: () => resetHabitHistory(
                          context,
                          ref,
                          _args,
                          state.original?.name ?? state.draft.name,
                        ),
                        onArchive: () => _remove(context, ref, delete: false),
                        onDelete: () => _remove(context, ref, delete: true),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorBody extends ConsumerWidget {
  const _EditorBody({
    required this.args,
    required this.state,
    required this.onReset,
    required this.onArchive,
    required this.onDelete,
  });

  final HabitEditorArgs args;
  final HabitEditorState state;
  final VoidCallback onReset;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = state.draft;
    final c = ref.read(habitEditorControllerProvider(args).notifier);
    Widget side(Widget child) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.grouped,
      ),
      child: child,
    );
    const gap = SizedBox(height: AppSpacing.section);

    return ListView(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xxxl,
      ),
      children: [
        side(
          HabitPreviewCard(
            draft: draft,
            onCustomize: () => showHabitCustomizeSheet(context, args),
          ),
        ),
        gap,
        if (state.isNew) ...[
          side(const FFSectionLabel('Quick start')),
          HabitTemplateStrip(onTemplate: c.applyTemplate),
          gap,
        ],
        side(HabitDetailsSection(args: args, draft: draft)),
        gap,
        side(HabitGoalSection(args: args, draft: draft)),
        gap,
        side(HabitRemindersSection(args: args, draft: draft)),
        if (!state.isNew) ...[
          gap,
          side(
            HabitManageSection(
              onReset: onReset,
              onArchive: onArchive,
              onDelete: onDelete,
            ),
          ),
        ],
      ],
    );
  }
}
