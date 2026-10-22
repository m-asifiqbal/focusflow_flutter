/// ============================================================
/// HOME TASK TILE — one row of "Today's Tasks" (mockup 03)
/// ============================================================
///
/// What: white card (radius 20) with the accent check circle, title (16
/// w600), "🕘 09:00 AM" and one pill (HIGH for high priority, else the
/// first tag or the list), and a tilted pin for pinned tasks. Completed
/// rows: title struck through and faded to 40%, meta line unchanged
/// (mockup 03 "Morning run 5 km").
/// Why: pure presentation; the section passes the callbacks, which go
/// through the tasks lane's completion flow (Undo snackbar).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/task_style.dart';

class HomeTaskTile extends StatelessWidget {
  const HomeTaskTile({
    required this.task,
    required this.onTap,
    required this.onCheck,
    this.onLongPress,
    this.use24h = false,
    super.key,
  });

  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Check circle tapped (true = complete, false = reopen).
  final ValueChanged<bool> onCheck;
  final bool use24h;

  /// The single pill of the meta line: (label, colours) or null.
  static (String, ModuleColors)? pillOf(TaskItem t) {
    if (t.priority == TaskPriority.high) return (tr('High'), TagPalette.high);
    if (t.tags.isNotEmpty) {
      final tag = t.tags.first;
      return (tag.name, TaskStyle.labelColors(tag.name, hex: tag.colorHex));
    }
    final list = t.listName;
    if (list != null && list.trim().isNotEmpty) {
      return (list, TaskStyle.labelColors(list));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final done = task.isCompleted;
    final title = task.title.trim().isEmpty ? tr('Untitled task') : task.title;
    final minutes = task.dueTimeMinutes;
    final time = minutes == null
        ? tr('Any time')
        : DateUtilsX.minutesToTime(minutes, use24h: use24h);
    final pill = pillOf(task);
    // The mockup tints the time line with the accent (muted).
    final metaColor = ff.primary.withValues(alpha: 0.75);
    final metaStyle = context.text.meta.copyWith(
      fontSize: HomeDimens.taskMeta,
      fontWeight: FontWeight.w500,
      color: metaColor,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.cardTitle.copyWith(
            fontSize: HomeDimens.taskTitle,
            fontWeight: FontWeight.w600,
            color: done ? ff.ink.withValues(alpha: 0.4) : null,
            decoration: done ? TextDecoration.lineThrough : null,
            decorationColor: ff.ink.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FontAwesomeIcons.clock,
                  size: HomeDimens.taskMetaIcon,
                  color: metaColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(time, style: metaStyle),
              ],
            ),
            if (pill != null) FFTag(pill.$1, colors: pill.$2),
          ],
        ),
      ],
    );

    return FFCard(
      radius: AppRadii.row,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xs + AppSpacing.xxs,
        HomeDimens.taskPadding - AppSpacing.xs,
        HomeDimens.taskPadding,
        HomeDimens.taskPadding - AppSpacing.xs,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: [
        title,
        time,
        if (pill != null) pill.$1,
        if (task.isPinned) 'pinned',
        if (done) 'completed',
      ].join(', '),
      child: Row(
        children: [
          FFCheckCircle(
            checked: done,
            size: HomeDimens.taskCheck,
            color: ff.primary,
            semanticLabel: done
                ? tr('Mark {title} as not done', {'title': title})
                : tr('Complete {title}', {'title': title}),
            onChanged: onCheck,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: content),
          if (task.isPinned) ...[
            const SizedBox(width: AppSpacing.sm),
            // Tilted like the mockup's pin (and the note cards').
            Transform.rotate(
              angle: HomeDimens.pinTilt,
              child: Icon(
                FontAwesomeIcons.thumbtack,
                size: HomeDimens.taskPin,
                color: ff.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
