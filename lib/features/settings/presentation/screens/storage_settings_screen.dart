/// ============================================================
/// STORAGE SETTINGS — Settings › Storage (`/settings/storage`)
/// ============================================================
///
/// What: hero with the total on-device footprint + a stacked bar, a
/// BREAKDOWN of every bucket (database, attachments, local backups, cache)
/// and CLEAN UP: clear the cache (confirmed), and shortcuts to Recently
/// deleted / Archive / Backup where the user decides what goes.
/// Why: CLAUDE.md — user data is never deleted from here. Only the cache
/// can be cleared, and only after a confirmation; everything else links to
/// the screen that owns it (with its own confirm + Undo).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/settings/domain/entities/storage_usage.dart';
import 'package:focusflow/features/settings/presentation/providers/settings_root_providers.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_hero.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_page.dart';
import 'package:focusflow/features/settings/presentation/widgets/storage/storage_bar.dart';
import 'package:go_router/go_router.dart';

class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storageUsageProvider);
    final counts = ref.watch(libraryCountsProvider).valueOrNull;
    final usage = async.valueOrNull;
    return SettingsPage(
      title: 'Storage',
      children: [
        SettingsHero(
          icon: FontAwesomeIcons.database,
          title: usage == null
              ? (async.hasError ? 'Couldn’t measure' : 'Measuring…')
              : '${formatBytes(usage.totalBytes)} on this device',
          body:
              'Your data lives on this phone, encrypted. Nothing here is '
              'removed without asking you first.',
          trailing: usage == null ? null : StorageBar(usage: usage),
        ),
        FFGroupedList(
          label: 'Breakdown',
          children: async.when(
            loading: () => const [
              FFSkeletonRow(),
              FFSkeletonRow(),
              FFSkeletonRow(),
            ],
            error: (_, _) => [
              FFListRow(
                leading: settingsTile(
                  FontAwesomeIcons.triangleExclamation,
                  SettingsTints.red,
                ),
                title: 'Couldn’t measure storage',
                value: 'Retry',
                onTap: () => ref.invalidate(storageUsageProvider),
              ),
            ],
            data: (u) => [
              for (final b in StorageBucket.values)
                FFListRow(
                  leading: settingsTile(b.icon, b.colors),
                  title: b.label,
                  subtitle: b.hint,
                  value: formatBytes(b.bytesOf(u)),
                  chevron: b == StorageBucket.backups,
                  onTap: b == StorageBucket.backups
                      ? () => context.push(AppRoutes.settingsBackup)
                      : null,
                ),
            ],
          ),
        ),
        FFGroupedList(
          label: 'Clean up',
          footer:
              'Clearing the cache never touches notes, tasks, reminders, '
              'habits, vault items or backups. Recently deleted items are '
              'removed for good after 30 days.',
          children: [
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.broom,
                SettingsTints.amber,
              ),
              title: 'Clear cache',
              value: usage == null ? null : formatBytes(usage.cacheBytes),
              chevron: false,
              enabled: (usage?.cacheBytes ?? 0) > 0,
              onTap: () => _clearCache(context, ref),
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.solidTrashCan,
                SettingsTints.rose,
              ),
              title: 'Recently deleted',
              value: counts?.trash.toString(),
              onTap: () => context.push(AppRoutes.trash),
            ),
            FFListRow(
              leading: settingsTile(
                FontAwesomeIcons.boxArchive,
                SettingsTints.slate,
              ),
              title: 'Archive',
              value: counts?.archived.toString(),
              onTap: () => context.push(AppRoutes.archive),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final ok = await showFFConfirm(
      context,
      title: 'Clear cache?',
      message:
          'Removes temporary files only. Your notes, tasks, vault and '
          'backups stay exactly as they are.',
      confirmLabel: 'Clear cache',
      icon: FontAwesomeIcons.broom,
    );
    if (!ok) return;
    final freed = await ref.read(storageRepositoryProvider).clearCache();
    ref.invalidate(storageUsageProvider);
    if (context.mounted) {
      showFFToast(
        context,
        'Freed ${formatBytes(freed)}',
        icon: FontAwesomeIcons.broom,
      );
    }
  }
}
