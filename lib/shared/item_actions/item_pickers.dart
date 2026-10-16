/// ============================================================
/// ITEM PICKERS — the generic follow-up sheets of the item actions sheet
/// ============================================================
///
/// "Change colour", "Edit tags / move to folder" and "Set reminder" work
/// the same for every module, so they live here and are shared by the
/// actions sheet, editors and multi-select bars. Each one writes through
/// the repositories itself (live streams update every screen).
///
/// Owned by the Notes/Library phase (screens 07–09); built from
/// core/widgets (FFBottomSheet, FFChipBar, FFGroupedList…).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/ff_action_sheet.dart';
import 'package:focusflow/core/widgets/ff_bottom_sheet.dart';
import 'package:focusflow/core/widgets/ff_snackbar.dart';
import 'package:focusflow/features/library/presentation/widgets/item_picker_sheets.dart';
import 'package:focusflow/features/library/presentation/widgets/reminder_quick_sheet.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Card colour picker (note card palette, screen 08 / design system) for
/// [items]; white clears the colour.
Future<void> pickItemColour(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> items, {
  String? current,
}) async {
  if (items.isEmpty) return;
  final choice = await showFFBottomSheet<ColourChoice>(
    context,
    // The sheet builds its own FFBottomSheet.
    wrap: false,
    builder: (_) => ColourPickerSheet(current: current),
  );
  if (choice == null) return;
  await ref.read(itemsRepositoryProvider).setColor(items, choice.hex);
}

/// Tags (add) and folder or list (scoped to the item's module) for [item].
Future<void> editItemTagsAndFolder(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final list = item.type == ItemType.task;
  final hasFolders = item.type == ItemType.note || list;
  if (!hasFolders) {
    await addTagsToItems(context, ref, [item.ref]);
    return;
  }
  await showFFActionSheet(
    context,
    FFActionSheetData(
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.tag,
          label: 'Add tags',
          colors: ModuleStyle.notes.colors,
          onTap: () => addTagsToItems(context, ref, [item.ref]),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.solidFolder,
          label: list ? 'Move to list' : 'Move to folder',
          colors: ModuleStyle.tasks.colors,
          onTap: () => moveItemsToFolder(context, ref, item.type, [
            item.ref,
          ], current: item.folderId),
        ),
      ],
    ),
  );
}

/// Adds tags to one or many items (editor "+", multi-select "Tag").
/// Returns false when the picker was dismissed (nothing changed).
Future<bool> addTagsToItems(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> items,
) async {
  if (items.isEmpty) return false;
  final existing = items.length == 1
      ? await ref.read(tagsRepositoryProvider).watchTagsOf(items.first).first
      : const [];
  if (!context.mounted) return false;
  final names = await showFFBottomSheet<List<String>>(
    context,
    // The sheet builds its own FFBottomSheet.
    wrap: false,
    builder: (_) => TagPickerSheet(
      exclude: {for (final t in existing) t.name.toLowerCase()},
    ),
  );
  if (names == null || names.isEmpty) return false;
  await ref.read(itemsRepositoryProvider).addTags(items, names);
  return true;
}

/// Moves items of one module into a folder / list (multi-select "Move",
/// editor folder chip). [current] marks the item's folder. Returns false
/// when the picker was dismissed.
Future<bool> moveItemsToFolder(
  BuildContext context,
  WidgetRef ref,
  ItemType module,
  List<ItemRef> items, {
  String? current,
}) async {
  if (items.isEmpty) return false;
  final choice = await showFFBottomSheet<FolderChoice>(
    context,
    // The sheet builds its own FFBottomSheet.
    wrap: false,
    builder: (_) => FolderPickerSheet(
      module: module,
      current: current,
      title: module == ItemType.task ? 'Move to list' : 'Move to folder',
    ),
  );
  if (choice == null) return false;
  await ref.read(itemsRepositoryProvider).setFolder(items, choice.folderId);
  return true;
}

/// "Set reminder" for a note / task: quick presets, a custom date + time,
/// the full reminder editor (screen 13) or "Remove reminder". Writes via
/// RemindersRepository.upsertLinkedReminder (also stores the reminder id
/// on the item) and confirms with a toast.
Future<void> setItemReminder(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final reminders = ref.read(remindersRepositoryProvider);
  final linked = await reminders.getLinkedReminder(item.ref);
  if (!context.mounted) return;
  final now = ref.read(clockProvider).now();
  final use24h = ref.read(settingsProvider).use24HourTime;
  final choice = await showFFBottomSheet<ReminderQuickChoice>(
    context,
    // The sheet builds its own FFBottomSheet.
    wrap: false,
    builder: (_) => ReminderQuickSheet(
      now: now,
      current: linked?.triggerAt,
      use24h: use24h,
    ),
  );
  if (choice == null || !context.mounted) return;
  final DateTime at;
  switch (choice) {
    case ReminderAt(at: final picked):
      at = picked;
    case ReminderPickCustom():
      final custom = await _pickDateTime(context, linked?.triggerAt, now);
      if (custom == null) return;
      at = custom;
    case ReminderMoreOptions():
      final id = linked?.id;
      await context.push(
        id != null
            ? AppRoutes.reminder(id)
            : AppRoutes.newReminder(title: item.displayTitle, link: item.ref),
      );
      return;
    case ReminderRemove():
      await reminders.removeLinkedReminder(item.ref);
      if (context.mounted) {
        showFFToast(
          context,
          'Reminder removed',
          icon: FontAwesomeIcons.bellSlash,
        );
      }
      return;
  }
  await reminders.upsertLinkedReminder(
    item.ref,
    title: item.displayTitle,
    at: at,
    repeatRule: linked?.repeatRule,
  );
  if (!context.mounted) return;
  showFFToast(
    context,
    'Reminder set for ${reminderWhenLabel(at, now, use24h: use24h)}',
    icon: FontAwesomeIcons.solidBell,
  );
}

/// Material date then time picker; null when either is cancelled or the
/// result is in the past.
Future<DateTime?> _pickDateTime(
  BuildContext context,
  DateTime? initial,
  DateTime now,
) async {
  final start = initial != null && initial.isAfter(now)
      ? initial
      : now.add(const Duration(hours: 1));
  final day = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: DateTime(now.year + 10),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null) return null;
  final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  return at.isAfter(now) ? at : null;
}
