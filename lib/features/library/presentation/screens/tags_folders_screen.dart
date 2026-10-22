/// ============================================================
/// TAGS & FOLDERS — `/library/tags` (from Library › Collections)
/// ============================================================
///
/// What: every tag with its usage count (tap → the tag's mixed list,
/// long-press → rename / colour / delete), then the note folders, task
/// lists and vault folders with their item counts (tap → that module's
/// list; long-press → rename).
/// Why: the one place to tidy labels across modules; all rows are live.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/library_actions.dart';
import 'package:focusflow/features/library/presentation/library_format.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/library/presentation/widgets/choice_sheets.dart';
import 'package:focusflow/features/library/presentation/widgets/library_sections.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:go_router/go_router.dart';

class TagsFoldersScreen extends ConsumerWidget {
  const TagsFoldersScreen({super.key});

  /// Section title of each module's folders.
  static String folderSection(ItemType t) => switch (t) {
    ItemType.task => tr('Task lists'),
    ItemType.vault => tr('Vault folders'),
    _ => tr('{type} folders', {'type': t.label}),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(libraryTagsProvider);
    final tags = tagsAsync.valueOrNull;
    final folders = {
      for (final t in libraryFolderModules)
        t: ref.watch(libraryFoldersProvider(t)).valueOrNull,
    };
    final folderCount = folders.values.fold<int>(
      0,
      (n, l) => n + (l?.length ?? 0),
    );
    final loading = tags == null || folders.values.any((l) => l == null);
    final failed = tagsAsync.hasError && tags == null;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final sections = <Widget>[];
    void add(Widget w) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: AppSpacing.section));
      }
      sections.add(w);
    }

    if (failed) {
      add(
        FFEmptyState.compact(
          colors: TagPalette.high,
          icon: FontAwesomeIcons.triangleExclamation,
          title: tr('Couldn\'t load tags'),
          body: tr('Your items are safe. Try again.'),
          ctaLabel: tr('Retry'),
          ctaIcon: FontAwesomeIcons.arrowsRotate,
          onCta: () => ref.invalidate(libraryTagsProvider),
        ),
      );
    } else if (loading) {
      add(const FFSkeletonList(kind: FFSkeletonKind.row, count: 6));
    } else if (tags.isEmpty && folderCount == 0) {
      add(
        Padding(
          padding: EdgeInsetsDirectional.only(top: AppSpacing.xxxl),
          child: FFEmptyState(
            colors: TagPalette.design,
            icon: FontAwesomeIcons.tags,
            title: tr('No tags or folders yet'),
            body: tr(
              'Add #tags to notes, tasks, reminders and more, or create folders in Notes and lists in Tasks.',
            ),
          ),
        ),
      );
    } else {
      if (tags.isNotEmpty) {
        add(
          FFGroupedList(
            label: tr('Tags'),
            children: [for (final t in tags) _TagRow(tag: t)],
          ),
        );
      }
      for (final e in folders.entries) {
        if (e.value!.isEmpty) continue;
        add(
          FFGroupedList(
            label: folderSection(e.key),
            children: [for (final f in e.value!) _FolderRow(folder: f)],
          ),
        );
      }
    }

    return FFScaffold(
      safeBottom: false,
      body: ListView(
        padding: EdgeInsetsDirectional.only(bottom: bottom + AppSpacing.xxxl),
        children: [
          FFNavHeader(
            leading: FFBackButton(label: tr('Library')),
            title: tr('Tags & Folders'),
            subtitle: loading
                ? null
                : '${tags.length} ${tags.length == 1 ? 'tag' : 'tags'} · '
                      '$folderCount '
                      '${folderCount == 1 ? 'folder' : 'folders'}',
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.grouped,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sections,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  const _TagRow({required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FFListRow(
    leading: FFIconTile.soft(
      icon: FontAwesomeIcons.hashtag,
      colors: libraryTagColors(tag),
      size: 32,
    ),
    title: tag.label,
    value: '${tag.usageCount}',
    chevron: true,
    semanticLabel: '${tag.label}, ${LibraryFormat.items(tag.usageCount)}',
    onTap: () => context.push(AppRoutes.tag(tag.id)),
    onLongPress: () => showTagActions(context, ref, tag),
  );
}

class _FolderRow extends ConsumerWidget {
  const _FolderRow({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = folder.module.style;
    return FFListRow(
      leading: FFIconTile.soft(
        icon: folder.module == ItemType.task
            ? FontAwesomeIcons.listUl
            : FontAwesomeIcons.solidFolder,
        colors: style.colors,
        size: 32,
      ),
      title: folder.name,
      value: '${folder.itemCount}',
      chevron: true,
      semanticLabel: '${folder.name}, ${LibraryFormat.items(folder.itemCount)}',
      onTap: () => context.push(
        folder.module == ItemType.note
            ? Uri(
                path: AppRoutes.notes,
                queryParameters: {'folderId': folder.id},
              ).toString()
            : libraryModuleRoute(folder.module),
      ),
      onLongPress: () async {
        final name = await showTextInputSheet(
          context,
          title: folder.module == ItemType.task
              ? tr('Rename list')
              : tr('Rename folder'),
          initial: folder.name,
        );
        if (name == null) return;
        await ref.read(foldersRepositoryProvider).rename(folder.id, name);
      },
    );
  }
}
