/// ============================================================
/// TASK EDITOR CHROME — header and bottom actions of screen 11
/// ============================================================
///
/// What:
///   * [TaskEditorHeader] — Cancel · "Edit Task" / "New Task" · Save
///     (Save dimmed until the title is filled in).
///   * [TaskEditorFooter] — Archive (slate) and Delete (rose) buttons,
///     shown for existing tasks only.
/// Why: the mockup's header is a compact 44 pt bar (FFNavHeader is 56 pt)
/// with lighter 15.5 pt actions than FFNavAction.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

class TaskEditorHeader extends StatelessWidget {
  const TaskEditorHeader({
    required this.title,
    required this.onCancel,
    required this.onSave,
    required this.canSave,
    super.key,
  });

  final String title;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool canSave;

  /// The mockup's bar text sits 4 pt above a 44 pt bar's centre; the bar
  /// keeps its 44 pt tap height and is shifted instead.
  static const double _lift = -4;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final action = context.text.editorHeaderAction.copyWith(color: ff.primary);
    return Transform.translate(
      offset: const Offset(0, _lift),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xl,
        ),
        child: SizedBox(
          height: AppSizes.minTap,
          child: NavigationToolbar(
            leading: FFTextButton(
              label: tr('Cancel'),
              onPressed: onCancel,
              padding: EdgeInsetsDirectional.zero,
              style: action,
            ),
            middle: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.navTitle,
              ),
            ),
            trailing: FFTextButton(
              label: tr('Save'),
              onPressed: canSave ? onSave : null,
              padding: EdgeInsetsDirectional.zero,
              style: action.copyWith(fontWeight: FontWeight.w600),
            ),
            middleSpacing: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

class TaskEditorFooter extends StatelessWidget {
  const TaskEditorFooter({
    required this.onArchive,
    required this.onDelete,
    super.key,
  });

  /// Null hides Archive (task already archived).
  final VoidCallback? onArchive;
  final VoidCallback onDelete;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final b = Theme.of(context).brightness;
    final slate = ActionTints.lock.softFor(b);
    return Row(
      children: [
        if (onArchive != null) ...[
          Expanded(
            child: FFSecondaryButton(
              label: tr('Archive'),
              icon: FontAwesomeIcons.boxArchive,
              background: slate,
              foreground: ff.isDark ? ff.ink : ActionTints.lock.inkFor(b),
              height: height,
              onPressed: onArchive,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: FFSoftDangerButton(
            label: tr('Delete'),
            icon: FontAwesomeIcons.solidTrashCan,
            height: height,
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}
