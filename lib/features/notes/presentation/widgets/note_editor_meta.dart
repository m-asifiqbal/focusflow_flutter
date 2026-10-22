/// ============================================================
/// NOTE EDITOR META — tags row and the "Edited …" meta line (screen 08)
/// ============================================================
///
/// * [NoteTagsRow]  folder chip (IDEAS), #tag chips and the round "+".
/// * [NoteMetaLine] "Edited today, 9:12 AM · 214 words · 🔔 Reminder Fri".
/// Chips keep a 44-pt tall hit area around their 21-pt pill.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class NoteTagsRow extends StatelessWidget {
  const NoteTagsRow({
    required this.folderName,
    required this.tags,
    this.onFolder,
    this.onTag,
    this.onAdd,
    super.key,
  });

  final String? folderName;
  final List<Tag> tags;
  final VoidCallback? onFolder;
  final ValueChanged<Tag>? onTag;

  /// Null hides "+" (read-only notes).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final folder = folderName?.trim();
    return Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (folder != null && folder.isNotEmpty)
          _Chip(
            label: folder,
            background: ff.primarySoft,
            semanticLabel: tr('Folder {folder}', {'folder': folder}),
            onTap: onFolder,
          ),
        for (final tag in tags)
          _Chip(
            label: '#${tag.name}',
            background: ff.primarySoft.withValues(
              alpha: ff.primarySoft.a * 0.5,
            ),
            semanticLabel: tr('Tag {name}', {'name': tag.name}),
            onTap: onTag == null ? null : () => onTag!(tag),
          ),
        if (onAdd != null)
          Semantics(
            button: true,
            label: tr('Add tag'),
            excludeSemantics: true,
            child: FFPressable(
              onTap: onAdd,
              child: SizedBox(
                width: AppSizes.minTap,
                height: AppSizes.minTap,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    width: AppSpacing.xxl,
                    height: AppSpacing.xxl,
                    decoration: BoxDecoration(
                      color: ff.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FontAwesomeIcons.plus,
                      size: 11,
                      color: ff.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.semanticLabel,
    this.onTap,
  });

  final String label;
  final Color background;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTap),
          child: Align(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadii.tileSm - 3),
              ),
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.tag.copyWith(
                  height: 1.2,
                  letterSpacing: 0.4,
                  color: ff.primaryStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Edited today, 9:12 AM · 214 words · 🔔 Reminder Fri".
class NoteMetaLine extends StatelessWidget {
  const NoteMetaLine({
    required this.edited,
    required this.words,
    this.reminder,
    this.onReminder,
    super.key,
  });

  final String edited;
  final String words;

  /// "Reminder Fri" (null = no linked reminder).
  final String? reminder;
  final VoidCallback? onReminder;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = context.text.meta.copyWith(
      fontSize: 11.5,
      color: ff.inkFaint,
    );
    final reminder = this.reminder;
    final text = Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '$edited · $words'),
          if (reminder != null) ...[
            const TextSpan(text: ' · '),
            // Bell + label never wrap apart.
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FontAwesomeIcons.bell,
                    size: 12,
                    color: ModuleStyle.reminders.colors.solid,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(child: Text(reminder, style: style)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    if (reminder == null || onReminder == null) return text;
    return Semantics(
      button: true,
      hint: tr('Opens the reminder'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onReminder,
        child: text,
      ),
    );
  }
}
