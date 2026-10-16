/// ============================================================
/// TASK PRIORITY SELECTOR — the PRIORITY pills of screen 11
/// ============================================================
///
/// What: three equal pills Low · Medium · High with their coloured dots;
/// the selected one gets its priority's soft fill + 2 pt ring (Medium =
/// amber-50 + amber ring in the mockup). Tapping the selected pill clears
/// the priority.
/// Why: a segmented-looking row that still reads as three toggle buttons
/// for screen readers; colours come from the priority trios so dark mode
/// works from tokens.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/task_flows.dart';
import 'package:focusflow/features/tasks/presentation/task_style.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

class TaskPrioritySelector extends StatelessWidget {
  const TaskPrioritySelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  static const double height = 45;

  @override
  Widget build(BuildContext context) {
    const choices = [TaskPriority.low, TaskPriority.medium, TaskPriority.high];
    return Row(
      children: [
        for (var i = 0; i < choices.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PriorityPill(
              priority: choices[i],
              selected: value == choices[i],
              onTap: () => onChanged(
                value == choices[i] ? TaskPriority.none : choices[i],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TaskPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final b = Theme.of(context).brightness;
    final trio = priorityTint(priority);
    final dot = TaskStyle.priorityColor(priority) ?? trio.solid;
    final fill = ff.isDark
        ? trio.softFor(b)
        : Color.lerp(ff.surface, trio.soft, 0.55)!;
    // The mockup's ring is a step lighter than the dot (amber-400).
    final ring = ff.isDark
        ? trio.solid
        : Color.lerp(trio.solid, trio.soft, 0.25)!;
    final radius = BorderRadius.circular(AppRadii.button);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '${priority.label} priority',
      onTap: onTap,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.reduceMotion ? Duration.zero : AppMotion.fast,
          constraints: const BoxConstraints(
            minHeight: TaskPrioritySelector.height,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? fill : ff.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected ? ring : ff.surfaceBorder,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? null : ff.cardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FFDot(color: dot, size: TaskSizes.dotSm),
              const SizedBox(width: TaskSizes.rowGap),
              // Large text scales on narrow screens shrink the label
              // instead of cutting "Medium" short.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    priority.label,
                    maxLines: 1,
                    style: context.text.editorChoice.copyWith(
                      color: selected ? trio.inkFor(b) : ff.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
