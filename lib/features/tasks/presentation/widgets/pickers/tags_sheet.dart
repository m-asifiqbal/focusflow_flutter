/// ============================================================
/// TAGS SHEET — "Tags" picker of the task / reminder editors
/// ============================================================
///
/// What: every existing tag as a toggle chip (the item's tags pre-selected)
/// plus a field to type new ones; resolves to the chosen tag names (empty
/// list = no tags), or null when dismissed.
/// Why: the shared "Add tags" sheet only adds; an editor needs to remove
/// tags too and must not write before Save.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/providers/tasks_list_providers.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

/// Opens the tags sheet with [current] names selected.
Future<List<String>?> showTagsSheet(
  BuildContext context, {
  required List<String> current,
}) {
  return showFFBottomSheet<List<String>>(
    context,
    wrap: false,
    builder: (_) => _TagsSheet(current: current),
  );
}

class _TagsSheet extends ConsumerStatefulWidget {
  const _TagsSheet({required this.current});

  final List<String> current;

  @override
  ConsumerState<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends ConsumerState<_TagsSheet> {
  final _field = TextEditingController();
  late final List<String> _picked = [...widget.current];

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  static String _clean(String s) => s.replaceAll('#', '').trim();

  int _indexOf(String name) =>
      _picked.indexWhere((p) => p.toLowerCase() == name.toLowerCase());

  void _toggle(String name) => setState(() {
    final i = _indexOf(name);
    i >= 0 ? _picked.removeAt(i) : _picked.add(name);
  });

  /// Adds the typed tag (Enter keeps the sheet open for the next one).
  void _addTyped() {
    final typed = _clean(_field.text);
    if (typed.isEmpty) return;
    setState(() {
      if (_indexOf(typed) < 0) _picked.add(typed);
      _field.clear();
    });
  }

  void _done() {
    _addTyped();
    Navigator.of(context).pop(List<String>.of(_picked));
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final all = ref.watch(allTagsProvider).valueOrNull ?? const <Tag>[];
    // Selected names first (incl. new ones), then the rest.
    final names = <String>[..._picked];
    for (final t in all) {
      if (!names.any((n) => n.toLowerCase() == t.name.toLowerCase())) {
        names.add(t.name);
      }
    }
    return FFBottomSheet(
      footer: FFPrimaryButton(label: 'Done', onPressed: _done),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            'Tags',
            subtitle: _picked.isEmpty
                ? 'No tags'
                : _picked.map((n) => '#$n').join(' '),
          ),
          FFSearchField(
            controller: _field,
            hint: 'New tag',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addTyped(),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (names.isEmpty)
            Text(
              'Type a name to create your first tag.',
              style: context.text.meta,
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final n in names)
                  FFChip(
                    label: '#$n',
                    icon: _indexOf(n) >= 0 ? FontAwesomeIcons.check : null,
                    selected: _indexOf(n) >= 0,
                    activeColor: ff.primary,
                    onTap: () => _toggle(n),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
