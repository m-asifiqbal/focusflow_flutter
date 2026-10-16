/// ============================================================
/// TASK EDITOR ROW — one Schedule / Organise row of screen 11
/// ============================================================
///
/// What: soft icon tile · label · value (emerald + bold when it is a
/// scheduled date/time, muted otherwise) · chevron, 62 pt tall like the
/// mockup (63 pt pitch with the divider).
/// Why: the mockup's editor rows are lighter than [FFListRow] (medium
/// label, smaller 14.5 pt values, softer chevron), so this row lays out the
/// same structure — paddings, tile gap, InkWell — with those styles.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

class TaskEditorRow extends StatelessWidget {
  const TaskEditorRow({
    required this.icon,
    required this.colors,
    required this.title,
    required this.value,
    required this.onTap,
    this.valueColor,
    super.key,
  });

  /// Icon tile size.
  static const double tileSize = 34;

  /// Row height without its divider.
  static const double minHeight = 62;

  final IconData icon;
  final ModuleColors colors;
  final String title;
  final String value;

  /// Accent for set values (Date, Time); null = muted.
  final Color? valueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final valueStyle = context.text.editorValue.copyWith(
      color: valueColor ?? Color.lerp(ff.inkMuted, ff.inkFaint, 0.4),
      fontWeight: valueColor == null ? FontWeight.w500 : FontWeight.w700,
    );
    return Semantics(
      button: true,
      label: '$title, $value',
      // excludeSemantics drops the InkWell's tap action; re-add it.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 10,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  FFIconTile.soft(icon: icon, colors: colors, size: tileSize),
                  const SizedBox(width: TaskSizes.tileGap),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.rowTitle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.5,
                    ),
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: valueStyle,
                    ),
                  ),
                  const SizedBox(width: TaskSizes.rowGap),
                  Icon(
                    rtl
                        ? FontAwesomeIcons.chevronLeft
                        : FontAwesomeIcons.chevronRight,
                    size: TaskSizes.glyphMeta,
                    color: Color.lerp(ff.inkFaint, ff.surface, 0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
