/// ============================================================
/// STORAGE BAR — stacked usage bar + legend on the Storage hero
/// ============================================================
///
/// What: one rounded bar split by bucket (database, attachments, local
/// backups, cache) and a wrapping legend underneath. [StorageBucket] holds
/// the label / icon / tint of each bucket so the bar and the breakdown rows
/// below it always agree.
/// Why: a quick visual answer to "what takes the space?" on the dark hero
/// card of Settings › Storage.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/features/settings/domain/entities/storage_usage.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';

/// The measured buckets, in bar order.
enum StorageBucket {
  database('Database', 'Notes, tasks, habits & vault · encrypted'),
  attachments('Attachments', 'Images and note covers'),
  backups('Local backups', 'Backup files kept on this device'),
  cache('Cache', 'Temporary files · safe to clear');

  const StorageBucket(this.label, this.hint);

  final String label;
  final String hint;

  IconData get icon => switch (this) {
    StorageBucket.database => FontAwesomeIcons.database,
    StorageBucket.attachments => FontAwesomeIcons.solidImage,
    StorageBucket.backups => FontAwesomeIcons.boxArchive,
    StorageBucket.cache => FontAwesomeIcons.broom,
  };

  ModuleColors get colors => switch (this) {
    StorageBucket.database => SettingsTints.emerald,
    StorageBucket.attachments => SettingsTints.blue,
    StorageBucket.backups => SettingsTints.violet,
    StorageBucket.cache => SettingsTints.amber,
  };

  int bytesOf(StorageUsage u) => switch (this) {
    StorageBucket.database => u.databaseBytes,
    StorageBucket.attachments => u.attachmentsBytes,
    StorageBucket.backups => u.backupsBytes,
    StorageBucket.cache => u.cacheBytes,
  };
}

class StorageBar extends StatelessWidget {
  const StorageBar({required this.usage, super.key});

  final StorageUsage usage;

  static const double _height = 8;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final total = usage.totalBytes;
    final parts = [
      for (final b in StorageBucket.values)
        if (b.bytesOf(usage) > 0) b,
    ];
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_height / 2),
            child: SizedBox(
              height: _height,
              child: ColoredBox(
                color: ff.vaultInk.withValues(alpha: 0.12),
                child: total <= 0
                    ? const SizedBox.expand()
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final b in parts)
                            Expanded(
                              // At least a sliver so tiny buckets stay visible.
                              flex: (b.bytesOf(usage) * 1000 ~/ total).clamp(
                                12,
                                1000,
                              ),
                              child: ColoredBox(color: b.colors.solid),
                            ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              for (final b in StorageBucket.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _height,
                      height: _height,
                      decoration: BoxDecoration(
                        color: b.colors.solid,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      b.label,
                      style: context.text.meta.copyWith(
                        color: ff.vaultInk.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
