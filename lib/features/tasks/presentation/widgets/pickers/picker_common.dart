/// ============================================================
/// PICKER COMMON — building blocks of the tasks/reminders sheets
/// ============================================================
///
/// What:
///   * [Picked] — wraps a sheet result so "chose None" (value null) differs
///     from "dismissed" (the Future completes with null).
///   * [SheetHeader] — title (+ optional subtitle) at the top of a sheet.
///   * [OptionItem] / [showOptionSheet] — a single-choice list sheet
///     (Remind me, Priority, Sound, Default snooze…).
///   * [showTextInputSheet] — one text field + confirm ("New list").
/// Why: the task and reminder editors need many small, consistent pickers
/// in FocusFlow style (not raw Material dialogs); they are all built from
/// the design-system sheet, rows and buttons.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

/// A sheet result: `null` future = dismissed, `Picked(null)` = "None".
@immutable
class Picked<T> {
  const Picked(this.value);

  final T value;
}

/// Title + optional subtitle at the top of a picker sheet.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {this.subtitle, this.trailing, super.key});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: context.text.sectionTitle),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!, style: context.text.meta),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One choice of [showOptionSheet].
@immutable
class OptionItem<T> {
  const OptionItem({
    required this.value,
    required this.label,
    this.icon,
    this.colors,
    this.dotColor,
    this.subtitle,
  });

  final T value;
  final String label;

  /// Leading soft icon tile.
  final IconData? icon;
  final ModuleColors? colors;

  /// Leading coloured dot instead of an icon (priorities).
  final Color? dotColor;
  final String? subtitle;
}

/// Shows a single-choice list; resolves to the chosen value wrapped in
/// [Picked], or null when dismissed.
Future<Picked<T>?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<OptionItem<T>> options,
  required T selected,
  String? subtitle,
  Color? accent,
}) {
  return showFFBottomSheet<Picked<T>>(
    context,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(title, subtitle: subtitle),
        FFGroupedList(
          dividerIndent: AppSpacing.lg,
          children: [
            for (final o in options)
              OptionRow(
                label: o.label,
                subtitle: o.subtitle,
                icon: o.icon,
                colors: o.colors,
                dotColor: o.dotColor,
                selected: o.value == selected,
                accent: accent,
                onTap: () => Navigator.of(sheetContext).pop(Picked(o.value)),
              ),
          ],
        ),
      ],
    ),
  );
}

/// A tappable row with a trailing check when [selected].
class OptionRow extends StatelessWidget {
  const OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.colors,
    this.dotColor,
    this.accent,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final ModuleColors? colors;
  final Color? dotColor;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final check = accent ?? ff.primary;
    Widget? leading;
    if (icon != null) {
      leading = FFIconTile.soft(
        icon: icon!,
        colors:
            colors ??
            ModuleColors(
              solid: ff.primary,
              soft: ff.primarySoft,
              ink: ff.primaryStrong,
            ),
        size: TaskSizes.pickerTile,
      );
    } else if (dotColor != null) {
      leading = SizedBox.square(
        dimension: TaskSizes.pickerDotBox,
        child: Center(
          child: FFDot(color: dotColor, size: TaskSizes.dot),
        ),
      );
    }
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: FFListRow(
        title: label,
        subtitle: subtitle,
        leading: leading,
        onTap: onTap,
        trailing: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: AppMotion.fast,
          child: Icon(
            FontAwesomeIcons.check,
            size: TaskSizes.glyphCheck,
            color: check,
          ),
        ),
      ),
    );
  }
}

/// A one-field text sheet ("New list"). Resolves to the trimmed text, or
/// null when dismissed / empty.
Future<String?> showTextInputSheet(
  BuildContext context, {
  required String title,
  String hint = '',
  String initial = '',
  String confirmLabel = 'Save',
}) {
  return showFFBottomSheet<String>(
    context,
    wrap: false,
    builder: (_) => _TextInputSheet(
      title: title,
      hint: hint,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    required this.hint,
    required this.initial,
    required this.confirmLabel,
  });

  final String title;
  final String hint;
  final String initial;
  final String confirmLabel;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return FFBottomSheet(
      footer: ValueListenableBuilder(
        valueListenable: _text,
        builder: (context, value, _) => FFPrimaryButton(
          label: widget.confirmLabel,
          onPressed: value.text.trim().isEmpty ? null : _submit,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(widget.title),
          TextField(
            controller: _text,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: context.text.body.copyWith(color: context.ff.ink),
            decoration: InputDecoration(hintText: widget.hint),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
