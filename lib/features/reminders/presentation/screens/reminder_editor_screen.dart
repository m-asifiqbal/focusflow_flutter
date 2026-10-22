/// ============================================================
/// REMINDER EDITOR SCREEN — screen 13 (`/reminders/new`, `/reminders/:id`)
/// ============================================================
///
/// What: Cancel · New/Edit Reminder · Save over the form
/// ([ReminderEditorBody]). Save writes through
/// [reminderEditorControllerProvider] and pops; the NotificationEngine
/// (re)schedules the OS notification from the database.
/// Why: Cancel (button, back gesture, system back) with unsaved changes
/// asks to discard; Archive / Delete use the shared lifecycle helpers
/// (confirmation + 5 s Undo) so every list updates live.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_editor_controller.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_editor_state.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_editor_body.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_editor_chrome.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_labels.dart';

class ReminderEditorScreen extends ConsumerStatefulWidget {
  const ReminderEditorScreen({required this.args, super.key});

  final ReminderEditorArgs args;

  @override
  ConsumerState<ReminderEditorScreen> createState() =>
      _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  /// Set once the editor is closing on purpose (skips the discard check).
  bool _leaving = false;

  ReminderEditorController get _form =>
      ref.read(reminderEditorControllerProvider(widget.args).notifier);

  ReminderEditorState? get _state =>
      ref.read(reminderEditorControllerProvider(widget.args)).valueOrNull;

  void _leave() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go(AppRoutes.reminders);
    });
  }

  Future<void> _cancel() async {
    final s = _state;
    if (s != null && s.isDirty) {
      final discard = await showFFConfirm(
        context,
        title: tr('Discard changes?'),
        message: s.isNew
            ? tr('This reminder hasn\'t been saved yet.')
            : tr('Your edits to this reminder won\'t be saved.'),
        confirmLabel: tr('Discard'),
        cancelLabel: tr('Keep editing'),
        destructive: true,
        icon: FontAwesomeIcons.solidTrashCan,
      );
      if (!discard || !mounted) return;
    }
    _leave();
  }

  /// Saves; returns the reminder id (null when invalid or failed).
  Future<String?> _write() async {
    try {
      return await _form.save();
    } on Exception {
      if (mounted) {
        showFFToast(
          context,
          tr("Couldn't save the reminder"),
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
      return null;
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final now = ref.read(clockProvider).now();
    final rolled = _state?.pastTimeRollsTo(now);
    final use24h = ref.read(settingsProvider).use24HourTime;
    final id = await _write();
    if (id == null || !mounted) return;
    if (rolled != null) {
      showFFToast(
        context,
        tr('Time had passed — set for {when}', {
          'when': ReminderLabels.rolledTo(rolled, now, use24h: use24h),
        }),
        icon: FontAwesomeIcons.solidClock,
      );
    }
    _leave();
  }

  Future<void> _archive() async {
    final s = _state;
    if (s == null) return;
    if (s.isDirty && s.canSave && await _write() == null) return;
    if (!mounted) return;
    final done = await archiveItems(context, ref, [
      ItemRef(ItemType.reminder, s.original.id),
    ], title: s.draft.title.trim());
    if (done && mounted) _leave();
  }

  Future<void> _delete() async {
    final s = _state;
    if (s == null) return;
    final done = await deleteItems(context, ref, [
      ItemRef(ItemType.reminder, s.original.id),
    ], title: s.original.title);
    if (done && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reminderEditorControllerProvider(widget.args));
    final s = async.valueOrNull;
    final dirty = s?.isDirty ?? false;
    // The editor's "Today" (chips, date sheet, time / repeat anchors) must
    // follow the clock even when no list screen is ticking it.
    return MinuteTicker(
      child: PopScope(
        canPop: _leaving || !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _cancel();
        },
        child: FFScaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskEditorHeader(
                title: widget.args.isNew
                    ? tr('New Reminder')
                    : tr('Edit Reminder'),
                canSave: s?.canSave ?? false,
                onCancel: _cancel,
                onSave: _save,
              ),
              Expanded(
                child: switch (async) {
                  AsyncData(:final value) => ReminderEditorBody(
                    args: widget.args,
                    state: value,
                    onArchive: value.original.isArchived ? null : _archive,
                    onDelete: _delete,
                  ),
                  AsyncError(:final error) => _ErrorState(
                    notFound: error is ReminderNotFoundException,
                    onRetry: () => ref.invalidate(
                      reminderEditorControllerProvider(widget.args),
                    ),
                    onBack: _leave,
                  ),
                  _ => const _LoadingState(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FFSkeleton(height: 80, radius: AppRadii.card),
          SizedBox(height: AppSpacing.section),
          FFSkeleton(height: 38, radius: AppRadii.button),
          SizedBox(height: AppSpacing.md),
          FFSkeleton(height: 235, radius: AppRadii.card),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.notFound,
    required this.onRetry,
    required this.onBack,
  });

  final bool notFound;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: notFound
            ? FFEmptyState(
                colors: ModuleStyle.reminders.colors,
                icon: FontAwesomeIcons.solidBell,
                title: tr('Reminder not found'),
                body: tr('It may have been deleted on another device.'),
                ctaLabel: tr('Back to reminders'),
                ctaIcon: FontAwesomeIcons.arrowLeft,
                onCta: onBack,
              )
            : FFErrorBanner(
                message: tr('Couldn\'t load this reminder'),
                onRetry: onRetry,
              ),
      ),
    );
  }
}
