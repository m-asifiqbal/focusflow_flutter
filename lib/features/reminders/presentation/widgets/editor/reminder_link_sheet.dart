/// ============================================================
/// REMINDER LINK + LOCATION SHEETS — pickers of screen 13
/// ============================================================
///
/// What:
///   * [showReminderLinkSheet] — Tasks | Notes segments, a search field and
///     a live list; resolves to a [Picked] [ReminderLink] (null value =
///     remove the link), or null when dismissed.
///   * [showLocationTriggerSheet] — explains that location triggers arrive
///     in v1.1 (the prompt puts the geofence picker behind a flag).
/// Why: a reminder links one task or note ("Open" from the notification
/// jumps there); the choice is saved with the reminder on Save.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/providers/reminder_editor_providers.dart';
import 'package:focusflow/features/tasks/presentation/providers/task_editor_providers.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

/// The picked task / note.
typedef ReminderLink = ({ItemRef ref, String title});

/// Opens the link picker; [current] marks the linked item.
Future<Picked<ReminderLink?>?> showReminderLinkSheet(
  BuildContext context, {
  ItemRef? current,
}) {
  return showFFBottomSheet<Picked<ReminderLink?>>(
    context,
    wrap: false,
    builder: (_) => _LinkSheet(current: current),
  );
}

class _LinkSheet extends ConsumerStatefulWidget {
  const _LinkSheet({this.current});

  final ItemRef? current;

  @override
  ConsumerState<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends ConsumerState<_LinkSheet> {
  late ItemType _type = widget.current?.type == ItemType.note
      ? ItemType.note
      : ItemType.task;
  String _query = '';

  void _pop(ReminderLink? link) => Navigator.of(context).pop(Picked(link));

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final isTasks = _type == ItemType.task;
    final AsyncValue<List<ReminderLink>> items = isTasks
        ? ref
              .watch(linkableTasksProvider(_query))
              .whenData(
                (l) => [
                  for (final t in l)
                    (ref: ItemRef(ItemType.task, t.id), title: t.title),
                ],
              )
        : ref
              .watch(linkableNotesProvider(_query))
              .whenData(
                (l) => [
                  for (final n in l)
                    (ref: ItemRef(ItemType.note, n.id), title: n.displayTitle),
                ],
              );
    final style = isTasks ? ModuleStyle.tasks : ModuleStyle.notes;
    return FFBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(tr('Link to')),
          FFSegmented<ItemType>(
            segments: [
              FFSegment(value: ItemType.task, label: tr('Tasks')),
              FFSegment(value: ItemType.note, label: tr('Notes')),
            ],
            value: _type,
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: AppSpacing.md),
          FFSearchField(
            hint: isTasks ? tr('Search tasks') : tr('Search notes'),
            onChanged: (q) => setState(() => _query = q),
            onClear: () => setState(() => _query = ''),
          ),
          const SizedBox(height: AppSpacing.lg),
          switch (items) {
            AsyncData(:final value) => FFGroupedList(
              dividerIndent: AppSpacing.lg,
              children: [
                if (current != null && _query.isEmpty)
                  OptionRow(
                    label: tr('No link'),
                    icon: FontAwesomeIcons.linkSlash,
                    colors: ActionTints.lock,
                    selected: false,
                    onTap: () => _pop(null),
                  ),
                for (final i in value)
                  OptionRow(
                    label: i.title.isEmpty ? tr('Untitled') : i.title,
                    icon: style.icon,
                    colors: style.colors,
                    selected: i.ref == current,
                    onTap: () => _pop(i),
                  ),
                if (value.isEmpty)
                  FFListRow(
                    title: _query.isNotEmpty
                        ? tr('Nothing matches')
                        : isTasks
                        ? tr('No tasks yet')
                        : tr('No notes yet'),
                    enabled: false,
                  ),
              ],
            ),
            AsyncError() => FFErrorBanner(
              message: isTasks
                  ? tr('Couldn\'t load tasks')
                  : tr('Couldn\'t load notes'),
              onRetry: () => isTasks
                  ? ref.invalidate(linkableTasksProvider(_query))
                  : ref.invalidate(linkableNotesProvider(_query)),
            ),
            _ => const FFSkeletonRow(),
          },
        ],
      ),
    );
  }
}

/// "Location trigger" — not available yet (v1.1); explains why.
Future<void> showLocationTriggerSheet(BuildContext context) {
  return showFFBottomSheet<void>(
    context,
    builder: (sheetContext) {
      final ff = sheetContext.ff;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            child: FFIconTile.soft(
              icon: FontAwesomeIcons.locationDot,
              colors: TagPalette.design,
              size: AppSizes.iconTileLg,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tr('Location triggers are coming soon'),
            textAlign: TextAlign.center,
            style: sheetContext.text.cardTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr(
              'Reminders that go off when you arrive at or leave a place are coming in {name} 1.1, and will work offline, on your device only. For now this reminder alerts you at its time.',
              {'name': AppInfo.name},
            ),
            textAlign: TextAlign.center,
            style: sheetContext.text.body.copyWith(color: ff.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          FFPrimaryButton(
            label: tr('Got it'),
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      );
    },
  );
}
