/// ============================================================
/// MEDICINE EDITOR — `/medicines/new?name=` and `/medicines/:id/edit`
/// ============================================================
///
/// Cancel · "New medicine" · Save. Title card (icon, name, strength), form,
/// how often + dose times, food timing, course, pills left, reminders,
/// note; an existing medicine adds Archive / Delete (shared lifecycle
/// actions: confirmation + Undo). Leaving with changes asks first. The
/// draft lives in medicineEditorControllerProvider; saving flushes the
/// notification engine so the first alert is scheduled before we close.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';
import 'package:focusflow/features/medicines/presentation/notifiers/medicine_editor_controller.dart';
import 'package:focusflow/features/medicines/presentation/widgets/editor/medicine_options_section.dart';
import 'package:focusflow/features/medicines/presentation/widgets/editor/medicine_schedule_section.dart';
import 'package:focusflow/features/medicines/presentation/widgets/editor/medicine_title_card.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:go_router/go_router.dart';

class MedicineEditorScreen extends ConsumerWidget {
  const MedicineEditorScreen({this.medicineId, this.initialName, super.key});

  final String? medicineId;
  final String? initialName;

  MedicineEditorArgs get _args => (id: medicineId, name: initialName);

  void _pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.medicines);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final s = ref.read(medicineEditorControllerProvider(_args)).valueOrNull;
    if (s != null && s.isDirty) {
      final discard = await showFFConfirm(
        context,
        title: tr('Discard changes?'),
        message: s.isNew
            ? tr('This medicine hasn\'t been added yet.')
            : tr('Your edits to this medicine will be lost.'),
        confirmLabel: tr('Discard'),
        cancelLabel: tr('Keep editing'),
        destructive: true,
      );
      if (!discard) return;
    }
    if (context.mounted) _pop(context);
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final c = ref.read(medicineEditorControllerProvider(_args).notifier);
    final isNew = medicineId == null;
    final id = await c.save();
    if (id == null || !context.mounted) return;
    FFHaptics.light(context);
    showFFToast(
      context,
      isNew ? tr('Medicine added') : tr('Medicine saved'),
      icon: FontAwesomeIcons.solidCircleCheck,
    );
    if (isNew) {
      // Land on the new medicine's page, not back on the form.
      context.pushReplacement(AppRoutes.medicine(id));
    } else {
      _pop(context);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref, {
    required bool delete,
  }) async {
    final m = ref
        .read(medicineEditorControllerProvider(_args))
        .valueOrNull
        ?.original;
    if (m == null) return;
    final done = delete
        ? await deleteItems(context, ref, [m.ref], title: m.name)
        : await archiveItems(context, ref, [m.ref], title: m.name);
    if (done && context.mounted) context.go(AppRoutes.medicines);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(medicineEditorControllerProvider(_args));
    final s = async.valueOrNull;
    final isNew = medicineId == null;
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
                label: tr('Cancel'),
                onPressed: () => _leave(context, ref),
              ),
              title: isNew ? tr('New medicine') : tr('Edit medicine'),
              trailing: [
                FFNavAction(
                  label: isNew ? tr('Add') : tr('Save'),
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
                    message: tr('Couldn\'t load this medicine.'),
                    onRetry: () =>
                        ref.invalidate(medicineEditorControllerProvider(_args)),
                  ),
                ),
                data: (state) => state == null
                    ? FFEmptyState(
                        colors: MedicineStyle.colors,
                        icon: ModuleStyle.medicines.icon,
                        title: tr('Medicine not found'),
                        body: tr('It may have been deleted on another device.'),
                        ctaLabel: tr('Back to medicines'),
                        ctaIcon: null,
                        onCta: () => context.go(AppRoutes.medicines),
                      )
                    : _Body(
                        args: _args,
                        state: state,
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

class _Body extends StatelessWidget {
  const _Body({
    required this.args,
    required this.state,
    required this.onArchive,
    required this.onDelete,
  });

  final MedicineEditorArgs args;
  final MedicineEditorState state;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.section);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.grouped,
        AppSpacing.xs,
        AppSpacing.grouped,
        AppSpacing.xxxl,
      ),
      children: [
        MedicineTitleCard(
          args: args,
          initial: state.draft,
          autofocus: state.isNew && state.draft.name.isEmpty,
        ),
        gap,
        MedicineScheduleSection(args: args),
        gap,
        MedicineOptionsSection(args: args),
        if (!state.isNew) ...[
          gap,
          FFGroupedList(
            label: tr('Manage'),
            children: [
              FFListRow(
                leading: FFIconTile.soft(
                  icon: FontAwesomeIcons.boxArchive,
                  colors: ModuleStyle.vault.colors,
                ),
                title: tr('Archive medicine'),
                subtitle: tr('Stops reminders, keeps the history'),
                onTap: onArchive,
              ),
              FFListRow(
                leading: const FFIconTile.soft(
                  icon: FontAwesomeIcons.trashCan,
                  colors: TagPalette.high,
                ),
                title: tr('Delete medicine'),
                destructive: true,
                onTap: onDelete,
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          tr(
            'FocusFlow only reminds you. Always follow your doctor\'s or pharmacist\'s instructions.',
          ),
          textAlign: TextAlign.center,
          style: context.text.caption,
        ),
      ],
    );
  }
}
