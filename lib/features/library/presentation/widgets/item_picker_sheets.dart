/// ============================================================
/// ITEM PICKER SHEETS — tag and folder pickers behind item_pickers.dart
/// ============================================================
///
/// * [TagPickerSheet]    type a new tag or tap existing ones → names.
/// * [FolderPickerSheet] the module's folders + "No folder" → choice.
/// Pure pickers: they return the choice; the caller writes it through the
/// repositories (shared/item_actions/item_pickers.dart).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Every tag (suggestions of the tag picker), most used first.
final pickerTagsProvider = StreamProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagsRepositoryProvider).watchTags(),
);

/// Folders / lists of one module.
final pickerFoldersProvider = StreamProvider.autoDispose
    .family<List<Folder>, ItemType>(
      (ref, module) =>
          ref.watch(foldersRepositoryProvider).watchFolders(module),
    );

/// Result of [FolderPickerSheet]: [folderId] null = "No folder".
typedef FolderChoice = ({String? folderId});

class TagPickerSheet extends ConsumerStatefulWidget {
  const TagPickerSheet({this.exclude = const {}, super.key});

  /// Lower-case names already on the item (hidden from suggestions).
  final Set<String> exclude;

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  final _field = TextEditingController();
  final _picked = <String>[];

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  static String _clean(String s) => s.replaceAll('#', '').trim();

  void _toggle(String name) => setState(() {
    final i = _picked.indexWhere((p) => p.toLowerCase() == name.toLowerCase());
    i >= 0 ? _picked.removeAt(i) : _picked.add(name);
  });

  void _done() {
    final typed = _clean(_field.text);
    final names = [
      ..._picked,
      if (typed.isNotEmpty &&
          !_picked.any((p) => p.toLowerCase() == typed.toLowerCase()))
        typed,
    ];
    Navigator.of(context).pop(names);
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final tags = ref.watch(pickerTagsProvider).valueOrNull ?? const <Tag>[];
    final suggestions = [
      for (final t in tags)
        if (!widget.exclude.contains(t.name.toLowerCase())) t,
    ];
    return FFBottomSheet(
      footer: ListenableBuilder(
        listenable: _field,
        builder: (context, _) => FFPrimaryButton(
          label: tr('Add tags'),
          icon: FontAwesomeIcons.tag,
          onPressed: _picked.isEmpty && _clean(_field.text).isEmpty
              ? null
              : _done,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Add tags'), style: context.text.title),
          const SizedBox(height: AppSpacing.lg),
          FFSearchField(
            controller: _field,
            hint: tr('New tag'),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _done(),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            FFSectionLabel(tr('Your tags')),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in suggestions)
                  FFChip(
                    label: '#${t.name}',
                    selected: _picked.any(
                      (p) => p.toLowerCase() == t.name.toLowerCase(),
                    ),
                    activeColor: ff.primary,
                    onTap: () => _toggle(t.name),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class FolderPickerSheet extends ConsumerWidget {
  const FolderPickerSheet({
    required this.module,
    this.current,
    this.title,
    super.key,
  });

  final ItemType module;
  final String? current;

  /// Heading of the sheet; "Move to folder" when null.
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final folders = ref.watch(pickerFoldersProvider(module));
    Widget row(String? id, String name, Color color, {int? count}) => FFListRow(
      leading: FFIconTile(
        icon: id == null
            ? FontAwesomeIcons.folderOpen
            : FontAwesomeIcons.solidFolder,
        colors: ModuleColors(solid: color, soft: ff.primarySoft, ink: color),
      ),
      title: name,
      value: count?.toString(),
      trailing: id == current
          ? Icon(FontAwesomeIcons.check, size: 15, color: ff.primary)
          : null,
      onTap: () => Navigator.of(context).pop<FolderChoice>((folderId: id)),
    );
    return FFBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title ?? tr('Move to folder'), style: context.text.title),
          const SizedBox(height: AppSpacing.lg),
          switch (folders) {
            AsyncData(:final value) => FFGroupedList(
              children: [
                row(null, tr('No folder'), ff.inkMuted),
                for (final f in value)
                  row(
                    f.id,
                    f.name,
                    parseHex(f.colorHex) ?? ff.primary,
                    count: f.itemCount,
                  ),
              ],
            ),
            AsyncError() => FFErrorBanner(
              message: tr('Couldn\'t load folders'),
            ),
            _ => const FFSkeletonRow(),
          },
        ],
      ),
    );
  }
}

/// Result of [ColourPickerSheet]: [hex] null = white (no colour).
typedef ColourChoice = ({String? hex});

/// The six note-card colours as large swatches.
class ColourPickerSheet extends StatelessWidget {
  const ColourPickerSheet({this.current, super.key});

  final String? current;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final brightness = Theme.of(context).brightness;
    final selected = (current ?? NoteColors.hexes.first).toUpperCase();
    return FFBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Change colour'), style: context.text.title),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (var i = 0; i < NoteColors.hexes.length; i++)
                Semantics(
                  button: true,
                  selected: NoteColors.hexes[i] == selected,
                  label: tr('{v} colour', {
                    'v': NoteColors.name(NoteColors.hexes[i]),
                  }),
                  excludeSemantics: true,
                  child: FFPressable(
                    onTap: () => Navigator.of(context).pop<ColourChoice>((
                      hex: i == 0 ? null : NoteColors.hexes[i],
                    )),
                    child: Container(
                      width: AppSizes.iconTileLg,
                      height: AppSizes.iconTileLg,
                      decoration: BoxDecoration(
                        color: NoteColors.background(
                          NoteColors.hexes[i],
                          brightness,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: NoteColors.hexes[i] == selected
                              ? ff.success
                              : ff.divider,
                          width: NoteColors.hexes[i] == selected ? 3 : 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
