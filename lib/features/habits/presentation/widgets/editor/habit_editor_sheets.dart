/// ============================================================
/// HABIT EDITOR SHEETS — small pickers of the habit editor (screen 15)
/// ============================================================
///
///   showHabitTextSheet     Name / unit text entry
///   showHabitOptionSheet   Category, habit type and frequency choices
///   showHabitTimesSheet    Reminder times: chips + "Add time"
///
/// Pickers return the chosen value; the times sheet edits the editor
/// controller live (so the row updates behind the sheet).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';

/// Single-line text entry. Returns the trimmed text (null when dismissed
/// or empty).
Future<String?> showHabitTextSheet(
  BuildContext context, {
  required String title,
  required String initial,
  String hint = '',
  int maxLength = 60,
}) => showFFBottomSheet<String>(
  context,
  builder: (_) => _TextSheet(
    title: title,
    initial: initial,
    hint: hint,
    maxLength: maxLength,
  ),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.initial,
    required this.hint,
    required this.maxLength,
  });

  final String title;
  final String initial;
  final String hint;
  final int maxLength;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: context.text.title),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: widget.hint),
          onSubmitted: (_) => _done(),
        ),
        const SizedBox(height: AppSpacing.md),
        FFPrimaryButton(label: 'Done', onPressed: _done),
      ],
    );
  }
}

/// One choice of [showHabitOptionSheet].
class HabitOption<T> {
  const HabitOption(this.value, this.label, {this.subtitle, this.icon});

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// A list of choices with a check on [selected]. Returns the tapped value.
Future<T?> showHabitOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<HabitOption<T>> options,
  required T selected,
}) => showFFBottomSheet<T>(
  context,
  builder: (sheet) {
    final ff = sheet.ff;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: sheet.text.title),
        const SizedBox(height: AppSpacing.lg),
        FFGroupedList(
          dividerIndent: AppSpacing.lg,
          children: [
            for (final o in options)
              FFListRow(
                title: o.label,
                subtitle: o.subtitle,
                semanticLabel: o.value == selected
                    ? '${o.label}, selected'
                    : o.label,
                trailing: o.value == selected
                    ? Icon(
                        FontAwesomeIcons.check,
                        size: AppSpacing.lg,
                        color: ff.primary,
                      )
                    : const SizedBox.shrink(),
                onTap: () => Navigator.of(sheet).pop(o.value),
              ),
          ],
        ),
      ],
    );
  },
);

/// Reminder times of the draft: remove with ×, add with the time picker.
Future<void> showHabitTimesSheet(BuildContext context, HabitEditorArgs args) =>
    showFFBottomSheet<void>(context, builder: (_) => _TimesSheet(args));

class _TimesSheet extends ConsumerWidget {
  const _TimesSheet(this.args);

  final HabitEditorArgs args;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    ref
        .read(habitEditorControllerProvider(args).notifier)
        .addReminderTime(HabitFormat.storeTime(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final draft = ref
        .watch(habitEditorControllerProvider(args))
        .valueOrNull
        ?.draft;
    final times = draft?.reminderTimes ?? const <String>[];
    final controller = ref.read(habitEditorControllerProvider(args).notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Reminder times', style: context.text.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'A reminder fires at each time on scheduled days.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (times.isEmpty)
          Text('No times yet', style: context.text.meta)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in times)
                InputChip(
                  label: Text(HabitFormat.time(t)),
                  labelStyle: context.text.rowTitle,
                  backgroundColor: ff.primarySoft,
                  side: BorderSide.none,
                  deleteIcon: Icon(
                    FontAwesomeIcons.xmark,
                    size: AppSpacing.md,
                    color: ff.primaryStrong,
                  ),
                  deleteButtonTooltipMessage: 'Remove ${HabitFormat.time(t)}',
                  onDeleted: () => controller.removeReminderTime(t),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),
        FFSecondaryButton(
          label: 'Add time',
          icon: FontAwesomeIcons.plus,
          onPressed: () => _add(context, ref),
        ),
        const SizedBox(height: AppSpacing.md),
        FFPrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
