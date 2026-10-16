/// ============================================================
/// TAGS & FOLDERS SETTINGS — Settings › Tags & folders
/// ============================================================
///
/// What: TAGS (shared by every module; tap → rename · colour · merge ·
/// delete) and one section per module with folders — NOTE FOLDERS, TASK
/// LISTS, VAULT FOLDERS (tap → rename · colour · delete; "New folder").
/// Every list is a live stream, so changes show up across the app at once.
/// Why: the management counterpart of Library › Tags & Folders (which is
/// for browsing). Loading → skeleton rows; error → retry; no tags → an
/// inline hint (tags are created from items, not here).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/library_actions.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:focusflow/features/settings/presentation/widgets/tags_folders/tags_folders_actions.dart';

class TagsFoldersSettingsScreen extends ConsumerWidget {
  const TagsFoldersSettingsScreen({super.key});

  static String sectionLabel(ItemType t) => switch (t) {
    ItemType.task => 'Task lists',
    ItemType.vault => 'Vault folders',
    _ => '${t.label} folders',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsPage(
    title: 'Tags & folders',
    children: [
      const _TagsSection(),
      for (final m in libraryFolderModules) _FoldersSection(module: m),
    ],
  );
}

String _count(int n) => '$n';

class _TagsSection extends ConsumerWidget {
  const _TagsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryTagsProvider);
    return FFGroupedList(
      label: 'Tags',
      footer:
          'Tags are shared by notes, tasks, reminders, habits and the '
          'vault. Add them from any item.',
      children: async.when(
        loading: () => const [FFSkeletonRow(), FFSkeletonRow()],
        error: (_, _) => [
          _RetryRow(onRetry: () => ref.invalidate(libraryTagsProvider)),
        ],
        data: (tags) => tags.isEmpty
            ? [
                FFListRow(
                  leading: settingsTile(
                    FontAwesomeIcons.hashtag,
                    SettingsTints.slate,
                  ),
                  title: 'No tags yet',
                  subtitle: 'Type #tag in a note or task to create one',
                  chevron: false,
                ),
              ]
            : [
                for (final t in tags)
                  FFListRow(
                    leading: settingsTile(
                      FontAwesomeIcons.hashtag,
                      libraryTagColors(t),
                    ),
                    title: t.label,
                    value: _count(t.usageCount),
                    semanticLabel:
                        '${t.label}, ${t.usageCount} items. Manage tag',
                    onTap: () => showTagManageSheet(context, ref, t, tags),
                  ),
              ],
      ),
    );
  }
}

class _FoldersSection extends ConsumerWidget {
  const _FoldersSection({required this.module});

  final ItemType module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryFoldersProvider(module));
    final noun = module == ItemType.task ? 'list' : 'folder';
    final add = FFListRow(
      leading: settingsTile(FontAwesomeIcons.plus, SettingsTints.emerald),
      title: 'New $noun',
      chevron: false,
      onTap: () => createFolderFlow(context, ref, module),
    );
    return FFGroupedList(
      label: TagsFoldersSettingsScreen.sectionLabel(module),
      children: async.when(
        loading: () => const [FFSkeletonRow()],
        error: (_, _) => [
          _RetryRow(
            onRetry: () => ref.invalidate(libraryFoldersProvider(module)),
          ),
        ],
        data: (List<Folder> folders) => [
          for (final f in folders)
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidFolder,
                folderColors(f),
              ),
              title: f.name,
              value: _count(f.itemCount),
              semanticLabel: '${f.name}, ${f.itemCount} items. Manage $noun',
              onTap: () => showFolderManageSheet(context, ref, f),
            ),
          add,
        ],
      ),
    );
  }
}

class _RetryRow extends StatelessWidget {
  const _RetryRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FFListRow(
    leading: settingsTile(
      FontAwesomeIcons.triangleExclamation,
      SettingsTints.red,
    ),
    title: 'Couldn’t load',
    value: 'Retry',
    onTap: onRetry,
  );
}

/// Keeps the import of [Tag] meaningful for readers of the row builders.
typedef TagList = List<Tag>;
