/// ============================================================
/// CHOICE SHEETS — small single-choice and text-input bottom sheets
/// ============================================================
///
/// * [showChoiceSheet]    a titled list of options with a check on the
///   current one (sort order, tag filter…). Returns the picked value
///   wrapped in a record so `null` can be a real choice ("Any tag").
/// * [showTextInputSheet] one text field + primary button ("New folder").
/// Pure pickers: callers write the result through repositories / settings.
/// Shared by the notes list, library and archive screens of this lane.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';

/// One row of [showChoiceSheet].
@immutable
class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.label,
    this.icon,
    this.colors,
    this.subtitle,
  });

  final T value;
  final String label;
  final IconData? icon;
  final ModuleColors? colors;
  final String? subtitle;
}

/// The picked value of [showChoiceSheet] (null record = dismissed).
typedef Choice<T> = ({T value});

/// Shows [options] under [title]; the row equal to [selected] gets a check.
Future<Choice<T>?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<ChoiceOption<T>> options,
  T? selected,
}) => showFFBottomSheet<Choice<T>>(
  context,
  builder: (context) {
    final ff = context.ff;
    return FFBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.text.title),
          ),
          const SizedBox(height: AppSpacing.lg),
          FFGroupedList(
            children: [
              for (final o in options)
                FFListRow(
                  leading: o.icon == null
                      ? null
                      : FFIconTile.soft(
                          icon: o.icon!,
                          colors: o.colors ?? TagPalette.ideas,
                        ),
                  title: o.label,
                  subtitle: o.subtitle,
                  semanticLabel: o.value == selected
                      ? tr('{label}, selected', {'label': o.label})
                      : o.label,
                  trailing: o.value == selected
                      ? Icon(
                          FontAwesomeIcons.check,
                          size: 15,
                          color: ff.primary,
                        )
                      : null,
                  onTap: () =>
                      Navigator.of(context).pop<Choice<T>>((value: o.value)),
                ),
            ],
          ),
        ],
      ),
    );
  },
);

/// One-field sheet; returns the trimmed text, or null when dismissed or
/// left empty.
Future<String?> showTextInputSheet(
  BuildContext context, {
  required String title,
  String hint = '',
  String? confirmLabel,
  String initial = '',
}) async {
  final text = await showFFBottomSheet<String>(
    context,
    // The sheet builds its own FFBottomSheet.
    wrap: false,
    builder: (_) => _TextInputSheet(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel ?? tr('Save'),
      initial: initial,
    ),
  );
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String initial;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return FFBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(widget.title, style: context.text.title),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The themed input (filled surface, emerald focus ring).
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: context.text.body.copyWith(color: context.ff.ink),
            decoration: InputDecoration(hintText: widget.hint),
          ),
          const SizedBox(height: AppSpacing.xl),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, _) => FFPrimaryButton(
              label: widget.confirmLabel,
              onPressed: value.text.trim().isEmpty ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
